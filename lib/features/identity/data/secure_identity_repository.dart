import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../services/crypto/crypto_service.dart';
import '../domain/identity.dart';
import '../domain/identity_repository.dart';

/// Stores identity material in platform encrypted storage, never SQLite.
class SecureIdentityRepository implements IdentityRepository {
  SecureIdentityRepository({required this.storage, required this.crypto});

  static const _deviceId = 'identity.device_id';
  static const _signingPublic = 'identity.signing_public';
  static const _signingPrivate = 'identity.signing_private';
  static const _exchangePublic = 'identity.exchange_public';
  static const _exchangePrivate = 'identity.exchange_private';
  final FlutterSecureStorage storage;
  final CryptoService crypto;

  @override
  Future<bool> exists() async => (await storage.read(key: _deviceId)) != null;

  @override
  Future<Identity> getOrCreate() async {
    final deviceId = await storage.read(key: _deviceId);
    if (deviceId != null) return _read(deviceId);

    final signing = await crypto.generateSigningKeyPair();
    final exchange = await crypto.generateExchangeKeyPair();
    final signingPublic = await signing.extractPublicKey();
    final exchangePublic = await exchange.extractPublicKey();
    final newId = crypto.newDeviceId();
    await storage.write(key: _deviceId, value: newId);
    await storage.write(
      key: _signingPublic,
      value: base64UrlEncode(signingPublic.bytes),
    );
    await storage.write(
      key: _signingPrivate,
      value: base64UrlEncode(await signing.extractPrivateKeyBytes()),
    );
    await storage.write(
      key: _exchangePublic,
      value: base64UrlEncode(exchangePublic.bytes),
    );
    await storage.write(
      key: _exchangePrivate,
      value: base64UrlEncode(await exchange.extractPrivateKeyBytes()),
    );
    return Identity(
      deviceId: newId,
      signingPublicKey: Uint8List.fromList(signingPublic.bytes),
      encryptionPublicKey: Uint8List.fromList(exchangePublic.bytes),
    );
  }

  @override
  Future<IdentityKeyMaterial> loadKeyMaterial() async {
    final identity = await getOrCreate();
    final signingPrivate = base64Url.decode(await _required(_signingPrivate));
    final exchangePrivate = base64Url.decode(await _required(_exchangePrivate));
    return IdentityKeyMaterial(
      identity: identity,
      signingKeyPair: SimpleKeyPairData(
        signingPrivate,
        publicKey: SimplePublicKey(
          identity.signingPublicKey,
          type: KeyPairType.ed25519,
        ),
        type: KeyPairType.ed25519,
      ),
      exchangeKeyPair: SimpleKeyPairData(
        exchangePrivate,
        publicKey: SimplePublicKey(
          identity.encryptionPublicKey,
          type: KeyPairType.x25519,
        ),
        type: KeyPairType.x25519,
      ),
    );
  }

  Future<Identity> _read(String deviceId) async {
    final signing = await _required(_signingPublic);
    final exchange = await _required(_exchangePublic);
    return Identity(
      deviceId: deviceId,
      signingPublicKey: Uint8List.fromList(base64Url.decode(signing)),
      encryptionPublicKey: Uint8List.fromList(base64Url.decode(exchange)),
    );
  }

  Future<String> _required(String key) async {
    final value = await storage.read(key: key);
    if (value == null) {
      throw StateError('Secure identity storage is incomplete for $key.');
    }
    return value;
  }
}
