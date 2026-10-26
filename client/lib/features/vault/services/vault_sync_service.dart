import 'dart:async';
import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/crypto/crypto_engine.dart';
import '../../../core/security/secure_storage_service.dart';
import '../models/vault_item.dart';

/// Estados de la sincronización en la nube con Supabase
enum CloudSyncStatus {
  synced,
  syncing,
  offline,
  error,
}

/// Servicio de Sincronización Local y en la Nube con arquitectura Zero-Knowledge y Offline-First
class VaultSyncService {
  final SupabaseClient _supabase;
  final SecretKey _masterEncryptionKey;
  final String userEmail;
  final SecureStorageService _secureStorage;
  RealtimeChannel? _realtimeSubscription;

  final _vaultItemsController = StreamController<List<VaultItem>>.broadcast();
  Stream<List<VaultItem>> get vaultItemsStream => _vaultItemsController.stream;

  final _categoriesController = StreamController<List<String>>.broadcast();
  Stream<List<String>> get categoriesStream => _categoriesController.stream;

  final _syncStatusController = StreamController<CloudSyncStatus>.broadcast();
  Stream<CloudSyncStatus> get syncStatusStream => _syncStatusController.stream;
  CloudSyncStatus _currentSyncStatus = CloudSyncStatus.offline;
  CloudSyncStatus get currentSyncStatus => _currentSyncStatus;

  void _updateSyncStatus(CloudSyncStatus status) {
    _currentSyncStatus = status;
    if (!_syncStatusController.isClosed) {
      _syncStatusController.add(status);
    }
  }

  List<String> _customCategories = [];
  List<String> get customCategories => List.unmodifiable(_customCategories);

  List<VaultItem> _cachedItems = [];
  List<VaultItem> get currentItems => List.unmodifiable(_cachedItems);
  SecretKey get masterEncryptionKey => _masterEncryptionKey;

  VaultSyncService({
    required SupabaseClient supabase,
    required SecretKey masterEncryptionKey,
    required this.userEmail,
    SecureStorageService? secureStorage,
  })  : _supabase = supabase,
        _masterEncryptionKey = masterEncryptionKey,
        _secureStorage = secureStorage ?? SecureStorageService();

  /// Determina si Supabase tiene credenciales reales configuradas (excluye mocks de pruebas)
  bool get isCloudConfigured {
    try {
      final url = _supabase.rest.url.toString();
      if (url.contains('ysnjstolpjszgjsmtjkc')) return true;
      if (url.contains('demo') || url.contains('dummy') || url.contains('example')) return false;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Asegura que la sesión de Supabase Auth esté activa utilizando la contraseña derivada
  Future<void> _ensureSupabaseSession() async {
    if (!isCloudConfigured) return;
    if (_supabase.auth.currentUser != null) return;

    try {
      final savedAuthPassword = await _secureStorage.getSavedAuthPassword(userEmail);
      if (savedAuthPassword != null && savedAuthPassword.isNotEmpty) {
        await _supabase.auth.signInWithPassword(
          email: userEmail.trim().toLowerCase(),
          password: savedAuthPassword,
        );
        debugPrint('✅ Sesión de Supabase Auth reconectada exitosamente para: $userEmail');
      }
    } catch (e) {
      debugPrint('Aviso al reconectar sesión en segundo plano con Supabase: $e');
    }
  }

  /// Inicializa la escucha de cambios en tiempo real vía WebSockets de Supabase
  void initializeRealtimeSync() {
    if (!isCloudConfigured) {
      _updateSyncStatus(CloudSyncStatus.offline);
      return;
    }

    try {
      _realtimeSubscription = _supabase
          .channel('public:vault_items')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'vault_items',
            callback: (payload) {
              debugPrint('⚡ Cambio en tiempo real detectado en Supabase, sincronizando bóveda...');
              fetchAndDecryptAll();
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Aviso: no se pudo iniciar WebSockets en tiempo real: $e');
    }
  }

  /// Descarga los registros cifrados DIRECTAMENTE desde la plataforma online Supabase
  Future<List<VaultItem>> fetchAndDecryptAll() async {
    final Map<String, VaultItem> itemMap = {};

    // 1. Asegurar sesión activa en Supabase Auth
    await _ensureSupabaseSession();
    final userId = _supabase.auth.currentUser?.id;

    // 2. MIGRACIÓN TRANSPARENTE Y PURGA PERMANENTE DE ALMACENAMIENTO LOCAL:
    // Si existe algún dato local previo (ej. TXT importado antes de la sincronización en la nube),
    // se descifra, se respalda de inmediato en la base de datos online de Supabase y se BORRA de local.
    try {
      final legacyLocalJson = await _secureStorage.getLocalEncryptedVault(userEmail);
      if (legacyLocalJson != null && legacyLocalJson.isNotEmpty) {
        debugPrint('🔄 Migrando y purgando bóveda local legacy hacia Supabase...');
        final List<dynamic> localList = jsonDecode(legacyLocalJson);
        final List<VaultItem> legacyItems = [];
        for (final dynamic rawRow in localList) {
          try {
            final Map<dynamic, dynamic> row = rawRow as Map<dynamic, dynamic>;
            final dynamic rawEnc = row['encrypted'];
            if (rawEnc == null) continue;
            final payload = EncryptedPayload.fromMap(rawEnc as Map<dynamic, dynamic>);
            final decryptedJson = await CryptoEngine.decrypt(
              payload: payload,
              key: _masterEncryptionKey,
            );
            final item = VaultItem.fromDecryptedJson(
              id: (row['id'] ?? '').toString(),
              jsonStr: decryptedJson,
              version: (row['version'] as num?)?.toInt() ?? 1,
              isFavorite: row['is_favorite'] == true,
              isDeleted: row['is_deleted'] == true,
              updatedAt: DateTime.tryParse((row['updated_at'] ?? '').toString()) ?? DateTime.now().toUtc(),
            );
            if (!item.isDeleted) {
              itemMap[item.id] = item;
              legacyItems.add(item);
            }
          } catch (_) {}
        }

        // Subir a Supabase en lote si la nube está conectada
        if (isCloudConfigured && userId != null && legacyItems.isNotEmpty) {
          final List<Map<String, dynamic>> upsertRows = [];
          for (final item in legacyItems) {
            final enc = await CryptoEngine.encrypt(
              plainText: item.toSensitiveJson(),
              key: _masterEncryptionKey,
            );
            upsertRows.add({
              'id': item.id,
              'user_id': userId,
              'payload_ciphertext': enc.ciphertextBase64,
              'nonce': enc.nonceBase64,
              'auth_tag': enc.authTagBase64,
              'is_favorite': item.isFavorite,
              'is_deleted': item.isDeleted,
              'version': item.version,
              'client_updated_at': item.updatedAt.toIso8601String(),
            });
          }
          await _supabase.from('vault_items').upsert(upsertRows);
          debugPrint('☁️ ${upsertRows.length} credenciales migradas exitosamente a Supabase Online.');
        }

        // PURGA TOTAL: Eliminar definitivamente el almacén local del navegador cuando la nube está activa
        if (isCloudConfigured) {
          await _secureStorage.removeLocalEncryptedVault(userEmail);
          debugPrint('🧹 Almacenamiento local eliminado. Todo reside 100% online en Supabase.');
        }
      }
    } catch (e) {
      debugPrint('Aviso en purga de almacenamiento local: $e');
    }

    // 3. CARGA DIRECTA Y EXCLUSIVA DESDE SUPABASE ONLINE (Zero-Knowledge)
    if (isCloudConfigured && userId != null) {
      try {
        final dynamic rawResponse = await _supabase
            .from('vault_items')
            .select('*')
            .eq('user_id', userId)
            .eq('is_deleted', false);

        final List<dynamic> response = (rawResponse is List) ? rawResponse : [];

        for (final row in response) {
          try {
            final encryptedPayload = EncryptedPayload(
              ciphertextBase64: row['payload_ciphertext'] as String,
              nonceBase64: row['nonce'] as String,
              authTagBase64: row['auth_tag'] as String,
            );

            final decryptedJson = await CryptoEngine.decrypt(
              payload: encryptedPayload,
              key: _masterEncryptionKey,
            );

            final item = VaultItem.fromDecryptedJson(
              id: (row['id'] ?? '').toString(),
              jsonStr: decryptedJson,
              version: (row['version'] as num?)?.toInt() ?? 1,
              isFavorite: row['is_favorite'] == true,
              isDeleted: row['is_deleted'] == true,
              updatedAt: DateTime.tryParse((row['client_updated_at'] ?? row['server_updated_at'] ?? '').toString()) ?? DateTime.now().toUtc(),
            );

            itemMap[item.id] = item;
          } catch (itemErr) {
            debugPrint('Aviso al descifrar elemento de la nube: $itemErr');
            continue;
          }
        }
        _updateSyncStatus(CloudSyncStatus.synced);
      } catch (e) {
        debugPrint('Aviso al consultar Supabase online: $e');
        _updateSyncStatus(CloudSyncStatus.error);
      }
    } else if (isCloudConfigured) {
      _updateSyncStatus(CloudSyncStatus.offline);
    }

    _cachedItems = itemMap.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    // Garantizar que no persista en local si la nube está activa
    await _persistLocalEncryptedVault();

    // Sincronizar categorías personalizadas
    final savedCats = await _secureStorage.getCustomCategories(userEmail);
    final catSet = Set<String>.from(savedCats);
    for (final item in _cachedItems) {
      if (item.category.trim().isNotEmpty &&
          item.category != 'all' &&
          item.category != 'favorites' &&
          item.category != 'login' &&
          item.category != 'device' &&
          item.category != 'note' &&
          item.category != 'bancos' &&
          item.category != 'tiendas' &&
          item.category != 'correo') {
        catSet.add(item.category.trim());
      }
    }
    _customCategories = catSet.toList()..sort();
    if (!_categoriesController.isClosed) {
      _categoriesController.add(_customCategories);
    }

    _vaultItemsController.add(_cachedItems);
    return _cachedItems;
  }

  /// Cifra un elemento con AES-256-GCM y lo persiste DIRECTAMENTE en la plataforma online de Supabase
  Future<void> saveItem(VaultItem item) async {
    // 1. Cifrado simétrico de extremo a extremo (Zero-Knowledge)
    final sensitiveJson = item.toSensitiveJson();
    final encrypted = await CryptoEngine.encrypt(
      plainText: sensitiveJson,
      key: _masterEncryptionKey,
    );

    // 2. Actualizar caché en memoria
    final index = _cachedItems.indexWhere((e) => e.id == item.id);
    if (index >= 0) {
      _cachedItems[index] = item;
    } else {
      _cachedItems.insert(0, item);
    }
    _vaultItemsController.add(_cachedItems);

    // 3. Persistir directamente en Supabase Online (100% en la nube)
    await _ensureSupabaseSession();
    final userId = _supabase.auth.currentUser?.id;
    if (isCloudConfigured && userId != null) {
      try {
        await _supabase.from('vault_items').upsert({
          'id': item.id,
          'user_id': userId,
          'payload_ciphertext': encrypted.ciphertextBase64,
          'nonce': encrypted.nonceBase64,
          'auth_tag': encrypted.authTagBase64,
          'is_favorite': item.isFavorite,
          'is_deleted': item.isDeleted,
          'version': item.version,
          'client_updated_at': item.updatedAt.toIso8601String(),
        });
        _updateSyncStatus(CloudSyncStatus.synced);
      } catch (e) {
        debugPrint('Error al guardar credencial en la plataforma online Supabase: $e');
        _updateSyncStatus(CloudSyncStatus.error);
        rethrow;
      }
    }

    // 4. Asegurar que no quede almacenamiento local en el navegador
    await _persistLocalEncryptedVault();
  }

  /// Guarda múltiples credenciales de forma masiva DIRECTAMENTE en Supabase (ej. importación TXT/Excel)
  Future<void> saveItemsBulk(List<VaultItem> items) async {
    if (items.isEmpty) return;

    // 1. Actualizar caché en memoria
    for (final item in items) {
      final index = _cachedItems.indexWhere((e) => e.id == item.id);
      if (index >= 0) {
        _cachedItems[index] = item;
      } else {
        _cachedItems.insert(0, item);
      }
    }
    _vaultItemsController.add(_cachedItems);

    // 2. Persistir directamente en Supabase Online en lote
    await _ensureSupabaseSession();
    final userId = _supabase.auth.currentUser?.id;
    if (isCloudConfigured && userId != null) {
      _updateSyncStatus(CloudSyncStatus.syncing);
      try {
        final List<Map<String, dynamic>> upsertRows = [];
        for (final item in items) {
          final enc = await CryptoEngine.encrypt(
            plainText: item.toSensitiveJson(),
            key: _masterEncryptionKey,
          );
          upsertRows.add({
            'id': item.id,
            'user_id': userId,
            'payload_ciphertext': enc.ciphertextBase64,
            'nonce': enc.nonceBase64,
            'auth_tag': enc.authTagBase64,
            'is_favorite': item.isFavorite,
            'is_deleted': item.isDeleted,
            'version': item.version,
            'client_updated_at': item.updatedAt.toIso8601String(),
          });
        }
        await _supabase.from('vault_items').upsert(upsertRows);
        _updateSyncStatus(CloudSyncStatus.synced);
        debugPrint('☁️ ${upsertRows.length} credenciales almacenadas exitosamente en Supabase Online.');
      } catch (e) {
        debugPrint('Error al guardar lote en Supabase: $e');
        _updateSyncStatus(CloudSyncStatus.error);
        rethrow;
      }
    }

    // 3. Garantizar que no persista ningún archivo local en el navegador
    await _persistLocalEncryptedVault();
  }

  /// Borrado lógico (soft-delete) directamente en Supabase Online
  Future<void> deleteItem(String id) async {
    final index = _cachedItems.indexWhere((e) => e.id == id);
    if (index >= 0) {
      _cachedItems.removeAt(index);
      _vaultItemsController.add(_cachedItems);

      await _ensureSupabaseSession();
      final userId = _supabase.auth.currentUser?.id;
      if (isCloudConfigured && userId != null) {
        try {
          await _supabase.from('vault_items').update({
            'is_deleted': true,
            'client_updated_at': DateTime.now().toUtc().toIso8601String(),
          }).eq('id', id).eq('user_id', userId);
          _updateSyncStatus(CloudSyncStatus.synced);
        } catch (e) {
          debugPrint('Error al eliminar ítem en Supabase Online: $e');
        }
      }

      await _persistLocalEncryptedVault();
    }
  }

  /// Garantiza que en producción todo resida 100% online en Supabase y NUNCA en local
  Future<void> _persistLocalEncryptedVault() async {
    if (isCloudConfigured) {
      // Purgar cualquier dato residual en local: Todo está almacenado 100% online en Supabase
      await _secureStorage.removeLocalEncryptedVault(userEmail);
      return;
    }
    // Entorno aislado para pruebas unitarias sin conexión
    try {
      final List<Map<String, dynamic>> serializedList = [];
      for (final item in _cachedItems) {
        final encrypted = await CryptoEngine.encrypt(
          plainText: item.toSensitiveJson(),
          key: _masterEncryptionKey,
        );
        serializedList.add({
          'id': item.id,
          'version': item.version,
          'is_favorite': item.isFavorite,
          'is_deleted': item.isDeleted,
          'updated_at': item.updatedAt.toIso8601String(),
          'encrypted': encrypted.toMap(),
        });
      }
      await _secureStorage.saveLocalEncryptedVault(userEmail, jsonEncode(serializedList));
    } catch (_) {}
  }

  /// Añade una nueva categoría personalizada
  Future<void> addCustomCategory(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    if (!_customCategories.any((c) => c.toLowerCase() == trimmed.toLowerCase())) {
      _customCategories.add(trimmed);
      _customCategories.sort();
      await _secureStorage.saveCustomCategories(userEmail, _customCategories);
      if (!_categoriesController.isClosed) {
        _categoriesController.add(_customCategories);
      }
    }
  }

  /// Elimina una categoría personalizada existente
  Future<void> deleteCustomCategory(String name) async {
    _customCategories.removeWhere((c) => c.toLowerCase() == name.toLowerCase().trim());
    await _secureStorage.saveCustomCategories(userEmail, _customCategories);
    if (!_categoriesController.isClosed) {
      _categoriesController.add(_customCategories);
    }
  }

  void dispose() {
    _realtimeSubscription?.unsubscribe();
    _syncStatusController.close();
    _vaultItemsController.close();
    _categoriesController.close();
  }
}
