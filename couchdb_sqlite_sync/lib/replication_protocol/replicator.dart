import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:couchdb/couchdb.dart';
import 'package:couchdb_sqlite_sync/adapters/http_adapter.dart';
import 'package:couchdb_sqlite_sync/adapters/sqllite_adapter.dart';
import 'package:couchdb_sqlite_sync/model_class/sequence_log.dart';
import 'package:couchdb_sqlite_sync/sequence_service/sqlite_sequence_manager.dart';
import 'package:uuid/uuid.dart';

class Replicator {
  //temp replication id
  final String uuid = "2b93a1dd-c17f-4422-addd-d432c5ae39c6";
  final uuidGenerator = new Uuid();

  final String dbName = "a-dish";
  static final client = CouchDbClient(
    username: 'admin',
    password: 'secret',
    scheme: 'https',
    host: 'sync-dev.feedmeapi.com',
    port: 443,
    cors: true,
  );
  final dbs = Databases(client);
  final docs = Documents(client);

  SqliteSequenceManager sqliteSequenceManager = SqliteSequenceManager();
  SqliteAdapter sqliteAdapter = SqliteAdapter();
  HttpAdapter httpAdapter = HttpAdapter();

  String sourceUpperBound;
  String targetUpperBound;
  String sourceLastSeq;
  String targetLastSeq;
  String source;
  String target;

  //Replication Log
  int version;
  String curRev;

  static String generateRandomString(int len) {
    var r = Random(DateTime.now().millisecond);
    const _chars = 'abcdefghijklmnopqrstuvwxyz1234567890';
    return List.generate(len, (index) => _chars[r.nextInt(_chars.length)])
        .join();
  }

  trigger(String source, String target) async {
    this.source = source;
    this.target = target;

    await getFeedUpperBound();
    await getReplicationLog();

    switch (source) {
      case 'couchdb':
        await replicateFromCouchDb();
        break;

      default:
        await replicateFromSqlite();
        break;
    }

    await writeReplicationLog();
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
      version = 0;
      DocumentsResponse document = await docs.doc(dbName, "_local/$uuid");

      List replicatorHistory = document.doc['history'];
      String remoteCheckpoint = replicatorHistory[0]['recorded_seq'];
      String localCheckpoint = document.doc['source_last_seq'];
      curRev = document.rev;
      version = document.doc["replication_id_version"];

      if (source == 'couchdb') {
        sourceLastSeq = remoteCheckpoint;
        targetLastSeq = localCheckpoint;
      } else {
        sourceLastSeq = localCheckpoint;
        targetLastSeq = remoteCheckpoint;
      }
    } on CouchDbException catch (e) {
      print(e);
    }
  }

  Future<void> writeReplicationLog() async {
    String sessionId = uuidGenerator.v4();

    await httpAdapter
        .insertReplicationLog(id: '_local/$uuid', rev: curRev, body: {
      "history": [
        {
          "recorded_seq":
              source == 'couchdb' ? sourceUpperBound : targetUpperBound,
          "session_id": sessionId
        }
      ],
      "replication_id_version": version + 1,
      "session_id": sessionId,
      "source_last_seq":
          source == 'couchdb' ? targetUpperBound : sourceUpperBound
    });
  }

  //source = CouchDB
  //target = Sqlite
  Future<void> replicateFromCouchDb() async {
    dbs
        .changesIn(dbName,
            feed: 'normal',
            since: sourceLastSeq,
            style: "all_docs",
            heartbeat: 10000)
        .asStream()
        .listen((event) {
      event.listen((databasesResponse) {
        return jsonDecode(databasesResponse.result)['result'];
      }, onDone: () {
        print("Task Done");
      }, onError: (error) {
        print("Some Error");
      });
    });
  }

  //source = Sqlite
  //target = CouchDB
  Future<void> replicateFromSqlite() async {
    //get revs
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

    Map<String, Map<String, List<String>>> revsDiff =
        await httpAdapter.revsDifferentWithCouchDb(revs);

    //get bulk docs from Sqlite
    List<Object> bulkDocs = await sqliteAdapter.getBulkDocs(revsDiff);

    //insert bulk docs to CouchDb
    await httpAdapter.insertBulkDocs(bulkDocs);
    await httpAdapter.ensureFullCommit();
  }
}
