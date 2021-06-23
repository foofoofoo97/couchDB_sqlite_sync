import 'dart:async';
import 'package:couchdb_sqlite_sync/pouchdb.dart';
import 'package:couchdb_sqlite_sync/replication_protocol/replicator.dart';

class Sychronizer {
  StreamSubscription localSubscription;
  StreamSubscription remoteSubscription;
  PouchDB localDB;
  PouchDB remoteDB;

  Future<void> init({
    PouchDB localDb,
    PouchDB remoteDb,
    Function callback,
  }) async {
    localDB = localDb;
    remoteDB = remoteDb;

    await Replicator(localDb: localDB, remoteDb: remoteDB)
        .replicateFromSqlite();
    await Replicator(localDb: localDB, remoteDb: remoteDB)
        .replicateFromCouchDB();
    callback();

    localSubscription = localDB.stream().listen((event) async {
      await Replicator(localDb: localDb, remoteDb: remoteDb)
          .replicateFromSqlite();
      callback();
    });

    remoteSubscription = remoteDB.stream().listen((event) async {
      await Replicator(localDb: localDb, remoteDb: remoteDb)
          .replicateFromCouchDB();
      callback();
    });
  }

  void cancel() {
    localSubscription.cancel();
    remoteSubscription.cancel();
  }
}
