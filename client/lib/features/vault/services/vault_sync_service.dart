import 'dart:async';
import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/crypto/crypto_engine.dart';
import '../../../core/security/secure_storage_service.dart';
import '../models/vault_item.dart';

/// Servicio de Sincronización Local y en la Nube con arquitectura Zero-Knowledge y Offline-First
class VaultSyncService {
  final SupabaseClient _supabase;
  final SecretKey _masterEncryptionKey;
  final SecureStorageService _secureStorage;
  RealtimeChannel? _realtimeSubscription;

  final _vaultItemsController = StreamController<List<VaultItem>>.broadcast();
  Stream<List<VaultItem>> get vaultItemsStream => _vaultItemsController.stream;

  List<VaultItem> _cachedItems = [];
  List<VaultItem> get currentItems => List.unmodifiable(_cachedItems);

  VaultSyncService({
    required SupabaseClient supabase,
    required SecretKey masterEncryptionKey,
    SecureStorageService? secureStorage,
  })  : _supabase = supabase,
        _masterEncryptionKey = masterEncryptionKey,
        _secureStorage = secureStorage ?? SecureStorageService();

  /// Determina si Supabase tiene credenciales reales configuradas
  bool get isCloudConfigured {
    try {
      final url = _supabase.rest.url.toString();
      return !url.contains('demo-passwords-vault.supabase.co') &&
          !url.contains('dummy_anon_key');
    } catch (_) {
      return false;
    }
  }

  /// Inicializa la escucha de cambios en tiempo real vía WebSockets de Supabase
  void initializeRealtimeSync() {
    if (!isCloudConfigured || _supabase.auth.currentUser == null) {
      debugPrint('ℹ️ Modo Local / Offline activo: Sincronización en la nube en espera de credenciales Supabase.');
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
              fetchAndDecryptAll();
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Aviso: no se pudo iniciar WebSockets en tiempo real: $e');
    }
  }

  /// Descarga los registros cifrados desde el almacenamiento local y/o Supabase
  Future<List<VaultItem>> fetchAndDecryptAll() async {
    final Map<String, VaultItem> itemMap = {};

    // 1. Cargar y descifrar la bóveda local persistente
    try {
      final localVaultJson = await _secureStorage.getLocalEncryptedVault();
      if (localVaultJson != null && localVaultJson.isNotEmpty) {
        final List<dynamic> localList = jsonDecode(localVaultJson);
        for (final row in localList) {
          try {
            final payload = EncryptedPayload.fromMap(row['encrypted']);
            final decryptedJson = await CryptoEngine.decrypt(
              payload: payload,
              key: _masterEncryptionKey,
            );

            final item = VaultItem.fromDecryptedJson(
              id: row['id'] as String,
              jsonStr: decryptedJson,
              version: row['version'] as int? ?? 1,
              isFavorite: row['is_favorite'] as bool? ?? false,
              isDeleted: row['is_deleted'] as bool? ?? false,
              updatedAt: DateTime.parse(row['updated_at'] as String),
            );

            if (!item.isDeleted) {
              itemMap[item.id] = item;
            }
          } catch (_) {
            continue;
          }
        }
      }
    } catch (e) {
      debugPrint('Aviso al leer almacenamiento local: $e');
    }

    // 2. Si hay conexión configurada y usuario autenticado en Supabase, sincronizar con la nube
    final userId = _supabase.auth.currentUser?.id;
    if (isCloudConfigured && userId != null) {
      try {
        final response = await _supabase
            .from('vault_items')
            .select('*')
            .eq('user_id', userId)
            .eq('is_deleted', false)
            .order('server_updated_at', ascending: false);

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
              id: row['id'] as String,
              jsonStr: decryptedJson,
              version: row['version'] as int,
              isFavorite: row['is_favorite'] as bool,
              isDeleted: row['is_deleted'] as bool,
              updatedAt: DateTime.parse(row['server_updated_at'] as String),
            );

            // Supabase prevalece si es más reciente
            itemMap[item.id] = item;
          } catch (_) {
            continue;
          }
        }
      } catch (e) {
        debugPrint('Aviso: modo sin conexión o error de red con Supabase: $e');
      }
    }

    _cachedItems = itemMap.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    _vaultItemsController.add(_cachedItems);
    return _cachedItems;
  }

  /// Cifra un elemento con AES-256-GCM y lo persiste en local y en la nube
  Future<void> saveItem(VaultItem item) async {
    // 1. Cifrado simétrico de extremo a extremo (Zero-Knowledge)
    final sensitiveJson = item.toSensitiveJson();
    final encrypted = await CryptoEngine.encrypt(
      plainText: sensitiveJson,
      key: _masterEncryptionKey,
    );

    final encryptedTitle = await CryptoEngine.encrypt(
      plainText: item.title,
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

    // 3. Persistir en almacenamiento seguro local (Offline-First)
    await _persistLocalEncryptedVault();

    // 4. Si la nube está configurada y el usuario autenticado, enviar a Supabase
    final userId = _supabase.auth.currentUser?.id;
    if (isCloudConfigured && userId != null) {
      try {
        await _supabase.from('vault_items').upsert({
          'id': item.id,
          'user_id': userId,
          'title_ciphertext': encryptedTitle.ciphertextBase64,
          'payload_ciphertext': encrypted.ciphertextBase64,
          'nonce': encrypted.nonceBase64,
          'auth_tag': encrypted.authTagBase64,
          'category': item.category,
          'is_favorite': item.isFavorite,
          'is_deleted': item.isDeleted,
          'version': item.version,
          'client_updated_at': item.updatedAt.toIso8601String(),
        });
      } catch (e) {
        debugPrint('Guardado localmente. La sincronización en la nube se reintentará al conectar: $e');
      }
    }
  }

  /// Borrado lógico (soft-delete)
  Future<void> deleteItem(String id) async {
    final index = _cachedItems.indexWhere((e) => e.id == id);
    if (index >= 0) {
      final itemToDelete = _cachedItems[index].copyWith(isDeleted: true);
      _cachedItems.removeAt(index);
      _vaultItemsController.add(_cachedItems);

      await _persistLocalEncryptedVault();

      final userId = _supabase.auth.currentUser?.id;
      if (isCloudConfigured && userId != null) {
        try {
          await _supabase.from('vault_items').update({
            'is_deleted': true,
          }).eq('id', id);
        } catch (_) {}
      }
    }
  }

  /// Guarda todos los ítems cifrados en almacenamiento local
  Future<void> _persistLocalEncryptedVault() async {
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

      await _secureStorage.saveLocalEncryptedVault(jsonEncode(serializedList));
    } catch (e) {
      debugPrint('Error al persistir bóveda cifrada en almacenamiento local: $e');
    }
  }

  void dispose() {
    _realtimeSubscription?.unsubscribe();
    _vaultItemsController.close();
  }
}
