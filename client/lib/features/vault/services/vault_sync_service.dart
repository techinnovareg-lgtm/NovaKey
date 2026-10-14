import 'dart:async';
import 'package:cryptography/cryptography.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/crypto/crypto_engine.dart';
import '../models/vault_item.dart';

/// Servicio de Sincronización en Tiempo Real de la Bóveda con arquitectura Zero-Knowledge
class VaultSyncService {
  final SupabaseClient _supabase;
  final SecretKey _masterEncryptionKey;
  RealtimeChannel? _realtimeSubscription;

  final _vaultItemsController = StreamController<List<VaultItem>>.broadcast();
  Stream<List<VaultItem>> get vaultItemsStream => _vaultItemsController.stream;

  List<VaultItem> _cachedItems = [];
  List<VaultItem> get currentItems => List.unmodifiable(_cachedItems);

  VaultSyncService({
    required SupabaseClient supabase,
    required SecretKey masterEncryptionKey,
  })  : _supabase = supabase,
        _masterEncryptionKey = masterEncryptionKey;

  /// Inicializa la escucha de cambios en tiempo real vía WebSockets de Supabase
  void initializeRealtimeSync() {
    _realtimeSubscription = _supabase
        .channel('public:vault_items')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'vault_items',
          callback: (payload) {
            // Al recibir un cambio de otro dispositivo, recargar y descifrar la lista
            fetchAndDecryptAll();
          },
        )
        .subscribe();
  }

  /// Descarga los registros cifrados desde Supabase y los descifra en memoria
  Future<List<VaultItem>> fetchAndDecryptAll() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _supabase
        .from('vault_items')
        .select('*')
        .eq('user_id', userId)
        .eq('is_deleted', false)
        .order('server_updated_at', ascending: false);

    final List<VaultItem> items = [];

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

        items.add(item);
      } catch (e) {
        // En caso de corrupción o clave inválida en un registro, omitir
        continue;
      }
    }

    _cachedItems = items;
    _vaultItemsController.add(_cachedItems);
    return _cachedItems;
  }

  /// Cifra un elemento con AES-256-GCM y lo sube a Supabase
  Future<void> saveItem(VaultItem item) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Usuario no autenticado');

    // 1. Cifrar el contenido sensible localmente
    final sensitiveJson = item.toSensitiveJson();
    final encrypted = await CryptoEngine.encrypt(
      plainText: sensitiveJson,
      key: _masterEncryptionKey,
    );

    // Cifrar el título para indexación local básica
    final encryptedTitle = await CryptoEngine.encrypt(
      plainText: item.title,
      key: _masterEncryptionKey,
    );

    // 2. Persistir en Supabase
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

    // 3. Actualizar caché local
    final index = _cachedItems.indexWhere((e) => e.id == item.id);
    if (index >= 0) {
      _cachedItems[index] = item;
    } else {
      _cachedItems.insert(0, item);
    }
    _vaultItemsController.add(_cachedItems);
  }

  /// Borrado lógico (soft-delete) para sincronizar eliminación en todos los dispositivos
  Future<void> deleteItem(String id) async {
    final index = _cachedItems.indexWhere((e) => e.id == id);
    if (index >= 0) {
      final updated = _cachedItems[index].copyWith(isDeleted: true);
      await saveItem(updated);
      _cachedItems.removeAt(index);
      _vaultItemsController.add(_cachedItems);
    }
  }

  void dispose() {
    _realtimeSubscription?.unsubscribe();
    _vaultItemsController.close();
  }
}
