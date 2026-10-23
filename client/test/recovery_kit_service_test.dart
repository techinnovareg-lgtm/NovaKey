import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:client/core/crypto/crypto_engine.dart';
import 'package:client/core/security/recovery_kit_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Pruebas de Ciberseguridad: RecoveryKitService (Kit de Rescate Zero-Knowledge)', () {
    test('Genera claves de rescate con formato Crockford Base32 y entropía adecuada', () {
      final key1 = RecoveryKitService.generateRecoveryKey();
      final key2 = RecoveryKitService.generateRecoveryKey();

      expect(key1, startsWith('NK-REC-'));
      expect(key2, startsWith('NK-REC-'));
      expect(key1, isNot(equals(key2)));
      expect(RecoveryKitService.isValidKeyFormat(key1), isTrue);
      expect(RecoveryKitService.isValidKeyFormat(key2), isTrue);
    });

    test('Validador de formato rechaza claves con formato inválido o caracteres ambiguos', () {
      expect(RecoveryKitService.isValidKeyFormat('INVALID-KEY'), isFalse);
      expect(RecoveryKitService.isValidKeyFormat('NK-REC-1234-5678-90AB-CDEF'), isFalse);
      expect(RecoveryKitService.isValidKeyFormat('NK-REC-AAAA-BBBB-CCCC-DDDD-EEEE-0000'), isFalse); // '0' no está en Crockford
      expect(RecoveryKitService.isValidKeyFormat('NK-REC-AAAA-BBBB-CCCC-DDDD-EEEE-IIII'), isFalse); // 'I' no está en Crockford
    });

    test('Cifrado y Descifrado exitoso de la MEK mediante la Clave de Rescate (Roundtrip)', () async {
      final email = 'usuario.seguro@novakey.com';
      final salt = await CryptoEngine.deriveDeterministicSalt(email);
      final derivedKeys = await CryptoEngine.deriveKeys(
        masterPassword: 'ClaveMaestraSuperSegura123!#',
        salt: salt,
      );
      final originalMek = derivedKeys.masterEncryptionKey;
      final originalMekBytes = await originalMek.extractBytes();

      final recoveryKey = RecoveryKitService.generateRecoveryKey();

      // Cifrar MEK con la Clave de Rescate
      final encryptedPayload = await RecoveryKitService.encryptMekForRecovery(
        masterEncryptionKey: originalMek,
        recoveryKey: recoveryKey,
        salt: salt,
      );

      // Guardar datos
      await RecoveryKitService.saveRecoveryData(
        email: email,
        payload: encryptedPayload,
        recoveryKey: recoveryKey,
      );

      expect(await RecoveryKitService.hasRecoveryKit(email), isTrue);
      final savedKey = await RecoveryKitService.getSavedRecoveryKey(email);
      expect(savedKey, equals(RecoveryKitService.normalizeKey(recoveryKey)));

      // Descifrar MEK con la Clave de Rescate correcta
      final recoveredMek = await RecoveryKitService.decryptMekFromRecovery(
        recoveryPayload: encryptedPayload,
        recoveryKey: recoveryKey,
        salt: salt,
      );

      expect(recoveredMek, isNotNull);
      final recoveredMekBytes = await recoveredMek!.extractBytes();
      expect(recoveredMekBytes, equals(originalMekBytes));
    });

    test('Intento de descifrado con una Clave de Rescate errónea falla rotundamente (Zero-Knowledge)', () async {
      final email = 'victima@novakey.com';
      final salt = await CryptoEngine.deriveDeterministicSalt(email);
      final derivedKeys = await CryptoEngine.deriveKeys(
        masterPassword: 'Password!12345678',
        salt: salt,
      );

      final legitimateKey = RecoveryKitService.generateRecoveryKey();
      final attackerKey = RecoveryKitService.generateRecoveryKey();

      final encryptedPayload = await RecoveryKitService.encryptMekForRecovery(
        masterEncryptionKey: derivedKeys.masterEncryptionKey,
        recoveryKey: legitimateKey,
        salt: salt,
      );

      final failedMek = await RecoveryKitService.decryptMekFromRecovery(
        recoveryPayload: encryptedPayload,
        recoveryKey: attackerKey,
        salt: salt,
      );

      expect(failedMek, isNull);
    });

    test('Generación de plantilla HTML imprimible para el Kit Oficial de Rescate', () {
      final email = 'test.recovery@novakey.security';
      final key = RecoveryKitService.generateRecoveryKey();

      final html = RecoveryKitService.generateKitDocumentHtml(
        email: email,
        recoveryKey: key,
      );

      expect(html, contains('NovaKey - Kit de Rescate de Emergencia'));
      expect(html, contains(email));
      expect(html, contains(key));
      expect(html, contains('Tech Innova'));
      expect(html, contains('+51 947 515 529'));
    });
  });
}
