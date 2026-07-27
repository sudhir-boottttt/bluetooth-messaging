import '../features/messaging/domain/message_envelope.dart';

/// Decision made by the flooding router for one inbound mesh packet.
enum RouteAction { dropDuplicate, dropExpired, deliver, forward }

/// Duplicate-suppressing flooding policy. Replace this class to introduce AODV,
/// BATMAN, or gossip routing without changing the messaging layer.
class FloodRouter {
  FloodRouter({required this.localDeviceId, this.maxSeenIds = 10000});

  final String localDeviceId;
  final int maxSeenIds;
  final Set<String> _seen = <String>{};
  final List<String> _seenOrder = <String>[];

  RouteAction route(MessageEnvelope envelope) {
    if (_seen.contains(envelope.id)) return RouteAction.dropDuplicate;
    _remember(envelope.id);
    if (envelope.isFor(localDeviceId)) return RouteAction.deliver;
    return envelope.canForward ? RouteAction.forward : RouteAction.dropExpired;
  }

  void _remember(String id) {
    _seen.add(id);
    _seenOrder.add(id);
    if (_seenOrder.length > maxSeenIds) _seen.remove(_seenOrder.removeAt(0));
  }
}
