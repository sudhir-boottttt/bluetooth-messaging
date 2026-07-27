import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:uuid/uuid.dart';

/// Cryptographic primitives used by identity and message services.
///
/// AEAD encryption is deliberately separated from transport: relays only pass
/// opaque ciphertext and signed metadata.
class CryptoService {
  CryptoService()
    : _x25519 = X25519(),
      _ed25519 = Ed25519(),
      _aesGcm = AesGcm.with256bits();

  final X25519 _x25519;
  final Ed25519 _ed25519;
  final AesGcm _aesGcm;
  static const Uuid _uuid = Uuid();

  String newDeviceId() => _uuid.v4();

  Future<SimpleKeyPair> generateExchangeKeyPair() => _x25519.newKeyPair();
  Future<SimpleKeyPair> generateSigningKeyPair() => _ed25519.newKeyPair();

  Future<SecretKey> deriveSharedSecret({
    required SimpleKeyPair localKeyPair,
    required SimplePublicKey remotePublicKey,
  }) => _x25519.sharedSecretKey(
    keyPair: localKeyPair,
    remotePublicKey: remotePublicKey,
  );

  Future<SecretBox> encrypt({
    required List<int> plaintext,
    required SecretKey secretKey,
    required List<int> associatedData,
  }) => _aesGcm.encrypt(plaintext, secretKey: secretKey, aad: associatedData);

  Future<List<int>> decrypt({
    required SecretBox box,
    required SecretKey secretKey,
    required List<int> associatedData,
  }) => _aesGcm.decrypt(box, secretKey: secretKey, aad: associatedData);

  Future<Signature> sign(List<int> data, SimpleKeyPair keyPair) =>
      _ed25519.sign(data, keyPair: keyPair);

  Future<bool> verify(List<int> data, Signature signature) =>
      _ed25519.verify(data, signature: signature);

  Uint8List bytes(List<int> value) => Uint8List.fromList(value);
}
