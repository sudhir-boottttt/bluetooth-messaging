import 'identity.dart';

/// Persistence boundary for the device's self-sovereign identity.
abstract interface class IdentityRepository {
  Future<Identity> getOrCreate();
  Future<bool> exists();
  Future<IdentityKeyMaterial> loadKeyMaterial();
}
