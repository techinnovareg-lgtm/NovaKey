import 'dart:convert';
import 'package:uuid/uuid.dart';

/// Modelo de datos de un elemento de la Bóveda en texto plano (en memoria volátil del cliente)
class VaultItem {
  final String id;
  final String title;
  final String username;
  final String password;
  final String websiteUrl;
  final String notes;
  final String category; // 'login', 'note', 'card', 'server', 'device'
  final String imageBase64; // Foto de la credencial o etiqueta física del dispositivo (Módem, Cámara, etc.)
  final bool isFavorite;
  final bool isDeleted;
  final int version;
  final DateTime updatedAt;

  VaultItem({
    String? id,
    required this.title,
    required this.username,
    required this.password,
    this.websiteUrl = '',
    this.notes = '',
    this.category = 'login',
    this.imageBase64 = '',
    this.isFavorite = false,
    this.isDeleted = false,
    this.version = 1,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        updatedAt = updatedAt ?? DateTime.now().toUtc();

  /// Serializa los campos sensibles a JSON para su posterior cifrado simétrico
  String toSensitiveJson() {
    return jsonEncode({
      'title': title,
      'username': username,
      'password': password,
      'websiteUrl': websiteUrl,
      'notes': notes,
      'category': category,
      'imageBase64': imageBase64,
    });
  }

  /// Deserializa desde JSON descifrado
  factory VaultItem.fromDecryptedJson({
    required String id,
    required String jsonStr,
    required int version,
    required bool isFavorite,
    required bool isDeleted,
    required DateTime updatedAt,
  }) {
    final Map<String, dynamic> data = jsonDecode(jsonStr);
    return VaultItem(
      id: id,
      title: data['title'] ?? '',
      username: data['username'] ?? '',
      password: data['password'] ?? '',
      websiteUrl: data['websiteUrl'] ?? '',
      notes: data['notes'] ?? '',
      category: data['category'] ?? 'login',
      imageBase64: (data['imageBase64'] ?? '').toString(),
      version: version,
      isFavorite: isFavorite,
      isDeleted: isDeleted,
      updatedAt: updatedAt,
    );
  }

  VaultItem copyWith({
    String? title,
    String? username,
    String? password,
    String? websiteUrl,
    String? notes,
    String? category,
    String? imageBase64,
    bool? isFavorite,
    bool? isDeleted,
    int? version,
  }) {
    return VaultItem(
      id: id,
      title: title ?? this.title,
      username: username ?? this.username,
      password: password ?? this.password,
      websiteUrl: websiteUrl ?? this.websiteUrl,
      notes: notes ?? this.notes,
      category: category ?? this.category,
      imageBase64: imageBase64 ?? this.imageBase64,
      isFavorite: isFavorite ?? this.isFavorite,
      isDeleted: isDeleted ?? this.isDeleted,
      version: version ?? this.version,
      updatedAt: DateTime.now().toUtc(),
    );
  }
}
