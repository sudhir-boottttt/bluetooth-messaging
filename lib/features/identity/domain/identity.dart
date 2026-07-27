import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Locally owned, cryptographic identity. Secret material never leaves storage.
class Identity {
  const Identity({
    required this.deviceId,
    required this.signingPublicKey,
    required this.encryptionPublicKey,
  });

  final String deviceId;
  final Uint8List signingPublicKey;
  final Uint8List encryptionPublicKey;
}

/// Private keys loaded only from encrypted storage for a cryptographic action.
class IdentityKeyMaterial {
  const IdentityKeyMaterial({
    required this.identity,
    required this.signingKeyPair,
    required this.exchangeKeyPair,
  });
  final Identity identity;
  final SimpleKeyPair signingKeyPair;
  final SimpleKeyPair exchangeKeyPair;
}
