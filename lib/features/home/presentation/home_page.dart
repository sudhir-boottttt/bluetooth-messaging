import 'dart:async';

import 'package:flutter/material.dart';

import '../../../services/ble/ble_mesh_transport.dart';

/// Nearby peer dashboard. Starting the mesh activates advertising and scanning.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final BleMeshTransport _transport = BleMeshTransport();
  final Map<String, MeshPeer> _peers = {};
  StreamSubscription<MeshPeer>? _peerSubscription;
  String? _error;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _peerSubscription = _transport.peers.listen(
      (peer) {
        if (mounted) setState(() => _peers[peer.id] = peer);
      },
      onError: (Object error) {
        if (mounted) setState(() => _error = error.toString());
      },
    );
  }

  Future<void> _start() async {
    try {
      await _transport.start();
      if (mounted) {
        setState(() {
          _running = true;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  @override
  void dispose() {
    unawaited(_peerSubscription?.cancel());
    unawaited(_transport.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('MeshChat')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            child: ListTile(
              leading: Icon(
                _running ? Icons.hub : Icons.hub_outlined,
                color: _running ? Theme.of(context).colorScheme.primary : null,
              ),
              title: Text(_running ? 'Mesh is active' : 'Mesh is offline'),
              subtitle: Text(
                _error ??
                    (_running
                        ? 'Advertising and scanning for nearby MeshChat devices.'
                        : 'Start nearby Bluetooth mesh discovery.'),
              ),
              trailing: FilledButton(
                onPressed: _running ? null : _start,
                child: Text(_running ? 'Active' : 'Start'),
              ),
            ),
          ),
        ),
        Expanded(
          child: _peers.isEmpty
              ? const Center(child: Text('No nearby MeshChat devices found.'))
              : ListView.builder(
                  itemCount: _peers.length,
                  itemBuilder: (_, index) {
                    final peer = _peers.values.elementAt(index);
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(
                        peer.name.isEmpty ? 'Mesh device' : peer.name,
                      ),
                      subtitle: Text(peer.id),
                      trailing: Text('${peer.rssi} dBm'),
                    );
                  },
                ),
        ),
      ],
    ),
  );
}
