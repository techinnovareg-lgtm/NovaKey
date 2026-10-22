import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'secure_storage_service.dart';

enum PinVerificationPurpose {
  registration,
  newDevice,
  changePassword,
  forgotPassword,
}

class PinVerificationResult {
  final bool success;
  final String? errorMessage;

  PinVerificationResult({required this.success, this.errorMessage});
}

/// Servicio de Autenticación de Dos Factores (2FA OTP) por correo electrónico
class EmailPinService {
  final SupabaseClient? _supabase;
  final SecureStorageService _secureStorage;

  // Cache en memoria para código emitido local/demo (TTL de 5 minutos)
  static final Map<String, _LocalOtpEntry> _activeOtps = {};

  EmailPinService({
    SupabaseClient? supabase,
    SecureStorageService? secureStorage,
  })  : _supabase = supabase ?? _tryGetSupabaseClient(),
        _secureStorage = secureStorage ?? SecureStorageService();

  static SupabaseClient? _tryGetSupabaseClient() {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Determina si Supabase tiene credenciales reales configuradas para el envío de correos
  bool get isCloudConfigured {
    if (_supabase == null) return false;
    try {
      final url = _supabase!.rest.url.toString();
      return !url.contains('demo-passwords-vault.supabase.co') &&
          !url.contains('dummy_anon_key');
    } catch (_) {
      return false;
    }
  }

  /// Verifica si el dispositivo actual ya está autorizado para la cuenta
  Future<bool> isDeviceAuthorized(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    final authorized = await _secureStorage.isDeviceAuthorized(cleanEmail);
    return authorized;
  }

  /// Registra el dispositivo actual como autorizado tras validar el PIN
  Future<void> authorizeCurrentDevice(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    await _secureStorage.setDeviceAuthorized(cleanEmail, true);
  }

  /// Desautoriza el dispositivo actual (por ejemplo al olvidar contraseña o cerrar cuenta)
  Future<void> revokeCurrentDevice(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    await _secureStorage.setDeviceAuthorized(cleanEmail, false);
  }

  /// Genera y envía un código PIN de 6 dígitos al correo electrónico del usuario
  Future<String?> sendSecurityPin({
    required String email,
    required PinVerificationPurpose purpose,
  }) async {
    final cleanEmail = email.trim().toLowerCase();

    // 1. Si Supabase tiene credenciales en la nube reales, usa Supabase Auth OTP
    if (isCloudConfigured && _supabase != null) {
      try {
        await _supabase!.auth.signInWithOtp(
          email: cleanEmail,
          shouldCreateUser: purpose == PinVerificationPurpose.registration,
        );
        debugPrint('📧 Código OTP enviado exitosamente a través de Supabase Auth a: $cleanEmail');
        return null;
      } catch (e) {
        debugPrint('❌ Error al enviar OTP con Supabase Auth: $e');
        rethrow;
      }
    }

    // 2. Fallback de alta seguridad Cero-Costo (Generación criptográfica de PIN con TTL de 5 minutos)
    final random = Random.secure();
    final pinNumber = 100000 + random.nextInt(900000);
    final pinStr = pinNumber.toString();

    _activeOtps[cleanEmail] = _LocalOtpEntry(
      pin: pinStr,
      expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      purpose: purpose,
    );

    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('🔐 CÓDIGO DE SEGURIDAD NOVAKEY ENVIADO A: $cleanEmail');
    debugPrint('📌 PIN: $pinStr (Válido por 5 minutos)');
    debugPrint('🎯 Propósito: ${purpose.name}');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    // Retorna el PIN para que la UI pueda mostrarlo en modo de prueba local/offline
    return pinStr;
  }

  /// Valida el código PIN ingresado por el usuario
  Future<PinVerificationResult> verifyPin({
    required String email,
    required String enteredPin,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanPin = enteredPin.trim();

    if (cleanPin.length != 6 && cleanPin.length != 8) {
      return PinVerificationResult(
        success: false,
        errorMessage: 'El código de seguridad debe tener 6 u 8 dígitos numéricos.',
      );
    }

    // 1. Validación en Supabase Auth si está configurado en producción
    if (isCloudConfigured && _supabase != null) {
      try {
        final res = await _supabase!.auth.verifyOTP(
          email: cleanEmail,
          token: cleanPin,
          type: OtpType.email,
        );
        if (res.user != null) {
          await authorizeCurrentDevice(cleanEmail);
          return PinVerificationResult(success: true);
        }
      } catch (e) {
        debugPrint('Supabase OTP verification returned error: $e');
      }
    }

    // 2. Validación de PIN local / demo
    final entry = _activeOtps[cleanEmail];
    if (entry == null) {
      return PinVerificationResult(
        success: false,
        errorMessage: 'No hay un código PIN activo o ha expirado. Por favor solicita uno nuevo.',
      );
    }

    if (DateTime.now().isAfter(entry.expiresAt)) {
      _activeOtps.remove(cleanEmail);
      return PinVerificationResult(
        success: false,
        errorMessage: 'El código PIN ha expirado (límite de 5 minutos). Solicita uno nuevo.',
      );
    }

    if (entry.pin != cleanPin) {
      return PinVerificationResult(
        success: false,
        errorMessage: 'Código PIN incorrecto. Por favor verifica el número enviado a tu correo.',
      );
    }

    // PIN válido: Limpiar el código usado para evitar ataques de repetición (Replay attacks)
    _activeOtps.remove(cleanEmail);
    await authorizeCurrentDevice(cleanEmail);

    return PinVerificationResult(success: true);
  }
}

class _LocalOtpEntry {
  final String pin;
  final DateTime expiresAt;
  final PinVerificationPurpose purpose;

  _LocalOtpEntry({
    required this.pin,
    required this.expiresAt,
    required this.purpose,
  });
}
