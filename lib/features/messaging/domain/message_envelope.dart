import 'dart:convert';
import 'dart:typed_data';

/// Immutable signed transport envelope. Its payload remains opaque to relays.
class MessageEnvelope {
  const MessageEnvelope({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.timestamp,
    required this.ttl,
    required this.hopCount,
    required this.ciphertext,
    required this.nonce,
    required this.mac,
    required this.signature,
  });

  final String id;
  final String senderId;
  final String receiverId;
  final DateTime timestamp;
  final int ttl;
  final int hopCount;
  final Uint8List ciphertext;
  final Uint8List nonce;
  final Uint8List mac;
  final Uint8List signature;

  bool get canForward => ttl > 0;
  bool isFor(String deviceId) => receiverId == deviceId;

  MessageEnvelope forwarded() {
    if (!canForward) throw StateError('Cannot forward an expired envelope.');
    return MessageEnvelope(
      id: id,
      senderId: senderId,
      receiverId: receiverId,
      timestamp: timestamp,
      ttl: ttl - 1,
      hopCount: hopCount + 1,
      ciphertext: ciphertext,
      nonce: nonce,
      mac: mac,
      signature: signature,
    );
  }

  Map<String, Object> toJson() => {
    'id': id,
    'senderId': senderId,
    'receiverId': receiverId,
    'timestamp': timestamp.toUtc().toIso8601String(),
    'ttl': ttl,
    'hopCount': hopCount,
    'ciphertext': base64UrlEncode(ciphertext),
    'nonce': base64UrlEncode(nonce),
    'mac': base64UrlEncode(mac),
    'signature': base64UrlEncode(signature),
  };

  Uint8List toBytes() => Uint8List.fromList(utf8.encode(jsonEncode(toJson())));

  /// Decodes a previously signed wire envelope. Signature verification happens
  /// in the message service before plaintext is accepted.
  factory MessageEnvelope.fromBytes(List<int> bytes) {
    final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    Uint8List decode(String key) =>
        Uint8List.fromList(base64Url.decode(json[key] as String));
    return MessageEnvelope(
      id: json['id'] as String,
      senderId: json['senderId'] as String,
      receiverId: json['receiverId'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      ttl: json['ttl'] as int,
      hopCount: json['hopCount'] as int,
      ciphertext: decode('ciphertext'),
      nonce: decode('nonce'),
      mac: decode('mac'),
      signature: decode('signature'),
    );
  }
}
