import 'dart:async';
import 'package:couchdb_sqlite_sync/adapters/http_adapter.dart';
import 'package:couchdb_sqlite_sync/pouchdb.dart';
import 'package:couchdb_sqlite_sync/replication_protocol/main_replicator.dart';

class Sychronizer {
  StreamSubscription localSubscription;
  StreamSubscription remoteSubscription;

  HttpAdapter httpAdapter = new HttpAdapter();

  Sychronizer() {
    localSubscription = PouchDB.dishStream.listen((event) async {
      await MainReplicator().replicateFromSqlite();
    });

    buildRemoteSubscription(remoteSubscription);
  }

  buildRemoteSubscription(StreamSubscription subscription) {
    subscription = httpAdapter.changesIn().asStream().listen((event) {
      event.listen((databasesResponse) async {
        print("i am synchronizing ");
        await MainReplicator().replicateFromCouchDB();
        PouchDB.getDish();
      });
    }, onDone: () {
      print("Task Done");
      subscription.cancel();
      buildRemoteSubscription(subscription);
    }, onError: (error) {
      print("Some Error");
    });
  }

  cancel() {
    localSubscription.cancel();
    remoteSubscription.cancel();
  }
}
