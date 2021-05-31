import 'dart:async';
import 'dart:convert';

import 'package:couchdb/couchdb.dart';
import 'package:couchdb_sqlite_sync/model_class/sequence_log.dart';
import 'package:couchdb_sqlite_sync/sequence_service/sqlite_sequence_manager.dart';

class Replicator {
  //temp replication id
  final String uuid = "2b93a1dd-c17f-4422-addd-d432c5ae39c6";

  final String dbName = "a-dish";
  static final client = CouchDbClient(
    username: 'admin',
    password: 'secret',
    scheme: 'https',
    host: 'sync-dev.feedmeapi.com',
    port: 443,
    cors: true,
  );
  static final dbs = Databases(client);
  static final docs = Documents(client);
  SqliteSequenceManager sqliteSequenceManager = SqliteSequenceManager();

  String sourceUpperBound;
  String targetUpperBound;
  String sourceLastSeq;
  String targetLastSeq;
  String source;
  String target;

  trigger(String source, String target) async {
    this.source = source;
    this.target = target;

    await getFeedUpperBound();
    await getReplicationLog();

    switch (source) {
      case 'couchdb':
        await listenToFeedChangesFrmCouchDb();
        break;

      default:
        await listenToFeedChangesFrmSqlite();
        break;
    }
  }

  Future<void> getFeedUpperBound() async {
    if (source == "couchdb") {
      targetUpperBound =
          (await sqliteSequenceManager.getUpdateSeq()).toString();
      sourceUpperBound = await getCouchDBUpperBound();
    } else {
      sourceUpperBound =
          (await sqliteSequenceManager.getUpdateSeq()).toString();
      targetUpperBound = await getCouchDBUpperBound();
    }
  }

  Future<String> getCouchDBUpperBound() async {
    DatabasesResponse databasesResponse = await dbs.dbInfo(dbName);
    return databasesResponse.updateSeq.split('-')[0];
  }

  Future<void> getReplicationLog() async {
    try {
      sourceLastSeq = "0";
      targetLastSeq = "0";
      DocumentsResponse document = await docs.doc(dbName, "_local/$uuid");
    } on CouchDbException catch (e) {
      print(e);
    }
  }

  //source = CouchDB
  //target = Sqlite
  Future<void> listenToFeedChangesFrmCouchDb() async {
    dbs
        .changesIn(dbName,
            feed: 'normal',
            since: sourceLastSeq,
            style: "all_docs",
            heartbeat: 10000)
        .asStream()
        .listen((event) {
      event.listen((databasesResponse) {
        print(jsonDecode(databasesResponse.result)['result'].last);
      }, onDone: () {
        print("Task Done");
      }, onError: (error) {
        print("Some Error");
      });
    });
  }

  //source = Sqlite
  //target = CouchDB
  Future<void> listenToFeedChangesFrmSqlite() async {
    List<SequenceLog> sequences =
        await sqliteSequenceManager.getSequenceSince(int.parse(sourceLastSeq));
    Map<String, List<String>> revs = new Map();
    for (SequenceLog sequenceLog in sequences) {
      revs.putIfAbsent(sequenceLog.id, () => []);
      List changesRev = jsonDecode(sequenceLog.changes)['changes'];
      for (Map value in changesRev) {
        revs[sequenceLog.id].add(value["rev"]);
      }
    }
  }

  Future<void> revsDifferent() async {}
}
