import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:client/core/crypto/crypto_engine.dart';
import 'package:client/core/security/secure_storage_service.dart';
import 'package:client/features/vault/models/vault_category.dart';
import 'package:client/features/vault/models/vault_item.dart';
import 'package:client/features/vault/services/vault_sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Gestión y Filtrado de Categorías Personalizadas en NovaKey', () {
    late SecureStorageService storage;
    late VaultSyncService syncService;
    const testEmail = 'categories.test@novakey.security';

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = SecureStorageService();

      final salt = CryptoEngine.generateRandomSalt();
      final keys = await CryptoEngine.deriveKeys(
        masterPassword: 'MasterCategoryPassword!2026',
        salt: salt,
        memory: 1024,
        iterations: 1,
        parallelism: 1,
      );

      syncService = VaultSyncService(
        supabase: SupabaseClient('https://demo.supabase.co', 'dummy_anon_key'),
        masterEncryptionKey: keys.masterEncryptionKey,
        userEmail: testEmail,
        secureStorage: storage,
      );
    });

    test('Deducción inteligente de íconos según nombre de categoría', () {
      expect(VaultCategory.getIconForName('Bancos y Tarjetas'), equals(VaultCategory.defaultCategories[0].icon));
      expect(VaultCategory.getIconForName('Tiendas por departamento Ripley'), equals(VaultCategory.defaultCategories[2].icon));
      expect(VaultCategory.getIconForName('Correos Corporativos'), equals(VaultCategory.defaultCategories[1].icon));
      expect(VaultCategory.getIconForName('Routers y Cámaras'), equals(VaultCategory.defaultCategories[3].icon));
    });

    test('Creación, persistencia y eliminación de categorías personalizadas', () async {
      // 1. Agregar categorías
      await syncService.addCustomCategory('Bancos');
      await syncService.addCustomCategory('Tiendas por departamento');
      await syncService.addCustomCategory('Streaming y Ocio');

      expect(syncService.customCategories.contains('Bancos'), isTrue);
      expect(syncService.customCategories.contains('Tiendas por departamento'), isTrue);
      expect(syncService.customCategories.contains('Streaming y Ocio'), isTrue);

      // 2. Verificar que se persistieron en SecureStorage
      final savedCats = await storage.getCustomCategories(testEmail);
      expect(savedCats.contains('Bancos'), isTrue);
      expect(savedCats.contains('Tiendas por departamento'), isTrue);
      expect(savedCats.contains('Streaming y Ocio'), isTrue);

      // 3. Eliminar una categoría
      await syncService.deleteCustomCategory('Streaming y Ocio');
      expect(syncService.customCategories.contains('Streaming y Ocio'), isFalse);
      final updatedSaved = await storage.getCustomCategories(testEmail);
      expect(updatedSaved.contains('Streaming y Ocio'), isFalse);
    });

    test('Asignación de categoría a credencial y filtrado de elementos', () async {
      await syncService.addCustomCategory('Bancos');
      await syncService.addCustomCategory('Tiendas por departamento');

      // Crear credenciales en diferentes categorías
      final bcpItem = VaultItem(
        title: 'BCP Token',
        username: 'user_bcp',
        password: 'pass_bcp_123',
        category: 'Bancos',
      );

      final ripleyItem = VaultItem(
        title: 'Ripley Online',
        username: 'user_ripley',
        password: 'pass_ripley_123',
        category: 'Tiendas por departamento',
      );

      final correoItem = VaultItem(
        title: 'Gmail Personal',
        username: 'me@gmail.com',
        password: 'pass_gmail_123',
        category: 'correo',
      );

      await syncService.saveItem(bcpItem);
      await syncService.saveItem(ripleyItem);
      await syncService.saveItem(correoItem);

      // Descifrar y recuperar
      final items = await syncService.fetchAndDecryptAll();
      expect(items.length, equals(3));

      // Filtrar por Bancos
      final bancosItems = items.where((i) => i.category.toLowerCase() == 'bancos').toList();
      expect(bancosItems.length, equals(1));
      expect(bancosItems.first.title, equals('BCP Token'));

      // Filtrar por Tiendas por departamento
      final tiendasItems = items.where((i) => i.category.toLowerCase() == 'tiendas por departamento').toList();
      expect(tiendasItems.length, equals(1));
      expect(tiendasItems.first.title, equals('Ripley Online'));
    });
  });
}
