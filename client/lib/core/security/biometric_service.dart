import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Servicio de Autenticación Biométrica unificado para Android, Windows y Web
class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  /// Verifica si el hardware del dispositivo soporta biometría (Huella, Rostro, Windows Hello)
  Future<bool> isBiometricsSupported() async {
    if (kIsWeb) return false;
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();
      return canCheck && isDeviceSupported;
    } catch (e) {
      debugPrint('Soporte biométrico no disponible en esta plataforma: $e');
      return false;
    }
  }

  /// Lista los tipos de biometría disponibles (huella dactilar, reconocimiento facial, etc.)
  Future<List<BiometricType>> getAvailableBiometrics() async {
    if (kIsWeb) return [];
    try {
      return await _auth.getAvailableBiometrics();
    } catch (e) {
      debugPrint('Error obteniendo biometrías disponibles: $e');
      return [];
    }
  }

  /// Ejecuta el prompt de autenticación biométrica nativo
  Future<bool> authenticate({
    String reason = 'Confirma tu identidad para desbloquear tu Bóveda de Contraseñas',
  }) async {
    try {
      final supported = await isBiometricsSupported();
      if (!supported) return false;

      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // Permite PIN del sistema operativo o Windows Hello como respaldo
          useErrorDialogs: true,
          sensitiveTransaction: true,
        ),
      );
    } on PlatformException catch (e) {
      debugPrint('Fallo de autenticación biométrica: ${e.code} - ${e.message}');
      return false;
    }
  }

  /// Nombre amigable de la tecnología biométrica según plataforma
  String getBiometricTitle() {
    if (kIsWeb) return 'Autenticación WebAuthn / Passkey';
    if (Platform.isWindows) return 'Windows Hello (Rostro / Huella / PIN)';
    if (Platform.isAndroid) return 'Biometría Android (Huella / Desbloqueo Facial)';
    return 'Autenticación Biométrica';
  }
}
