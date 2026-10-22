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

  group('2. Pruebas de Integración (Integration Testing) - Metodología Atlassian', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Integración entre SecureStorageService, CryptoEngine y VaultSyncService', () async {
      const email = 'integration@tech-innova.online';
      const password = 'IntegrationSecurePassword2026!';
      final storage = SecureStorageService();

      // 1. Generación y almacenamiento persistente de sal
      final salt = CryptoEngine.generateRandomSalt();
      await storage.saveUserSalt(email, base64Encode(salt));

      // 2. Derivación de llaves con Argon2id
      final keys = await CryptoEngine.deriveKeys(
        masterPassword: password,
        salt: salt,
        memory: 1024,
        iterations: 1,
        parallelism: 1,
      );

      // Guardar verifier
      await storage.savePasswordVerifier(email, keys.authHashHex);

      // 3. Inicializar servicio de sincronización integrado con almacenamiento local
      final dummySupabase = SupabaseClient('https://demo.supabase.co', 'dummy_anon_key');
      final syncService = VaultSyncService(
        supabase: dummySupabase,
        masterEncryptionKey: keys.masterEncryptionKey,
        userEmail: email,
        secureStorage: storage,
      );

      // 4. Guardar credenciales a través del servicio
      final testItem = VaultItem(
        title: 'Servidor PostgreSQL',
        username: 'postgres_admin',
        password: 'SuperSecretDatabaseKey#2026',
        category: 'login',
        websiteUrl: '192.168.1.50:5432',
      );

      await syncService.saveItem(testItem);

      // 5. Verificar que el almacenamiento seguro subyacente guardó el blob cifrado
      final rawVaultJson = await storage.getLocalEncryptedVault(email);
      expect(rawVaultJson, isNotNull);
      expect(rawVaultJson!.contains('SuperSecretDatabaseKey#2026'), isFalse,
          reason: 'El almacenamiento persistente nunca debe contener contraseñas en plano');

      // 6. Verificar que el stream reactivo emite la credencial descifrada
      final currentList = syncService.currentItems;
      expect(currentList.length, equals(1));
      expect(currentList.first.title, equals('Servidor PostgreSQL'));
      expect(currentList.first.password, equals('SuperSecretDatabaseKey#2026'));

      syncService.dispose();
    });

    test('Integración de recuperación de sal y verifier hash para múltiples inicios de sesión', () async {
      const email = 'multi_session@novakey.com';
      const password = 'CorrectPassword#1';
      final storage = SecureStorageService();

      // Sesión 1: Registro
      final salt = CryptoEngine.generateRandomSalt();
      await storage.saveUserSalt(email, base64Encode(salt));

      final keys = await CryptoEngine.deriveKeys(
        masterPassword: password,
        salt: salt,
        memory: 1024,
        iterations: 1,
        parallelism: 1,
      );
      await storage.savePasswordVerifier(email, keys.authHashHex);

      // Sesión 2: Desbloqueo - Recuperar sal
      final retrievedSaltBase64 = await storage.getUserSalt(email);
      expect(retrievedSaltBase64, isNotNull);

      final reDerivedKeys = await CryptoEngine.deriveKeys(
        masterPassword: password,
        salt: base64Decode(retrievedSaltBase64!),
        memory: 1024,
        iterations: 1,
        parallelism: 1,
      );

      final savedVerifier = await storage.getPasswordVerifier(email);
      expect(reDerivedKeys.authHashHex, equals(savedVerifier),
          reason: 'El hash verificador debe coincidir perfectamente con la clave maestra');
    });
  });
}
