import 'package:flutter_test/flutter_test.dart';
import 'package:client/core/crypto/crypto_engine.dart';
import 'package:client/features/vault/models/vault_item.dart';

void main() {
  group('Zero-Knowledge Cryptographic Engine Tests', () {
    test('Generate random CSPRNG salt of 32 bytes', () {
      final salt1 = CryptoEngine.generateRandomSalt(32);
      final salt2 = CryptoEngine.generateRandomSalt(32);

      expect(salt1.length, equals(32));
      expect(salt2.length, equals(32));
      expect(salt1, isNot(equals(salt2)));
    });

    test('Derive Master Keys using Argon2id and HKDF', () async {
      final salt = CryptoEngine.generateRandomSalt(32);
      final keys = await CryptoEngine.deriveKeys(
        masterPassword: 'SuperStrongMasterPassword#2026!',
        salt: salt,
        memory: 1024, // Reducido para velocidad en tests unitarios
        iterations: 1,
        parallelism: 1,
      );

      expect(keys.authHashHex, isNotEmpty);
      expect(keys.authHashHex.length, equals(64)); // SHA-256 hex string

      final mekBytes = await keys.masterEncryptionKey.extractBytes();
      expect(mekBytes.length, equals(32)); // 256 bits AES key
    });

    test('Encrypt and Decrypt vault payload with AES-256-GCM', () async {
      final salt = CryptoEngine.generateRandomSalt(32);
      final keys = await CryptoEngine.deriveKeys(
        masterPassword: 'TestPassword123!',
        salt: salt,
        memory: 1024,
        iterations: 1,
        parallelism: 1,
      );

      final originalItem = VaultItem(
        title: 'Mi Cuenta de Correo',
        username: 'admin@dominio.com',
        password: 'PasswordSuperSecreto#999',
        websiteUrl: 'https://correo.empresa.com',
        notes: 'Nota confidencial con tokens de acceso',
        category: 'login',
      );

      final sensitiveJson = originalItem.toSensitiveJson();

      // Cifrado
      final encrypted = await CryptoEngine.encrypt(
        plainText: sensitiveJson,
        key: keys.masterEncryptionKey,
      );

      expect(encrypted.ciphertextBase64, isNotEmpty);
      expect(encrypted.nonceBase64, isNotEmpty);
      expect(encrypted.authTagBase64, isNotEmpty);

      // El ciphertext no debe contener la contraseña en plano
      expect(encrypted.ciphertextBase64.contains('PasswordSuperSecreto#999'), isFalse);

      // Descifrado
      final decryptedJson = await CryptoEngine.decrypt(
        payload: encrypted,
        key: keys.masterEncryptionKey,
      );

      expect(decryptedJson, equals(sensitiveJson));

      final restoredItem = VaultItem.fromDecryptedJson(
        id: originalItem.id,
        jsonStr: decryptedJson,
        version: originalItem.version,
        isFavorite: originalItem.isFavorite,
        isDeleted: originalItem.isDeleted,
        updatedAt: originalItem.updatedAt,
      );

      expect(restoredItem.title, equals(originalItem.title));
      expect(restoredItem.username, equals(originalItem.username));
      expect(restoredItem.password, equals(originalItem.password));
    });
  });
}
