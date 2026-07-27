import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:uuid/uuid.dart';

import '../../../services/crypto/crypto_service.dart';
import '../../identity/domain/identity.dart';
import 'message_envelope.dart';

/// Creates and opens signed end-to-end encrypted direct-message envelopes.
class EncryptedMessageService {
  EncryptedMessageService(this._crypto);
  final CryptoService _crypto;
  static const _uuid = Uuid();

  Future<MessageEnvelope> encrypt({
    required String receiverId,
    required SimplePublicKey receiverExchangeKey,
    required IdentityKeyMaterial sender,
    required List<int> plaintext,
    int ttl = 8,
  }) async {
    final id = _uuid.v4();
    final timestamp = DateTime.now().toUtc();
    final aad = Uint8List.fromList(
      '$id|${sender.identity.deviceId}|$receiverId|${timestamp.toIso8601String()}'
          .codeUnits,
    );
    final secret = await _crypto.deriveSharedSecret(
      localKeyPair: sender.exchangeKeyPair,
      remotePublicKey: receiverExchangeKey,
    );
    final box = await _crypto.encrypt(
      plaintext: plaintext,
      secretKey: secret,
      associatedData: aad,
    );
    final signed = Uint8List.fromList([
      ...aad,
      ...box.cipherText,
      ...box.nonce,
      ...box.mac.bytes,
    ]);
    final signature = await _crypto.sign(signed, sender.signingKeyPair);
    return MessageEnvelope(
      id: id,
      senderId: sender.identity.deviceId,
      receiverId: receiverId,
      timestamp: timestamp,
      ttl: ttl,
      hopCount: 0,
      ciphertext: Uint8List.fromList(box.cipherText),
      nonce: Uint8List.fromList(box.nonce),
      mac: Uint8List.fromList(box.mac.bytes),
      signature: Uint8List.fromList(signature.bytes),
    );
  }

  Future<List<int>> decryptFromContact({
    required MessageEnvelope envelope,
    required SimplePublicKey senderSigningKey,
    required SimplePublicKey senderExchangeKey,
    required IdentityKeyMaterial receiver,
  }) async {
    final aad = Uint8List.fromList(
      '${envelope.id}|${envelope.senderId}|${envelope.receiverId}|${envelope.timestamp.toUtc().toIso8601String()}'
          .codeUnits,
    );
    final valid = await _crypto.verify(
      Uint8List.fromList([
        ...aad,
        ...envelope.ciphertext,
        ...envelope.nonce,
        ...envelope.mac,
      ]),
      Signature(envelope.signature, publicKey: senderSigningKey),
    );
    if (!valid) throw StateError('Message signature verification failed.');
    final secret = await _crypto.deriveSharedSecret(
      localKeyPair: receiver.exchangeKeyPair,
      remotePublicKey: senderExchangeKey,
    );
    return _crypto.decrypt(
      box: SecretBox(
        envelope.ciphertext,
        nonce: envelope.nonce,
        mac: Mac(envelope.mac),
      ),
      secretKey: secret,
      associatedData: aad,
    );
  }
}
