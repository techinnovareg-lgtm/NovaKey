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
  });
}
