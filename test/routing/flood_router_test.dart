import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meshchat/features/messaging/domain/message_envelope.dart';
import 'package:meshchat/routing/flood_router.dart';

MessageEnvelope envelope({
  String id = 'message-1',
  String receiverId = 'peer',
  int ttl = 3,
}) => MessageEnvelope(
  id: id,
  senderId: 'sender',
  receiverId: receiverId,
  timestamp: DateTime.utc(2026),
  ttl: ttl,
  hopCount: 0,
  ciphertext: Uint8List(0),
  nonce: Uint8List(0),
  mac: Uint8List(0),
  signature: Uint8List(0),
);

void main() {
  group('FloodRouter', () {
    test('forwards an unseen packet and suppresses its duplicate', () {
      final router = FloodRouter(localDeviceId: 'local');
      final packet = envelope();
      expect(router.route(packet), RouteAction.forward);
      expect(router.route(packet), RouteAction.dropDuplicate);
    });

    test('delivers locally addressed packets before forwarding', () {
      expect(
        FloodRouter(
          localDeviceId: 'local',
        ).route(envelope(receiverId: 'local')),
        RouteAction.deliver,
      );
    });

    test('does not forward a packet with exhausted TTL', () {
      expect(
        FloodRouter(localDeviceId: 'local').route(envelope(ttl: 0)),
        RouteAction.dropExpired,
      );
    });
  });
}
