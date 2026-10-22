import 'package:flutter_test/flutter_test.dart';
import 'package:client/core/crypto/crypto_engine.dart';
import 'package:client/features/vault/models/vault_item.dart';

void main() {
  group('6. Pruebas de Rendimiento (Performance Testing) - Metodología Atlassian', () {
    test('PB-01: Tiempo de respuesta en derivación criptográfica Argon2id + HKDF', () async {
      final salt = CryptoEngine.generateRandomSalt(32);
      final stopwatch = Stopwatch()..start();

      final keys = await CryptoEngine.deriveKeys(
        masterPassword: 'HighEntropyMasterPassword#2026',
        salt: salt,
        memory: 1024,
        iterations: 1,
        parallelism: 1,
      );

      stopwatch.stop();
      final elapsedMs = stopwatch.elapsedMilliseconds;

      expect(keys.authHashHex, isNotEmpty);
      expect(elapsedMs, lessThan(1000),
          reason: 'La derivación de clave debe completarse en menos de 1000ms para garantizar fluidez');
    });

    test('PB-02: Rendimiento de cifrado y descifrado en masa (50 credenciales consecutivas)', () async {
      final salt = CryptoEngine.generateRandomSalt(32);
      final keys = await CryptoEngine.deriveKeys(
        masterPassword: 'PerformanceBulkKey#2026',
        salt: salt,
        memory: 1024,
        iterations: 1,
        parallelism: 1,
      );

      final items = List.generate(
        50,
        (i) => VaultItem(
          title: 'Servicio Web #$i',
          username: 'usuario_$i@empresa.com',
          password: 'Password_Segura_$i#%!',
          websiteUrl: 'https://app-$i.empresa.com',
          notes: 'Nota cifrada del registro número $i con detalles de acceso',
        ),
      );

      // Medir Cifrado en masa
      final encryptWatch = Stopwatch()..start();
      final encryptedPayloads = <EncryptedPayload>[];

      for (final item in items) {
        final payload = await CryptoEngine.encrypt(
          plainText: item.toSensitiveJson(),
          key: keys.masterEncryptionKey,
        );
        encryptedPayloads.add(payload);
      }
      encryptWatch.stop();

      expect(encryptedPayloads.length, equals(50));
      expect(encryptWatch.elapsedMilliseconds, lessThan(800),
          reason: 'El cifrado de 50 registros debe tomar menos de 800ms');

      // Medir Descifrado en masa
      final decryptWatch = Stopwatch()..start();
      final decryptedCount = <String>[];

      for (final payload in encryptedPayloads) {
        final plainJson = await CryptoEngine.decrypt(
          payload: payload,
          key: keys.masterEncryptionKey,
        );
        decryptedCount.add(plainJson);
      }
      decryptWatch.stop();

      expect(decryptedCount.length, equals(50));
      expect(decryptWatch.elapsedMilliseconds, lessThan(800),
          reason: 'El descifrado de 50 registros debe tomar menos de 800ms');
    });

    test('PB-03: Latencia ultra-baja en búsqueda y filtrado de 500 credenciales en memoria', () {
      final largeVault = List.generate(
        500,
        (i) => VaultItem(
          title: i == 420 ? 'Mikrotik Core Router' : 'Cuenta de Acceso Sistema #$i',
          username: 'user_$i@dominio.com',
          password: 'pwd_$i',
          websiteUrl: 'https://portal-$i.intranet.local',
          notes: i == 420 ? 'Ubicación rack principal datacenter' : 'Nota regular',
          category: i % 2 == 0 ? 'login' : 'device',
          isFavorite: i % 10 == 0,
        ),
      );

      final searchWatch = Stopwatch()..start();
      const query = 'mikrotik';

      final results = largeVault.where((item) {
        return item.title.toLowerCase().contains(query) ||
            item.username.toLowerCase().contains(query) ||
            item.websiteUrl.toLowerCase().contains(query) ||
            item.notes.toLowerCase().contains(query);
      }).toList();

      searchWatch.stop();

      expect(results.length, equals(1));
      expect(results.first.title, equals('Mikrotik Core Router'));
      expect(searchWatch.elapsedMilliseconds, lessThan(15),
          reason: 'La búsqueda en memoria debe ejecutarse en menos de 15ms (tiempo de frame 60fps)');
    });
  });
}
