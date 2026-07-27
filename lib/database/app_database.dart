import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

/// Known mesh contacts and their verified public key material.
class Users extends Table {
  TextColumn get id => text()();
  TextColumn get username => text().nullable()();
  TextColumn get avatarPath => text().nullable()();
  BlobColumn get signingPublicKey => blob()();
  BlobColumn get encryptionPublicKey => blob()();
  DateTimeColumn get lastSeenAt => dateTime().nullable()();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// A direct or group conversation, with local presentation metadata.
class Chats extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().nullable()();
  BoolColumn get isGroup => boolean().withDefault(const Constant(false))();
  BoolColumn get pinned => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime()();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Encrypted payloads and routable metadata. Plaintext is never persisted here.
class Messages extends Table {
  TextColumn get id => text()();
  TextColumn get chatId => text().references(Chats, #id)();
  TextColumn get senderId => text()();
  TextColumn get receiverId => text()();
  BlobColumn get ciphertext => blob()();
  BlobColumn get nonce => blob()();
  BlobColumn get mac => blob()();
  BlobColumn get signature => blob()();
  IntColumn get ttl => integer()();
  IntColumn get hopCount => integer().withDefault(const Constant(0))();
  TextColumn get status => text()();
  DateTimeColumn get sentAt => dateTime()();
  DateTimeColumn get readAt => dateTime().nullable()();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Durable duplicate suppression across process restarts.
class SeenMessages extends Table {
  TextColumn get messageId => text()();
  DateTimeColumn get seenAt => dateTime()();
  @override
  Set<Column<Object>> get primaryKey => {messageId};
}

/// Outbound retry queue. Attempts are capped by the transport service.
class PendingQueue extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get messageId => text().references(Messages, #id)();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  DateTimeColumn get nextAttemptAt => dateTime()();
}

/// Cached directional hints for future routing strategies.
class RoutingCache extends Table {
  TextColumn get destinationId => text()();
  TextColumn get nextHopId => text()();
  IntColumn get estimatedHops => integer()();
  DateTimeColumn get expiresAt => dateTime()();
  @override
  Set<Column<Object>> get primaryKey => {destinationId};
}

/// SQLite source of truth for messaging and routing state.
@DriftDatabase(
  tables: [Users, Chats, Messages, SeenMessages, PendingQueue, RoutingCache],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  Future<void> rememberSeenMessage(String messageId) =>
      into(seenMessages).insert(
        SeenMessagesCompanion.insert(
          messageId: messageId,
          seenAt: DateTime.now().toUtc(),
        ),
        mode: InsertMode.insertOrIgnore,
      );

  Future<bool> hasSeenMessage(String messageId) async =>
      (await (select(
        seenMessages,
      )..where((row) => row.messageId.equals(messageId))).getSingleOrNull()) !=
      null;
}

LazyDatabase _openConnection() => LazyDatabase(() async {
  final Directory documents = await getApplicationDocumentsDirectory();
  final file = File(path.join(documents.path, 'meshchat.sqlite'));
  return NativeDatabase.createInBackground(file);
});
