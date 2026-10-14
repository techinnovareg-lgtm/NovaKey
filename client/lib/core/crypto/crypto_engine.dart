import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

/// Resultado del cifrado autenticado AES-256-GCM
class EncryptedPayload {
  final String ciphertextBase64;
  final String nonceBase64;
  final String authTagBase64;

  EncryptedPayload({
    required this.ciphertextBase64,
    required this.nonceBase64,
    required this.authTagBase64,
  });

  Map<String, dynamic> toMap() => {
        'ciphertext': ciphertextBase64,
        'nonce': nonceBase64,
        'auth_tag': authTagBase64,
      };

  factory EncryptedPayload.fromMap(Map<String, dynamic> map) => EncryptedPayload(
        ciphertextBase64: map['ciphertext'] as String,
        nonceBase64: map['nonce'] as String,
        authTagBase64: map['auth_tag'] as String,
      );
}

/// Par de claves derivadas de la contraseña maestra
class DerivedKeys {
  /// Clave utilizada exclusivamente para cifrar/descifrar la bóveda en local (AES-256-GCM)
  final SecretKey masterEncryptionKey;

  /// Hash criptográfico enviado al backend para autenticación (Nunca se envía la clave maestra)
  final String authHashHex;

  DerivedKeys({
    required this.masterEncryptionKey,
    required this.authHashHex,
  });
}

/// Motor Criptográfico Central con arquitectura Zero-Knowledge
class CryptoEngine {
  static final AesGcm _aesGcm = AesGcm.with256bits();
  static final Sha256 _sha256 = Sha256();

  /// Genera una sal criptográfica segura de 32 bytes (CSPRNG)
  static Uint8List generateRandomSalt([int length = 32]) {
    final secretKey = SecretKeyData.random(length: length);
    return Uint8List.fromList(secretKey.bytes);
  }

  /// Deriva la Master Key usando Argon2id o PBKDF2-HMAC-SHA256 con bifurcación HKDF
  ///
  /// Parámetros por defecto calibrados para alto costo contra ataques GPU/ASIC:
  /// - memory: 64 MB (65536 KB)
  /// - iterations: 3
  /// - parallelism: 4
  static Future<DerivedKeys> deriveKeys({
    required String masterPassword,
    required Uint8List salt,
    int memory = 65536,
    int iterations = 3,
    int parallelism = 4,
  }) async {
    // 1. Derivación de la clave maestra raíz usando Argon2id
    final argon2 = Argon2id(
      memory: memory,
      iterations: iterations,
      parallelism: parallelism,
      hashLength: 32,
    );

    final rootKeyData = await argon2.deriveKey(
      secretKey: SecretKey(utf8.encode(masterPassword)),
      nonce: salt,
    );

    // 2. Bifurcación de claves mediante HKDF (RFC 5869)
    // Clave A: Master Encryption Key (MEK) para AES-256-GCM
    final hkdfMek = Hkdf(
      hmac: Hmac.sha256(),
      outputLength: 32,
    );
    final mekKey = await hkdfMek.deriveKey(
      secretKey: rootKeyData,
      info: utf8.encode('vault-data-encryption-v1'),
    );

    // Clave B: Auth Hash para autenticación con el servidor
    final hkdfAuth = Hkdf(
      hmac: Hmac.sha256(),
      outputLength: 32,
    );
    final authKey = await hkdfAuth.deriveKey(
      secretKey: rootKeyData,
      info: utf8.encode('vault-auth-signature-v1'),
    );

    final authKeyBytes = await authKey.extractBytes();
    final authHash = await _sha256.hash(authKeyBytes);
    final authHashHex = authHash.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    return DerivedKeys(
      masterEncryptionKey: mekKey,
      authHashHex: authHashHex,
    );
  }

  /// Cifra un payload de texto plano usando AES-256-GCM con Nonce de 96 bits
  static Future<EncryptedPayload> encrypt({
    required String plainText,
    required SecretKey key,
  }) async {
    final clearBytes = utf8.encode(plainText);
    final secretBox = await _aesGcm.encrypt(
      clearBytes,
      secretKey: key,
    );

    return EncryptedPayload(
      ciphertextBase64: base64Encode(secretBox.cipherText),
      nonceBase64: base64Encode(secretBox.nonce),
      authTagBase64: base64Encode(secretBox.mac.bytes),
    );
  }

  /// Descifra un payload cifrado con verificación de integridad de Mac/Tag
  static Future<String> decrypt({
    required EncryptedPayload payload,
    required SecretKey key,
  }) async {
    final cipherBytes = base64Decode(payload.ciphertextBase64);
    final nonce = base64Decode(payload.nonceBase64);
    final macBytes = base64Decode(payload.authTagBase64);

    final secretBox = SecretBox(
      cipherBytes,
      nonce: nonce,
      mac: Mac(macBytes),
    );

    final clearBytes = await _aesGcm.decrypt(
      secretBox,
      secretKey: key,
    );

    return utf8.decode(clearBytes);
  }

  /// Limpia arrays sensibles de memoria sobrescribiéndolos con ceros
  static void zeroize(Uint8List buffer) {
    for (int i = 0; i < buffer.length; i++) {
      buffer[i] = 0;
    }
  }
}
