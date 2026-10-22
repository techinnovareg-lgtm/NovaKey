import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Almacenamiento seguro y persistente para la Bóveda Zero-Knowledge
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
  static const String _keyLastEmail = 'sec_last_user_email';

  /// Guarda la sal del usuario asociada a su correo (para que Argon2id derive siempre la misma clave)
  Future<void> saveUserSalt(String email, String saltBase64) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'sec_salt_${email.toLowerCase().trim()}';
    await prefs.setString(key, saltBase64);
  }

  Future<String?> getUserSalt(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'sec_salt_${email.toLowerCase().trim()}';
    return prefs.getString(key);
  }

  /// Guarda el último email utilizado para recordar la sesión
  Future<void> saveUserEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastEmail, email.toLowerCase().trim());
  }

  Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLastEmail);
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

  /// Guarda la clave de cifrado de la bóveda (MEK) protegida localmente para biometría
  Future<void> saveEncryptedMek(String mekBase64) async {
    await _storage.write(key: _keyEncryptedMek, value: mekBase64);
  }

  Future<String?> getEncryptedMek() async {
    return await _storage.read(key: _keyEncryptedMek);
  }

  /// Guarda el verificador hash de la contraseña maestra (SHA-256 de authHashHex)
  Future<void> savePasswordVerifier(String email, String verifierHex) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'sec_verifier_${email.toLowerCase().trim()}';
    await prefs.setString(key, verifierHex);
  }

  Future<String?> getPasswordVerifier(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'sec_verifier_${email.toLowerCase().trim()}';
    return prefs.getString(key);
  }

  /// Guarda los ítems cifrados en almacenamiento local persistente (Offline-First)
  Future<void> saveLocalEncryptedVault(String email, String jsonStr) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'sec_vault_${email.toLowerCase().trim()}';
    await prefs.setString(key, jsonStr);
  }

  Future<String?> getLocalEncryptedVault(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'sec_vault_${email.toLowerCase().trim()}';
    return prefs.getString(key);
  }

  /// Guarda las categorías personalizadas del usuario
  Future<void> saveCustomCategories(String email, List<String> categories) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'sec_cats_${email.toLowerCase().trim()}';
    await prefs.setStringList(key, categories);
  }

  Future<List<String>> getCustomCategories(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'sec_cats_${email.toLowerCase().trim()}';
    return prefs.getStringList(key) ?? [];
  }

  /// Guarda o consulta si este dispositivo ha sido autorizado mediante PIN
  Future<void> setDeviceAuthorized(String email, bool authorized) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'sec_dev_auth_${email.toLowerCase().trim()}';
    await prefs.setBool(key, authorized);
  }

  Future<bool> isDeviceAuthorized(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'sec_dev_auth_${email.toLowerCase().trim()}';
    return prefs.getBool(key) ?? false;
  }

  /// Borra las claves locales temporales
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
