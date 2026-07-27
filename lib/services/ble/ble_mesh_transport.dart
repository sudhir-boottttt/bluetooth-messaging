import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:uuid/uuid.dart' as uuid;

import '../../features/messaging/domain/message_envelope.dart';

/// Symmetric BLE mesh transport: Android advertises a GATT write endpoint and
/// this service scans, connects, and writes framed packets to nearby peers.
class BleMeshTransport {
  BleMeshTransport({FlutterReactiveBle? ble})
    : _ble = ble ?? FlutterReactiveBle();

  static final Uuid serviceId = Uuid.parse(
    '9d4f91f1-8b61-4d9e-b8b6-4c9c9f1a0001',
  );
  static final Uuid characteristicId = Uuid.parse(
    '9d4f91f1-8b61-4d9e-b8b6-4c9c9f1a0002',
  );
  static const _permissions = MethodChannel('meshchat/permissions');
  static const _gatt = MethodChannel('meshchat/gatt');
  static const _inbound = EventChannel('meshchat/gatt/inbound');
  final FlutterReactiveBle _ble;
  final _peers = StreamController<MeshPeer>.broadcast();
  final _messages = StreamController<ReceivedMeshMessage>.broadcast();
  final _reassembler = _PacketReassembler();
  StreamSubscription<DiscoveredDevice>? _scan;
  StreamSubscription<dynamic>? _inboundSubscription;

  Stream<MeshPeer> get peers => _peers.stream;
  Stream<ReceivedMeshMessage> get messages => _messages.stream;

  /// Requests Android nearby-device access and starts both BLE roles.
  Future<void> start() async {
    final granted =
        await _permissions.invokeMethod<bool>('requestBlePermissions') ?? false;
    if (!granted) throw StateError('Nearby Devices permission was denied.');
    await _gatt.invokeMethod<void>('start');
    _inboundSubscription ??= _inbound
        .receiveBroadcastStream()
        .cast<Map<dynamic, dynamic>>()
        .listen(_onInbound);
    _scan ??= _ble
        .scanForDevices(
          withServices: [serviceId],
          scanMode: ScanMode.lowLatency,
        )
        .listen(
          (device) => _peers.add(
            MeshPeer(id: device.id, name: device.name, rssi: device.rssi),
          ),
          onError: _peers.addError,
        );
  }

  /// Writes an encrypted envelope to one direct neighbor using MTU-safe frames.
  Future<void> sendToPeer(String peerId, MessageEnvelope envelope) async {
    final update = await _ble
        .connectToDevice(
          id: peerId,
          connectionTimeout: const Duration(seconds: 12),
        )
        .firstWhere(
          (update) => update.connectionState == DeviceConnectionState.connected,
        );
    if (update.connectionState != DeviceConnectionState.connected) {
      throw StateError('Unable to connect to $peerId.');
    }
    final characteristic = QualifiedCharacteristic(
      deviceId: peerId,
      serviceId: serviceId,
      characteristicId: characteristicId,
    );
    for (final frame in _PacketFramer.frame(envelope.toBytes())) {
      await _ble.writeCharacteristicWithoutResponse(
        characteristic,
        value: frame,
      );
    }
  }

  void _onInbound(Map<dynamic, dynamic> event) {
    final payload = base64Decode(event['payload'] as String);
    final complete = _reassembler.add(payload);
    if (complete != null) {
      _messages.add(
        ReceivedMeshMessage(
          peerId: event['peerId'] as String,
          envelope: MessageEnvelope.fromBytes(complete),
        ),
      );
    }
  }

  Future<void> dispose() async {
    await _scan?.cancel();
    await _inboundSubscription?.cancel();
    await _gatt.invokeMethod<void>('stop');
    await _peers.close();
    await _messages.close();
  }
}

class MeshPeer {
  const MeshPeer({required this.id, required this.name, required this.rssi});
  final String id;
  final String name;
  final int rssi;
}

class ReceivedMeshMessage {
  const ReceivedMeshMessage({required this.peerId, required this.envelope});
  final String peerId;
  final MessageEnvelope envelope;
}

class _PacketFramer {
  static const _payloadBytes = 130;
  static const _uuid = uuid.Uuid();
  static List<Uint8List> frame(Uint8List data) {
    final id = _uuid.v4();
    final count = (data.length / _payloadBytes).ceil();
    return List<Uint8List>.generate(count, (index) {
      final start = index * _payloadBytes;
      final end = (start + _payloadBytes).clamp(0, data.length);
      return Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'id': id,
            'index': index,
            'count': count,
            'data': base64UrlEncode(data.sublist(start, end)),
          }),
        ),
      );
    });
  }
}

class _PacketReassembler {
  final Map<String, _PartialPacket> _pending = {};
  Uint8List? add(Uint8List frame) {
    final json = jsonDecode(utf8.decode(frame)) as Map<String, dynamic>;
    final id = json['id'] as String;
    final partial = _pending.putIfAbsent(
      id,
      () => _PartialPacket(json['count'] as int),
    );
    partial.fragments[json['index'] as int] = base64Url.decode(
      json['data'] as String,
    );
    if (partial.fragments.length != partial.count) return null;
    _pending.remove(id);
    return Uint8List.fromList([
      for (var i = 0; i < partial.count; i++) ...partial.fragments[i]!,
    ]);
  }
}

class _PartialPacket {
  _PartialPacket(this.count);
  final int count;
  final Map<int, List<int>> fragments = {};
}
