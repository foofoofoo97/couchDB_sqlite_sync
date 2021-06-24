import 'dart:async';
import 'package:couchdb_sqlite_sync/pouchdb.dart';
import 'package:couchdb_sqlite_sync/replication_protocol/replicator.dart';

class Sychronizer {
  StreamSubscription localSubscription;
  StreamSubscription remoteSubscription;
  PouchDB localDB;
  PouchDB remoteDB;

  Sychronizer({this.localDB, this.remoteDB});

  Future<void> init({
    Function callback,
  }) async {
    await Replicator(localDb: localDB, remoteDb: remoteDB)
        .replicateFromSqlite();
    await Replicator(localDb: localDB, remoteDb: remoteDB)
        .replicateFromCouchDB();
    callback();

    localSubscription = localDB.stream().listen((event) async {
      await Replicator(localDb: localDB, remoteDb: remoteDB)
          .replicateFromSqlite();
      callback();
    });

    remoteSubscription = remoteDB.stream().listen((event) async {
      await Replicator(localDb: localDB, remoteDb: remoteDB)
          .replicateFromCouchDB();
      callback();
    });
  }

  void cancel() {
    localSubscription.cancel();
    remoteSubscription.cancel();
  }
}
