import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:client/core/crypto/crypto_engine.dart';
import 'package:client/features/vault/models/vault_item.dart';

void main() {
  group('8. Pruebas Especializadas de Ciberseguridad para Gestores de Contraseñas', () {
    test('SP-01: Resistencia a Manipulación Criptográfica (AES-256-GCM Tamper Resistance)', () async {
      final salt = CryptoEngine.generateRandomSalt(32);
      final keys = await CryptoEngine.deriveKeys(
        masterPassword: 'TamperTestPassword2026!',
        salt: salt,
        memory: 1024,
        iterations: 1,
        parallelism: 1,
      );

      final originalPayload = await CryptoEngine.encrypt(
        plainText: '{"secret":"DatoUltraConfidencial"}',
        key: keys.masterEncryptionKey,
      );

      // 1. Simulación de Ataque: Modificación de 1 solo byte en el Ciphertext
      final ciphertextBytes = base64Decode(originalPayload.ciphertextBase64);
      ciphertextBytes[0] ^= 0xFF; // Invertir bits del primer byte
      final tamperedCiphertext = base64Encode(ciphertextBytes);

      final tamperedPayload1 = EncryptedPayload(
        ciphertextBase64: tamperedCiphertext,
        nonceBase64: originalPayload.nonceBase64,
        authTagBase64: originalPayload.authTagBase64,
      );

      // Verificación: La desencriptación debe ser rechazada categóricamente
      expect(
        () async => await CryptoEngine.decrypt(payload: tamperedPayload1, key: keys.masterEncryptionKey),
        throwsA(isA<Exception>()),
        reason: 'AES-256-GCM debe rechazar cualquier alteración del ciphertext sin filtrar datos',
      );

      // 2. Simulación de Ataque: Modificación del Auth Tag (firma de autenticación)
      final authTagBytes = base64Decode(originalPayload.authTagBase64);
      authTagBytes[0] ^= 0xFF;
      final tamperedAuthTag = base64Encode(authTagBytes);

      final tamperedPayload2 = EncryptedPayload(
        ciphertextBase64: originalPayload.ciphertextBase64,
        nonceBase64: originalPayload.nonceBase64,
        authTagBase64: tamperedAuthTag,
      );

      expect(
        () async => await CryptoEngine.decrypt(payload: tamperedPayload2, key: keys.masterEncryptionKey),
        throwsA(isA<Exception>()),
        reason: 'El authTag manipulado debe invalidar inmediatamente la transacción',
      );
    });

    test('SP-02: No-determinismo y Unicidad de Nonce/IV (Anti-Replay & Leakage Protection)', () async {
      final salt = CryptoEngine.generateRandomSalt(32);
      final keys = await CryptoEngine.deriveKeys(
        masterPassword: 'NonceUniquenessKey#2026',
        salt: salt,
        memory: 1024,
        iterations: 1,
        parallelism: 1,
      );

      const samePlaintext = 'MismaContraseñaParaTodosLosServicios#123';

      // Cifrar el mismo texto 5 veces consecutivas
      final payloads = <EncryptedPayload>[];
      for (int i = 0; i < 5; i++) {
        payloads.add(await CryptoEngine.encrypt(plainText: samePlaintext, key: keys.masterEncryptionKey));
      }

      // Verificación 1: Ningún nonce debe repetirse
      final nonces = payloads.map((e) => e.nonceBase64).toSet();
      expect(nonces.length, equals(5), reason: 'Cada operación debe utilizar un nonce criptográfico único (CSPRNG)');

      // Verificación 2: Ningún ciphertext debe repetirse aunque el texto sea idéntico
      final ciphertexts = payloads.map((e) => e.ciphertextBase64).toSet();
      expect(ciphertexts.length, equals(5), reason: 'El ciphertext nunca debe revelar igualdad de contenidos');
    });

    test('SP-03: Fuzzing y Robustez contra Entradas Maliciosas / Malformadas', () async {
      final salt = CryptoEngine.generateRandomSalt(32);
      final keys = await CryptoEngine.deriveKeys(
        masterPassword: 'FuzzingMasterPassword#2026',
        salt: salt,
        memory: 1024,
        iterations: 1,
        parallelism: 1,
      );

      // Vector 1: Cadena extremadamente larga (100,000 caracteres)
      final massiveString = 'A' * 100000;
      final massivePayload = await CryptoEngine.encrypt(plainText: massiveString, key: keys.masterEncryptionKey);
      final decryptedMassive = await CryptoEngine.decrypt(payload: massivePayload, key: keys.masterEncryptionKey);
      expect(decryptedMassive.length, equals(100000));

      // Vector 2: Caracteres Unicode exóticos, emojis y caracteres de control
      const exoticString = '🔒🛡️🔑 NovaKey — ᚠᛇᚻ ᛒᛦᚦ ᚠᚱfroda \u0000\u001F\t\r\n 𝒳 = 𝒴';
      final exoticPayload = await CryptoEngine.encrypt(plainText: exoticString, key: keys.masterEncryptionKey);
      final decryptedExotic = await CryptoEngine.decrypt(payload: exoticPayload, key: keys.masterEncryptionKey);
      expect(decryptedExotic, equals(exoticString));

      // Vector 3: Payload con JSON corrupto o deserialización anómala
      const malformedJson = '{ "title": "Incompleto", ';
      expect(
        () => VaultItem.fromDecryptedJson(
          id: 'test-id',
          jsonStr: malformedJson,
          version: 1,
          isFavorite: false,
          isDeleted: false,
          updatedAt: DateTime.now(),
        ),
        throwsA(isA<FormatException>()),
        reason: 'El parser debe detectar y aislar excepciones de formato de manera segura',
      );
    });

    test('SP-04: Resiliencia de la Clave Maestra y Verificación Criptográfica Zero-Knowledge', () async {
      final salt = CryptoEngine.generateRandomSalt(32);
      final keys = await CryptoEngine.deriveKeys(
        masterPassword: 'CorrectPassword2026',
        salt: salt,
        memory: 1024,
        iterations: 1,
        parallelism: 1,
      );

      // Verifier SHA-256 es computado
      final verifierHex = keys.authHashHex;

      // Cualquier contraseña con 1 solo carácter de diferencia produce un hash divergente (Efecto Avalancha)
      final slightDifferenceKeys = await CryptoEngine.deriveKeys(
        masterPassword: 'CorrectPassword2027', // Cambio de 1 dígito
        salt: salt,
        memory: 1024,
        iterations: 1,
        parallelism: 1,
      );

      expect(slightDifferenceKeys.authHashHex, isNot(equals(verifierHex)));

      // Verificamos que la distancia de Hamming/diferencia sea drástica
      int matchingChars = 0;
      for (int i = 0; i < verifierHex.length; i++) {
        if (verifierHex[i] == slightDifferenceKeys.authHashHex[i]) matchingChars++;
      }
      expect(matchingChars, lessThan(verifierHex.length ~/ 2),
          reason: 'El efecto avalancha de SHA-256 debe modificar radicalmente el hash ante cambios mínimos');
    });
  });
}
