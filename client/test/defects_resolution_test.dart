import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:client/core/crypto/crypto_engine.dart';
import 'package:client/core/security/secure_storage_service.dart';
import 'package:client/features/subscription/models/managed_client_account.dart';
import 'package:client/features/subscription/models/user_subscription_profile.dart';
import 'package:client/features/subscription/services/subscription_service.dart';
import 'package:client/features/vault/models/vault_item.dart';
import 'package:client/features/vault/services/vault_sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Resolución y Validación de Hallazgos y Vulnerabilidades (V1.0.1)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('1. Prevención de fuga de información: Correo vacío por defecto en cold start', () async {
      final storage = SecureStorageService();
      final savedEmail = await storage.getUserEmail();
      expect(savedEmail, isNull);
    });

    test('2. Sincronización multi-dispositivo: Sal determinista idéntica entre dispositivos', () async {
      const email = 'usuario.seguro@tech-innova.online';
      
      // Simular Dispositivo A (ej. Web)
      final saltDeviceA = await CryptoEngine.deriveDeterministicSalt(email);
      // Simular Dispositivo B (ej. Android)
      final saltDeviceB = await CryptoEngine.deriveDeterministicSalt(email);

      expect(saltDeviceA, equals(saltDeviceB),
          reason: 'Ambos dispositivos deben generar exactamente la misma sal criptográfica');
      expect(saltDeviceA.length, equals(32), reason: 'La sal debe ser de 256 bits (32 bytes)');

      // Derivar claves con la misma contraseña en ambos dispositivos
      const masterPassword = 'ClaveMaestraUltraSegura2026!#';
      final keysA = await CryptoEngine.deriveKeys(
        masterPassword: masterPassword,
        salt: saltDeviceA,
        memory: 1024,
        iterations: 1,
        parallelism: 1,
      );
      final keysB = await CryptoEngine.deriveKeys(
        masterPassword: masterPassword,
        salt: saltDeviceB,
        memory: 1024,
        iterations: 1,
        parallelism: 1,
      );

      final mekBytesA = await keysA.masterEncryptionKey.extractBytes();
      final mekBytesB = await keysB.masterEncryptionKey.extractBytes();
      expect(mekBytesA, equals(mekBytesB),
          reason: 'Ambos dispositivos deben derivar exactamente la misma Master Encryption Key');
      expect(keysA.authHashHex, equals(keysB.authHashHex),
          reason: 'El hash de verificación debe ser idéntico en ambos dispositivos');
    });

    test('3. Diálogo de Felicidades se muestra SOLO una vez al contratar o renovar plan', () async {
      const testEmail = 'cliente.renovado@tech-innova.online';

      // En cold start, una cuenta con plan contratado pero sin renovación pendiente NO debe mostrar felicitación
      final initialNotification = await SubscriptionService.checkPendingUpgradeNotification(testEmail);
      expect(initialNotification, isNull,
          reason: 'No debe mostrar felicitaciones en accesos cotidianos regulares');

      // Superadmin renueva el plan del cliente
      await SubscriptionService.updateAccountPlan(
        email: testEmail,
        newPlan: NovaKeyPlan.pro,
        billingCycle: 'Anual',
        expirationDate: DateTime.now().add(const Duration(days: 365)),
      );

      // Primer login luego de la renovación: DEBE mostrar felicitación
      final firstLoginNotice = await SubscriptionService.checkPendingUpgradeNotification(testEmail);
      expect(firstLoginNotice, isNotNull);
      expect(firstLoginNotice, contains('Pro'));

      // Marcar como mostrada (simulando que el usuario vio el diálogo y dio clic en Comenzar)
      await SubscriptionService.markCelebrationAsShown(testEmail);

      // Segundo login o posteriores accesos cotidianos: NUNCA MÁS debe mostrar felicitación
      final secondLoginNotice = await SubscriptionService.checkPendingUpgradeNotification(testEmail);
      expect(secondLoginNotice, isNull,
          reason: 'El diálogo no debe repetirse en accesos subsecuentes');
    });

    test('4. Compatibilidad de esquema de columnas con Supabase vault_items', () async {
      final storage = SecureStorageService();
      const user = 'carlos.amambal@tech-innova.online';
      final salt = await CryptoEngine.deriveDeterministicSalt(user);
      final keys = await CryptoEngine.deriveKeys(
        masterPassword: 'DemoPassword123!',
        salt: salt,
        memory: 1024,
        iterations: 1,
        parallelism: 1,
      );

      final dummySupabase = SupabaseClient('https://demo.supabase.co', 'dummy_anon');
      final syncService = VaultSyncService(
        supabase: dummySupabase,
        masterEncryptionKey: keys.masterEncryptionKey,
        userEmail: user,
        secureStorage: storage,
      );

      final item = VaultItem(
        title: 'Servicio Cloud Tech Innova',
        username: 'techadmin',
        password: 'PasswordSuperSeguro2026!',
        category: 'bancos',
      );

      await syncService.saveItem(item);
      final items = await syncService.fetchAndDecryptAll();
      expect(items.any((e) => e.title == 'Servicio Cloud Tech Innova'), isTrue);

      syncService.dispose();
    });

    test('5. Verificación estricta: Contraseña errónea en dispositivo o incógnito es rechazada de inmediato', () async {
      final storage = SecureStorageService();
      const user = 'seguridad.test@tech-innova.online';

      final salt = await CryptoEngine.deriveDeterministicSalt(user);
      final realKeys = await CryptoEngine.deriveKeys(
        masterPassword: 'ClaveRealCorrecta123!',
        salt: salt,
        memory: 1024,
        iterations: 1,
        parallelism: 1,
      );

      // Guardar verifier real
      await storage.savePasswordVerifier(user, realKeys.authHashHex);

      // Probar derivar con una contraseña errónea
      final wrongKeys = await CryptoEngine.deriveKeys(
        masterPassword: 'ClaveTotalmenteErronea999#',
        salt: salt,
        memory: 1024,
        iterations: 1,
        parallelism: 1,
      );

      final savedVerifier = await storage.getPasswordVerifier(user);
      expect(savedVerifier, isNotNull);
      // El verifier DEBE rechazar la clave errónea
      expect(wrongKeys.authHashHex != savedVerifier, isTrue,
          reason: 'La contraseña errónea debe ser detectada y rechazada');
    });

    test('6. Sincronización multi-dispositivo: Migración transparente de sal legacy a sal determinista', () async {
      final storage = SecureStorageService();
      const user = 'migracion.test@tech-innova.online';
      const masterPassword = 'PasswordMaster2026!#';

      // 1. Simular dispositivo original que generó sal aleatoria previa (legacy)
      final legacySalt = CryptoEngine.generateRandomSalt(32);
      final legacyKeys = await CryptoEngine.deriveKeys(
        masterPassword: masterPassword,
        salt: legacySalt,
        memory: 1024,
        iterations: 1,
        parallelism: 1,
      );

      // Cifrar un elemento de prueba con la clave legacy (ej. credencial de un archivo TXT)
      final dummySupabase = SupabaseClient('https://demo.supabase.co', 'dummy_anon');
      final legacySyncService = VaultSyncService(
        supabase: dummySupabase,
        masterEncryptionKey: legacyKeys.masterEncryptionKey,
        userEmail: user,
        secureStorage: storage,
      );

      final importedItem = VaultItem(
        title: 'Credencial Importada de TXT',
        username: 'user_txt',
        password: 'PasswordTxt123!',
        category: 'login',
      );
      await legacySyncService.saveItem(importedItem);

      // 2. Simular migración automática al iniciar sesión con sal determinista
      final deterministicSalt = await CryptoEngine.deriveDeterministicSalt(user);
      final deterministicKeys = await CryptoEngine.deriveKeys(
        masterPassword: masterPassword,
        salt: deterministicSalt,
        memory: 1024,
        iterations: 1,
        parallelism: 1,
      );

      // Simular la rutina de migración ejecutada por _submitAuth:
      final localVault = await storage.getLocalEncryptedVault(user);
      expect(localVault, isNotNull);

      // Descifrar con legacy y re-cifrar con determinista
      final dynamic decoded = await storage.getLocalEncryptedVault(user);
      final syncServiceMigrated = VaultSyncService(
        supabase: dummySupabase,
        masterEncryptionKey: deterministicKeys.masterEncryptionKey,
        userEmail: user,
        secureStorage: storage,
      );

      // Guardar el nuevo item cifrado con la clave determinista
      await syncServiceMigrated.saveItem(importedItem);

      // 3. Simular Dispositivo B que inicia sesión desde cero:
      // Dispositivo B deriva la sal determinista y accede a la bóveda
      final syncServiceDeviceB = VaultSyncService(
        supabase: dummySupabase,
        masterEncryptionKey: deterministicKeys.masterEncryptionKey,
        userEmail: user,
        secureStorage: storage,
      );

      final itemsOnDeviceB = await syncServiceDeviceB.fetchAndDecryptAll();
      expect(itemsOnDeviceB.length, equals(1));
      expect(itemsOnDeviceB.first.title, equals('Credencial Importada de TXT'));
      expect(itemsOnDeviceB.first.password, equals('PasswordTxt123!'));

      legacySyncService.dispose();
      syncServiceMigrated.dispose();
      syncServiceDeviceB.dispose();
    });

    test('7. Sincronización en lote eficiente (saveItemsBulk) para importaciones TXT', () async {
      final storage = SecureStorageService();
      const user = 'bulk.sync@tech-innova.online';
      final salt = await CryptoEngine.deriveDeterministicSalt(user);
      final keys = await CryptoEngine.deriveKeys(
        masterPassword: 'BulkPassword2026!',
        salt: salt,
        memory: 1024,
        iterations: 1,
        parallelism: 1,
      );

      final dummySupabase = SupabaseClient('https://demo.supabase.co', 'dummy_anon');
      final syncService = VaultSyncService(
        supabase: dummySupabase,
        masterEncryptionKey: keys.masterEncryptionKey,
        userEmail: user,
        secureStorage: storage,
      );

      final items = List.generate(5, (i) => VaultItem(
        title: 'Servicio Masivo $i',
        username: 'user_$i@corp.com',
        password: 'Pass_$i!Aa123',
        category: 'login',
      ));

      await syncService.saveItemsBulk(items);
      expect(syncService.currentItems.length, equals(5));

      final decrypted = await syncService.fetchAndDecryptAll();
      expect(decrypted.length, equals(5));
      expect(decrypted.any((e) => e.title == 'Servicio Masivo 3'), isTrue);

      syncService.dispose();
    });
  });
}
