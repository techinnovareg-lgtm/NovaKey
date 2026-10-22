import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:client/core/crypto/crypto_engine.dart';
import 'package:client/core/security/secure_storage_service.dart';
import 'package:client/features/vault/models/vault_item.dart';
import 'package:client/features/vault/services/vault_sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Vault Persistence & Lock-Unlock Flow Test', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Items persist and decrypt properly after locking and unlocking', () async {
      const email = 'usuario@prueba.com';
      const password = 'MiPasswordSeguro123!';

      final storage = SecureStorageService();

      // --- SESIÓN 1: Registro e Importación ---
      // 1. Derivar sal
      final initialSalt = CryptoEngine.generateRandomSalt();
      await storage.saveUserSalt(email, base64Encode(initialSalt));

      final keys1 = await CryptoEngine.deriveKeys(
        masterPassword: password,
        salt: initialSalt,
        memory: 1024,
        iterations: 1,
        parallelism: 1,
      );

      final dummySupabase = SupabaseClient('https://demo.supabase.co', 'dummy_anon_key');
      final syncService1 = VaultSyncService(
        supabase: dummySupabase,
        masterEncryptionKey: keys1.masterEncryptionKey,
        userEmail: email,
        secureStorage: storage,
      );

      // Guardar dos credenciales
      final item1 = VaultItem(
        title: 'Gmail',
        username: 'car123@gmail.com',
        password: 'password123',
      );
      final item2 = VaultItem(
        title: 'Hotmail',
        username: 'hafgt1122@hotmail.com',
        password: 'passwordhot123',
      );

      await syncService1.saveItem(item1);
      await syncService1.saveItem(item2);

      expect(syncService1.currentItems.length, equals(2));

      // --- ACCIÓN: BLOQUEO (Candado rojo) ---
      syncService1.dispose();

      // --- SESIÓN 2: Desbloqueo ---
      // 1. Obtener la sal guardada
      final savedSaltBase64 = await storage.getUserSalt(email);
      expect(savedSaltBase64, isNotNull);
      final retrievedSalt = base64Decode(savedSaltBase64!);

      // 2. Re-derivar la clave con la misma contraseña y la sal recuperada
      final keys2 = await CryptoEngine.deriveKeys(
        masterPassword: password,
        salt: retrievedSalt,
        memory: 1024,
        iterations: 1,
        parallelism: 1,
      );

      // 3. Crear nuevo VaultSyncService
      final syncService2 = VaultSyncService(
        supabase: dummySupabase,
        masterEncryptionKey: keys2.masterEncryptionKey,
        userEmail: email,
        secureStorage: storage,
      );

      // 4. Descifrar
      final restoredItems = await syncService2.fetchAndDecryptAll();

      // 5. Verificación
      expect(restoredItems.length, equals(2));
      expect(restoredItems[0].title, anyOf(equals('Gmail'), equals('Hotmail')));
      expect(restoredItems[1].title, anyOf(equals('Gmail'), equals('Hotmail')));
    });

    test('Device item with attached sticker/label photo encrypts and decrypts with AES-256-GCM', () async {
      const email = 'admin@redes.com';
      const password = 'RouterPassword2026!';
      final storage = SecureStorageService();

      final salt = CryptoEngine.generateRandomSalt();
      final keys = await CryptoEngine.deriveKeys(
        masterPassword: password,
        salt: salt,
        memory: 1024,
        iterations: 1,
        parallelism: 1,
      );

      final dummySupabase = SupabaseClient('https://demo.supabase.co', 'dummy_anon_key');
      final syncService = VaultSyncService(
        supabase: dummySupabase,
        masterEncryptionKey: keys.masterEncryptionKey,
        userEmail: email,
        secureStorage: storage,
      );

      // Foto simulada en Base64 de la etiqueta de un módem/cámara
      final fakeImageBase64 = base64Encode(utf8.encode('SIMULATED_ROUTER_STICKER_PHOTO_BYTES_PNG'));

      final deviceItem = VaultItem(
        title: 'Módem Fibra Óptica Sala',
        username: 'admin / Movistar-4G_5G',
        password: 'WiFiPasswordKey9988',
        websiteUrl: '192.168.1.1',
        category: 'device',
        notes: 'Serial: SN9982348 | MAC: 00:1A:2B:3C:4D:5E',
        imageBase64: fakeImageBase64,
      );

      await syncService.saveItem(deviceItem);
      expect(syncService.currentItems.length, equals(1));

      // Descifrar directamente desde almacenamiento local persistente
      final restored = await syncService.fetchAndDecryptAll();
      expect(restored.length, equals(1));
      expect(restored.first.title, equals('Módem Fibra Óptica Sala'));
      expect(restored.first.category, equals('device'));
      expect(restored.first.imageBase64, equals(fakeImageBase64));
      expect(restored.first.notes, contains('SN9982348'));
    });

    test('Password verifier successfully distinguishes between correct and incorrect password', () async {
      const email = 'seguridad@empresa.com';
      const correctPassword = 'PasswordCorrecto123!';
      const wrongPassword = 'PasswordIncorrecto999!';
      final storage = SecureStorageService();

      final salt = CryptoEngine.generateRandomSalt();
      await storage.saveUserSalt(email, base64Encode(salt));

      // 1. Registro con contraseña correcta: generar y guardar verifier
      final correctKeys = await CryptoEngine.deriveKeys(
        masterPassword: correctPassword,
        salt: salt,
        memory: 1024,
        iterations: 1,
        parallelism: 1,
      );
      await storage.savePasswordVerifier(email, correctKeys.authHashHex);

      // 2. Intento con contraseña errónea
      final candidateWrongKeys = await CryptoEngine.deriveKeys(
        masterPassword: wrongPassword,
        salt: salt,
        memory: 1024,
        iterations: 1,
        parallelism: 1,
      );

      final savedVerifier = await storage.getPasswordVerifier(email);
      expect(savedVerifier, isNotNull);
      // El verifier debe ser diferente: rechazo garantizado
      expect(candidateWrongKeys.authHashHex, isNot(equals(savedVerifier)));

      // 3. Intento con contraseña correcta
      final candidateCorrectKeys = await CryptoEngine.deriveKeys(
        masterPassword: correctPassword,
        salt: salt,
        memory: 1024,
        iterations: 1,
        parallelism: 1,
      );
      expect(candidateCorrectKeys.authHashHex, equals(savedVerifier));
    });

    test('Strict user vault isolation: access is constrained only to the authenticated email', () async {
      final storage = SecureStorageService();

      await storage.saveLocalEncryptedVault('usuario1@gmail.com', jsonEncode([{'id': '1', 'title': 'Test1'}]));
      await storage.saveLocalEncryptedVault('usuario2@empresa.com', jsonEncode([{'id': '2', 'title': 'Test2'}]));

      final vaultUser1 = await storage.getLocalEncryptedVault('usuario1@gmail.com');
      final vaultUser3 = await storage.getLocalEncryptedVault('usuario3@desconocido.com');

      expect(vaultUser1, isNotNull);
      expect(vaultUser1, contains('Test1'));
      expect(vaultUser3, isNull);
    });
  });
}
