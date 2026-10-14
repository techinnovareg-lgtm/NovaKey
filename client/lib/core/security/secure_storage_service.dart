import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Almacenamiento seguro respaldado por hardware (Android Keystore / Windows DPAPI)
class SecureStorageService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      resetOnError: true,
    ),
    wOptions: WindowsOptions(
      useBackwardCompatibility: false,
    ),
    webOptions: WebOptions(
      dbName: 'secure_vault_cache',
      publicKey: 'secure_vault_salt',
    ),
  );

  static const String _keyBiometricEnabled = 'sec_biometric_enabled';
  static const String _keyDeviceFingerprint = 'sec_device_fingerprint';
  static const String _keyEncryptedMek = 'sec_encrypted_mek';
  static const String _keyUserSalt = 'sec_user_salt';
  static const String _keyUserEmail = 'sec_user_email';

  /// Guarda la sal del usuario
  Future<void> saveUserSalt(String saltBase64) async {
    await _storage.write(key: _keyUserSalt, value: saltBase64);
  }

  Future<String?> getUserSalt() async {
    return await _storage.read(key: _keyUserSalt);
  }

  /// Guarda el email del usuario
  Future<void> saveUserEmail(String email) async {
    await _storage.write(key: _keyUserEmail, value: email);
  }

  Future<String?> getUserEmail() async {
    return await _storage.read(key: _keyUserEmail);
  }

  /// Guarda o consulta el identificador único del hardware (Fingerprint)
  Future<void> saveDeviceFingerprint(String fingerprint) async {
    await _storage.write(key: _keyDeviceFingerprint, value: fingerprint);
  }

  Future<String?> getDeviceFingerprint() async {
    return await _storage.read(key: _keyDeviceFingerprint);
  }

  /// Habilita o deshabilita el desbloqueo biométrico
  Future<void> setBiometricsEnabled(bool enabled) async {
    await _storage.write(key: _keyBiometricEnabled, value: enabled ? '1' : '0');
  }

  Future<bool> isBiometricsEnabled() async {
    final value = await _storage.read(key: _keyBiometricEnabled);
    return value == '1';
  }

  /// Guarda la clave de cifrado de la bóveda (MEK) protegida localmente
  Future<void> saveEncryptedMek(String mekBase64) async {
    await _storage.write(key: _keyEncryptedMek, value: mekBase64);
  }

  Future<String?> getEncryptedMek() async {
    return await _storage.read(key: _keyEncryptedMek);
  }

  static const String _keyLocalVaultItems = 'sec_local_vault_items';

  /// Guarda los ítems cifrados en almacenamiento local (para modo offline o sin nube)
  Future<void> saveLocalEncryptedVault(String jsonStr) async {
    await _storage.write(key: _keyLocalVaultItems, value: jsonStr);
  }

  Future<String?> getLocalEncryptedVault() async {
    return await _storage.read(key: _keyLocalVaultItems);
  }

  /// Borra todas las claves locales al cerrar sesión
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
