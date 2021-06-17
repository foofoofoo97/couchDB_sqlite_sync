import 'dart:async';
import 'package:couchdb_sqlite_sync/pouchdb.dart';
import 'package:couchdb_sqlite_sync/replication_protocol/main_replicator.dart';

class Sychronizer {
  StreamSubscription localSubscription;
  StreamSubscription remoteSubscription;
  PouchDB localDB;
  PouchDB remoteDB;

  void init({
    PouchDB localDb,
    PouchDB remoteDb,
    Function callback,
  }) async {
    localDB = localDb;
    remoteDB = remoteDb;

    await MainReplicator(localDB: localDb, remoteDB: remoteDb)
        .replicateFromSqlite();
    await MainReplicator(localDB: localDb, remoteDB: remoteDb)
        .replicateFromCouchDB();
    callback();

    localSubscription = localDB.dishStream().listen((event) async {
      await MainReplicator(localDB: localDb, remoteDB: remoteDb)
          .replicateFromSqlite();
      callback();
    });

    remoteSubscription = remoteDB.dishStream().listen((event) async {
      await MainReplicator(localDB: localDb, remoteDB: remoteDb)
          .replicateFromCouchDB();
      callback();
    });
  }

  void cancel() {
    localSubscription.cancel();
    remoteSubscription.cancel();
  }
}
