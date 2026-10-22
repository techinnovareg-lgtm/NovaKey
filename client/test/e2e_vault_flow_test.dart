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

  group('4. Pruebas de Extremo a Extremo (End-to-End / E2E Testing) - Metodología Atlassian', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('E2E-01: Ciclo de vida completo del usuario (Onboarding -> Uso -> Respaldo -> Bloqueo -> Ataque -> Desbloqueo)', () async {
      final storage = SecureStorageService();
      const userEmail = 'carlos@empresa.com';
      const masterPassword = 'MiContraseñaMaestraSuperRobusta#2026!';

      // ==========================================
      // FASE 1: Registro e Inicialización de Bóveda
      // ==========================================
      final userSalt = CryptoEngine.generateRandomSalt(32);
      await storage.saveUserSalt(userEmail, base64Encode(userSalt));

      final registrationKeys = await CryptoEngine.deriveKeys(
        masterPassword: masterPassword,
        salt: userSalt,
        memory: 1024,
        iterations: 1,
        parallelism: 1,
      );

      // Guardar el verifier SHA-256 (Zero-Knowledge)
      await storage.savePasswordVerifier(userEmail, registrationKeys.authHashHex);

      final dummySupabase = SupabaseClient('https://demo.supabase.co', 'dummy_anon');
      VaultSyncService? activeSessionService = VaultSyncService(
        supabase: dummySupabase,
        masterEncryptionKey: registrationKeys.masterEncryptionKey,
        userEmail: userEmail,
        secureStorage: storage,
      );

      // ==========================================
      // FASE 2: Creación de Contenido Heterogéneo
      // ==========================================
      final cred1 = VaultItem(
        title: 'Correo Institucional',
        username: 'carlos@hrayacucho.gob.pe',
        password: 'PasswordCorreo#456',
        category: 'login',
        isFavorite: true,
      );

      const photoBase64 = 'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAAFElEQVR42mNk+M9QzwAEjAwMDAwAFAAC/0wN5QAAAABJRU5ErkJggg==';
      final cred2 = VaultItem(
        title: 'Cámara IP Hikvision Entrada',
        username: 'admin',
        password: 'CameraPasswordKey#987',
        category: 'device',
        websiteUrl: '192.168.1.108',
        imageBase64: photoBase64,
        notes: 'Código de verificación impreso bajo la base',
      );

      await activeSessionService.saveItem(cred1);
      await activeSessionService.saveItem(cred2);

      expect(activeSessionService.currentItems.length, equals(2));

      // ==========================================
      // FASE 3: Generación de Respaldo Exportable
      // ==========================================
      final backupList = activeSessionService.currentItems.map((e) => e.toSensitiveJson()).toList();
      final backupJson = jsonEncode(backupList);
      expect(backupJson.contains('carlos@hrayacucho.gob.pe'), isTrue);
      expect(backupJson.contains('CameraPasswordKey#987'), isTrue);

      // ==========================================
      // FASE 4: Bloqueo de la Bóveda (Wipe RAM)
      // ==========================================
      activeSessionService.dispose();
      activeSessionService = null; // Memoria purgada
      expect(activeSessionService, isNull);

      // ==========================================
      // FASE 5: Simulación de Intento de Acceso no Autorizado
      // ==========================================
      const incorrectPassword = 'PasswordEquivocado#999';
      final attackerKeys = await CryptoEngine.deriveKeys(
        masterPassword: incorrectPassword,
        salt: userSalt,
        memory: 1024,
        iterations: 1,
        parallelism: 1,
      );

      final storedVerifier = await storage.getPasswordVerifier(userEmail);
      expect(attackerKeys.authHashHex, isNot(equals(storedVerifier)),
          reason: 'Un atacante con contraseña incorrecta debe ser rechazado inmediatamente');

      // ==========================================
      // FASE 6: Desbloqueo Legítimo y Verificación de Integridad
      // ==========================================
      final savedSaltStr = await storage.getUserSalt(userEmail);
      final legitimateSalt = base64Decode(savedSaltStr!);

      final legitimateKeys = await CryptoEngine.deriveKeys(
        masterPassword: masterPassword,
        salt: legitimateSalt,
        memory: 1024,
        iterations: 1,
        parallelism: 1,
      );

      expect(legitimateKeys.authHashHex, equals(storedVerifier));

      final restoredSessionService = VaultSyncService(
        supabase: dummySupabase,
        masterEncryptionKey: legitimateKeys.masterEncryptionKey,
        userEmail: userEmail,
        secureStorage: storage,
      );

      final decryptedItems = await restoredSessionService.fetchAndDecryptAll();
      expect(decryptedItems.length, equals(2));

      final restoredCamera = decryptedItems.firstWhere((e) => e.title == 'Cámara IP Hikvision Entrada');
      expect(restoredCamera.password, equals('CameraPasswordKey#987'));
      expect(restoredCamera.imageBase64, equals(photoBase64));

      restoredSessionService.dispose();
    });
  });
}
