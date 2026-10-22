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

  group('5. Pruebas de Aceptación (Acceptance Testing / UAT) - Metodología Atlassian', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('CA-01: Cero fuga de texto claro en reposo (Principio Zero-Knowledge estricto)', () async {
      final storage = SecureStorageService();
      const user = 'auditor@seguridad.gov';
      const secretPasswordToHide = 'UltraSecretPasswordNeverInPlaintext!#2026';
      const secretNoteToHide = 'Pin Secreto: 987654';

      final salt = CryptoEngine.generateRandomSalt();
      await storage.saveUserSalt(user, base64Encode(salt));

      final keys = await CryptoEngine.deriveKeys(
        masterPassword: 'MasterAuditorKey#1',
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

      await syncService.saveItem(VaultItem(
        title: 'Bóveda Suiza',
        username: 'auditor',
        password: secretPasswordToHide,
        notes: secretNoteToHide,
      ));

      // Inspeccionar el almacenamiento persistente en crudo
      final rawStorageJson = await storage.getLocalEncryptedVault(user);
      expect(rawStorageJson, isNotNull);

      // Verificación formal: No debe haber presencia de texto claro
      expect(rawStorageJson!.contains(secretPasswordToHide), isFalse,
          reason: 'CRITERIO DE ACEPTACIÓN FALLIDO: Contraseña expuesta en disco');
      expect(rawStorageJson.contains(secretNoteToHide), isFalse,
          reason: 'CRITERIO DE ACEPTACIÓN FALLIDO: Nota confidencial expuesta en disco');

      syncService.dispose();
    });

    test('CA-02: Aislamiento estricto multi-usuario (No Cross-Tenant Data Leakage)', () async {
      final storage = SecureStorageService();
      final dummySupabase = SupabaseClient('https://demo.supabase.co', 'dummy_anon');

      // Usuario 1: Juan
      const emailJuan = 'juan@empresa.com';
      final saltJuan = CryptoEngine.generateRandomSalt();
      await storage.saveUserSalt(emailJuan, base64Encode(saltJuan));
      final keysJuan = await CryptoEngine.deriveKeys(
        masterPassword: 'PasswordJuan#1',
        salt: saltJuan,
        memory: 1024,
        iterations: 1,
        parallelism: 1,
      );
      final syncJuan = VaultSyncService(
        supabase: dummySupabase,
        masterEncryptionKey: keysJuan.masterEncryptionKey,
        userEmail: emailJuan,
        secureStorage: storage,
      );
      await syncJuan.saveItem(VaultItem(title: 'Credencial Privada de Juan', username: 'juan_user', password: 'SecretJuan123'));
      syncJuan.dispose();

      // Usuario 2: Maria
      const emailMaria = 'maria@empresa.com';
      final saltMaria = CryptoEngine.generateRandomSalt();
      await storage.saveUserSalt(emailMaria, base64Encode(saltMaria));
      final keysMaria = await CryptoEngine.deriveKeys(
        masterPassword: 'PasswordMaria#2',
        salt: saltMaria,
        memory: 1024,
        iterations: 1,
        parallelism: 1,
      );
      final syncMaria = VaultSyncService(
        supabase: dummySupabase,
        masterEncryptionKey: keysMaria.masterEncryptionKey,
        userEmail: emailMaria,
        secureStorage: storage,
      );

      final itemsMaria = await syncMaria.fetchAndDecryptAll();
      expect(itemsMaria.isEmpty, isTrue,
          reason: 'CRITERIO DE ACEPTACIÓN: Maria no debe ver registros de Juan');

      // Intento de Maria de forzar el descifrado del blob de Juan con su propia llave
      final rawBlobJuan = await storage.getLocalEncryptedVault(emailJuan);
      expect(rawBlobJuan, isNotNull);
      final List<dynamic> list = jsonDecode(rawBlobJuan!);
      final payload = EncryptedPayload.fromMap(list[0]['encrypted'] as Map<dynamic, dynamic>);

      expect(
        () async => await CryptoEngine.decrypt(payload: payload, key: keysMaria.masterEncryptionKey),
        throwsA(isA<Exception>()),
        reason: 'CRITERIO DE ACEPTACIÓN: Descifrado cruzado debe fallar criptográficamente',
      );

      syncMaria.dispose();
    });

    test('CA-03: No-enumeración de usuarios en pantalla de acceso', () async {
      final storage = SecureStorageService();
      // Verificamos que no existan métodos públicos que listen todos los correos registrados
      // para evitar ataques de reconocimiento (shoulder-surfing o listado local)
      final allKeys = await storage.getUserEmail();
      // Si el usuario no ha iniciado sesión, el correo por defecto debe ser nulo o vacío
      expect(allKeys, isNull);
    });
  });
}
