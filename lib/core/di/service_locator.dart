import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';

import '../../database/app_database.dart';
import '../../features/identity/data/secure_identity_repository.dart';
import '../../features/identity/domain/identity_repository.dart';
import '../../features/messaging/domain/encrypted_message_service.dart';
import '../../services/crypto/crypto_service.dart';

/// Application-wide dependency container. Feature composition happens here.
final GetIt getIt = GetIt.instance;

Future<void> configureDependencies() async {
  if (getIt.isRegistered<IdentityRepository>()) return;

  getIt
    ..registerLazySingleton<Logger>(Logger.new)
    ..registerLazySingleton<FlutterSecureStorage>(FlutterSecureStorage.new)
    ..registerLazySingleton<CryptoService>(CryptoService.new)
    ..registerLazySingleton<EncryptedMessageService>(
      () => EncryptedMessageService(getIt<CryptoService>()),
    )
    ..registerLazySingleton<AppDatabase>(AppDatabase.new)
    ..registerLazySingleton<IdentityRepository>(
      () => SecureIdentityRepository(
        storage: getIt<FlutterSecureStorage>(),
        crypto: getIt<CryptoService>(),
      ),
    );
}
