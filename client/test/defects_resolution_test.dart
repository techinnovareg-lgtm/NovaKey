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
  });
}
