import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../crypto/crypto_engine.dart';

/// Servicio de Kit de Rescate de Emergencia (Emergency Recovery Kit)
/// Permite recuperar la Master Encryption Key (MEK) de forma 100% Zero-Knowledge
/// si el usuario olvida su contraseña maestra, sin intervención de terceros.
class RecoveryKitService {
  static final Sha256 _sha256 = Sha256();

  /// Genera una Clave de Rescate de Emergencia de alta entropía
  /// Formato: NK-REC-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX (6 bloques alfanuméricos)
  static String generateRecoveryKey() {
    const chars = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ'; // Base32 Crockford (sin caracteres ambiguos 0,O,1,I)
    final randomBytes = CryptoEngine.generateRandomSalt(24);
    final buffer = StringBuffer('NK-REC-');

    for (int i = 0; i < 24; i++) {
      buffer.write(chars[randomBytes[i] % chars.length]);
      if ((i + 1) % 4 == 0 && i < 23) {
        buffer.write('-');
      }
    }
    return buffer.toString();
  }

  /// Normaliza una clave ingresada por el usuario (mayúsculas, quita espacios extras)
  static String normalizeKey(String rawKey) {
    return rawKey.trim().toUpperCase().replaceAll(' ', '');
  }

  /// Valida que el formato de la clave corresponda a NK-REC-...
  static bool isValidKeyFormat(String key) {
    final clean = normalizeKey(key);
    final regExp = RegExp(r'^NK-REC-[2-9A-HJ-NP-Z]{4}-[2-9A-HJ-NP-Z]{4}-[2-9A-HJ-NP-Z]{4}-[2-9A-HJ-NP-Z]{4}-[2-9A-HJ-NP-Z]{4}-[2-9A-HJ-NP-Z]{4}$');
    return regExp.hasMatch(clean);
  }

  /// Deriva la clave simétrica de 256 bits a partir de la Clave de Rescate y la Sal
  static Future<SecretKey> _deriveRecoverySecretKey(String recoveryKey, Uint8List salt) async {
    final cleanKey = normalizeKey(recoveryKey);
    final hkdf = Hkdf(
      hmac: Hmac.sha256(),
      outputLength: 32,
    );
    return await hkdf.deriveKey(
      secretKey: SecretKey(utf8.encode(cleanKey)),
      nonce: salt,
      info: utf8.encode('novakey-emergency-recovery-kit-v1'),
    );
  }

  /// Cifra la Master Encryption Key (MEK) con la Clave de Rescate
  static Future<EncryptedPayload> encryptMekForRecovery({
    required SecretKey masterEncryptionKey,
    required String recoveryKey,
    required Uint8List salt,
  }) async {
    final recoverySecretKey = await _deriveRecoverySecretKey(recoveryKey, salt);
    final rawMekBytes = await masterEncryptionKey.extractBytes();
    final mekBase64 = base64Encode(rawMekBytes);

    return await CryptoEngine.encrypt(
      plainText: mekBase64,
      key: recoverySecretKey,
    );
  }

  /// Descifra la Master Encryption Key (MEK) a partir de la Clave de Rescate
  static Future<SecretKey?> decryptMekFromRecovery({
    required EncryptedPayload recoveryPayload,
    required String recoveryKey,
    required Uint8List salt,
  }) async {
    try {
      final recoverySecretKey = await _deriveRecoverySecretKey(recoveryKey, salt);
      final decryptedMekBase64 = await CryptoEngine.decrypt(
        payload: recoveryPayload,
        key: recoverySecretKey,
      );
      final rawMekBytes = base64Decode(decryptedMekBase64);
      return SecretKey(rawMekBytes);
    } catch (e) {
      debugPrint('Error al descifrar MEK con Clave de Rescate: $e');
      return null;
    }
  }

  /// Guarda en almacenamiento local persistente el payload de recuperación
  static Future<void> saveRecoveryData({
    required String email,
    required EncryptedPayload payload,
    required String recoveryKey,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final prefs = await SharedPreferences.getInstance();

    final payloadJson = jsonEncode(payload.toMap());
    await prefs.setString('sec_recovery_payload_$cleanEmail', payloadJson);

    // Guardar hash de verificación para comprobación rápida
    final cleanKey = normalizeKey(recoveryKey);
    final keyHash = await _sha256.hash(utf8.encode(cleanKey));
    final keyHashHex = keyHash.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    await prefs.setString('sec_recovery_hash_$cleanEmail', keyHashHex);

    // Guardar fecha de generación
    await prefs.setString('sec_recovery_date_$cleanEmail', DateTime.now().toIso8601String());

    // Guardar clave de rescate localmente para consulta del usuario autenticado
    await prefs.setString('sec_recovery_key_$cleanEmail', cleanKey);
  }

  /// Obtiene la clave de rescate guardada localmente si está disponible
  static Future<String?> getSavedRecoveryKey(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('sec_recovery_key_$cleanEmail');
  }

  /// Obtiene el payload de recuperación guardado
  static Future<EncryptedPayload?> getRecoveryPayload(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('sec_recovery_payload_$cleanEmail');
    if (jsonStr == null || jsonStr.isEmpty) return null;

    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return EncryptedPayload.fromMap(map);
    } catch (_) {
      return null;
    }
  }

  /// Verifica si el usuario tiene un Kit de Rescate configurado
  static Future<bool> hasRecoveryKit(String email) async {
    final payload = await getRecoveryPayload(email);
    return payload != null;
  }

  /// Genera el contenido oficial del Kit de Rescate de Emergencia (para descarga o impresión)
  static String generateKitDocumentHtml({
    required String email,
    required String recoveryKey,
    DateTime? createdAt,
  }) {
    final created = createdAt ?? DateTime.now();
    final dateStr = '${created.day.toString().padLeft(2, '0')}/${created.month.toString().padLeft(2, '0')}/${created.year}';
    return '''<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <title>NovaKey - Kit de Rescate de Emergencia</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background: #0B0F19; color: #F1F5F9; padding: 40px; margin: 0; }
    .card { max-width: 680px; margin: 0 auto; background: #131722; border: 2px solid #2563EB; border-radius: 16px; padding: 32px; box-shadow: 0 10px 30px rgba(0,0,0,0.5); }
    .header { display: flex; align-items: center; justify-content: space-between; border-bottom: 1px solid #1E293B; padding-bottom: 20px; margin-bottom: 24px; }
    .brand { font-size: 24px; font-weight: 800; color: #FFFFFF; }
    .brand span { color: #38BDF8; }
    .tag { background: rgba(37,99,235,0.2); color: #60A5FA; padding: 4px 12px; border-radius: 20px; font-size: 12px; font-weight: bold; border: 1px solid #2563EB; }
    .title { font-size: 20px; font-weight: bold; color: #FFFFFF; margin-top: 0; }
    .desc { font-size: 14px; color: #94A3B8; line-height: 1.6; }
    .key-box { background: #090D16; border: 2px dashed #38BDF8; border-radius: 12px; padding: 20px; text-align: center; margin: 24px 0; }
    .key-label { font-size: 12px; font-weight: bold; color: #94A3B8; text-transform: uppercase; letter-spacing: 1px; margin-bottom: 8px; }
    .key-value { font-family: 'Courier New', Courier, monospace; font-size: 20px; font-weight: bold; color: #38BDF8; letter-spacing: 2px; }
    .meta { font-size: 13px; color: #64748B; margin-bottom: 16px; }
    .meta strong { color: #CBD5E1; }
    .rules { background: rgba(245,158,11,0.08); border-left: 4px solid #F59E0B; padding: 14px 16px; border-radius: 0 8px 8px 0; margin-bottom: 24px; }
    .rules h4 { margin: 0 0 6px 0; color: #FBBF24; font-size: 13px; }
    .rules ul { margin: 0; padding-left: 20px; font-size: 12.5px; color: #CBD5E1; line-height: 1.5; }
    .footer { text-align: center; font-size: 12px; color: #64748B; border-top: 1px solid #1E293B; padding-top: 16px; margin-top: 24px; }
    @media print {
      body { background: #FFFFFF; color: #000000; padding: 10px; }
      .card { border: 2px solid #000000; box-shadow: none; background: #FFFFFF; }
      .brand, .title, .key-value { color: #000000 !important; }
      .key-box { border: 2px dashed #000000; background: #F8FAFC; }
      .rules { border-left: 4px solid #000000; background: #F1F5F9; }
      .rules h4, .rules ul, .desc, .meta, .footer { color: #333333 !important; }
    }
  </style>
</head>
<body>
  <div class="card">
    <div class="header">
      <div class="brand">Nova<span>Key</span></div>
      <div class="tag">KIT DE EMERGENCIA ZERO-KNOWLEDGE</div>
    </div>
    <h2 class="title">Hoja de Rescate de Emergencia</h2>
    <p class="desc">
      Este documento contiene tu <strong>Clave Maestra de Rescate</strong>. Si alguna vez olvidas tu contraseña maestra, esta clave te permitirá recuperar el acceso a tu bóveda y desencriptar todos tus datos.
    </p>
    <div class="meta">
      <div><strong>Usuario Titular:</strong> $email</div>
      <div><strong>Fecha de Emisión:</strong> $dateStr</div>
      <div><strong>Desarrollador:</strong> Tech Innova (tech-innova.online)</div>
    </div>
    <div class="key-box">
      <div class="key-label">Tu Clave de Rescate de Emergencia</div>
      <div class="key-value">$recoveryKey</div>
    </div>
    <div class="rules">
      <h4>⚠️ REGLAS CRÍTICAS DE SEGURIDAD</h4>
      <ul>
        <li><strong>Imprime esta hoja o guárdala en una memoria USB cifrada</strong> en un lugar físico seguro (fuera de línea).</li>
        <li><strong>No compartas esta clave con nadie.</strong> Ni el personal de Tech Innova te pedirá jamás esta clave.</li>
        <li><strong>Bajo Zero-Knowledge,</strong> si pierdes tu contraseña maestra Y esta clave de rescate, nadie en el mundo podrá descifrar tus contraseñas.</li>
      </ul>
    </div>
    <div class="footer">
      NovaKey • Bóveda Cero-Conocimiento desarrollada por Tech Innova • Soporte: +51 947 515 529
    </div>
  </div>
</body>
</html>''';
  }

  /// Abre la hoja de rescate para imprimir o guardar
  static Future<void> openPrintableDocument({
    required String email,
    required String recoveryKey,
  }) async {
    final htmlContent = generateKitDocumentHtml(
      email: email,
      recoveryKey: recoveryKey,
      createdAt: DateTime.now(),
    );

    final dataUri = Uri.dataFromString(
      htmlContent,
      mimeType: 'text/html',
      encoding: utf8,
    );

    try {
      await launchUrl(dataUri, mode: LaunchMode.externalApplication);
    } catch (_) {
      await launchUrl(dataUri);
    }
  }
}
