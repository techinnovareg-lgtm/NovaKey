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

  group('3. Pruebas Funcionales (Functional Testing) - Metodología Atlassian', () {
    late SecureStorageService storage;
    late VaultSyncService syncService;
    const email = 'func_user@novakey.app';

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = SecureStorageService();

      final salt = CryptoEngine.generateRandomSalt();
      await storage.saveUserSalt(email, base64Encode(salt));

      final keys = await CryptoEngine.deriveKeys(
        masterPassword: 'FunctionalTestPassword2026!',
        salt: salt,
        memory: 1024,
        iterations: 1,
        parallelism: 1,
      );

      final dummySupabase = SupabaseClient('https://demo.supabase.co', 'dummy_anon');
      syncService = VaultSyncService(
        supabase: dummySupabase,
        masterEncryptionKey: keys.masterEncryptionKey,
        userEmail: email,
        secureStorage: storage,
      );
    });

    tearDown(() {
      syncService.dispose();
    });

    test('RF-01: CRUD Completo de credenciales y notas seguras', () async {
      // 1. Create (Creación)
      final item = VaultItem(
        title: 'Banca por Internet',
        username: 'cliente_banco_01',
        password: 'ClaveSuperSegura#99',
        category: 'login',
        isFavorite: false,
      );
      await syncService.saveItem(item);
      expect(syncService.currentItems.length, equals(1));

      // 2. Read (Lectura)
      final fetched = syncService.currentItems.firstWhere((e) => e.id == item.id);
      expect(fetched.title, equals('Banca por Internet'));
      expect(fetched.password, equals('ClaveSuperSegura#99'));

      // 3. Update (Actualización)
      final updatedItem = fetched.copyWith(
        title: 'Banca por Internet (BCP)',
        password: 'NuevaClaveSegura#100',
        isFavorite: true,
      );
      await syncService.saveItem(updatedItem);
      expect(syncService.currentItems.length, equals(1));
      expect(syncService.currentItems.first.title, equals('Banca por Internet (BCP)'));
      expect(syncService.currentItems.first.isFavorite, isTrue);

      // 4. Delete (Eliminación)
      await syncService.deleteItem(item.id);
      expect(syncService.currentItems.isEmpty, isTrue);
    });

    test('RF-02: Soporte funcional para dispositivos con foto de etiqueta física', () async {
      // Imagen simulada en base64 de etiqueta física (ej. Módem Fibra Óptica)
      const mockStickerImageBase64 = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

      final device = VaultItem(
        title: 'Módem Huawei HG8145V5',
        username: 'Admin',
        password: 'ClaveImpresaEnReverso#4321',
        websiteUrl: '192.168.1.1',
        category: 'device',
        imageBase64: mockStickerImageBase64,
        notes: 'Código de serie impreso en la etiqueta trasera',
      );

      await syncService.saveItem(device);

      final saved = syncService.currentItems.first;
      expect(saved.category, equals('device'));
      expect(saved.imageBase64, equals(mockStickerImageBase64));
      expect(saved.websiteUrl, equals('192.168.1.1'));
    });

    test('RF-03: Filtrado y agrupación por categorías de negocio', () async {
      await syncService.saveItem(VaultItem(title: 'Gmail Personal', username: 'user1', password: 'p1', category: 'login'));
      await syncService.saveItem(VaultItem(title: 'Router Sala', username: 'admin', password: 'p2', category: 'device'));
      await syncService.saveItem(VaultItem(title: 'Cámara Patio', username: 'cam_user', password: 'p3', category: 'device', isFavorite: true));
      await syncService.saveItem(VaultItem(title: 'PIN Respaldo', username: 'pin', password: 'p4', category: 'note'));

      final all = syncService.currentItems;
      final logins = all.where((e) => e.category == 'login').toList();
      final devices = all.where((e) => e.category == 'device').toList();
      final notes = all.where((e) => e.category == 'note').toList();
      final favorites = all.where((e) => e.isFavorite).toList();

      expect(all.length, equals(4));
      expect(logins.length, equals(1));
      expect(devices.length, equals(2));
      expect(notes.length, equals(1));
      expect(favorites.length, equals(1));
      expect(favorites.first.title, equals('Cámara Patio'));
    });

    test('RF-04: Búsqueda dinámica insensible a mayúsculas y minúsculas', () async {
      await syncService.saveItem(VaultItem(title: 'AWS Console', username: 'devops_lead', password: 'aws_password_123'));
      await syncService.saveItem(VaultItem(title: 'Router Mikrotik', username: 'admin', password: 'mikrotik_pass', websiteUrl: '192.168.88.1'));
      await syncService.saveItem(VaultItem(title: 'GitHub Enterprise', username: 'git_user', password: 'git_password_456', notes: 'Token de despliegue'));

      const query1 = 'mikrotik';
      final results1 = syncService.currentItems.where((i) =>
        i.title.toLowerCase().contains(query1) ||
        i.username.toLowerCase().contains(query1) ||
        i.websiteUrl.toLowerCase().contains(query1) ||
        i.notes.toLowerCase().contains(query1)
      ).toList();

      expect(results1.length, equals(1));
      expect(results1.first.title, equals('Router Mikrotik'));

      const query2 = 'devops';
      final results2 = syncService.currentItems.where((i) =>
        i.title.toLowerCase().contains(query2) ||
        i.username.toLowerCase().contains(query2)
      ).toList();

      expect(results2.length, equals(1));
      expect(results2.first.title, equals('AWS Console'));
    });
  });
}
