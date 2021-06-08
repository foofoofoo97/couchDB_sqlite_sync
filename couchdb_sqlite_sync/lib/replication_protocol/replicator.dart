import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:couchdb/couchdb.dart';
import 'package:couchdb_sqlite_sync/adapters/http_adapter.dart';
import 'package:couchdb_sqlite_sync/adapters/sqllite_adapter.dart';
import 'package:couchdb_sqlite_sync/model_class/dish.dart';
import 'package:couchdb_sqlite_sync/model_class/sequence_log.dart';
import 'package:couchdb_sqlite_sync/sequence_service/sqlite_sequence_manager.dart';
import 'package:dio/dio.dart';
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

  trigger(String srce, String target) async {
    this.source = srce;
    this.target = target;

    await getReplicationLog();
    await getSourceUpperBound(srce);

    switch (srce) {
      case 'couchdb':
        await replicateFromCouchDb();
        break;

      default:
        await replicateFromSqlite();
        break;
    }
    await getTargetUpperBound(srce);
    await writeReplicationLog();
  }

  Future<void> getSourceUpperBound(String source) async {
    if (source == "couchdb") {
      sourceUpperBound = await getCouchDBUpperBound();
    } else {
      sourceUpperBound =
          (await sqliteSequenceManager.getUpdateSeq()).toString();
    }
  }

  Future<void> getTargetUpperBound(String source) async {
    if (source == "couchdb") {
      targetUpperBound =
          (await sqliteSequenceManager.getUpdateSeq()).toString();
    } else {
      targetUpperBound = await getCouchDBUpperBound();
    }
  }

  Future<String> getCouchDBUpperBound() async {
    DatabasesResponse databasesResponse = await dbs.dbInfo(dbName);
    return databasesResponse.updateSeq;
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
    print('i am here replicater');
    print(sourceLastSeq);

    final streamRes = await Dio().get<ResponseBody>(
        'https://sync-dev.feedmeapi.com/a-dish/_changes?descending=false&feed=normal&heartbeat=10000&since=$sourceLastSeq&style=all_docs',
        options: Options(responseType: ResponseType.stream));
    streamRes.data.stream.listen((event) async {
      String res = utf8.decode(event);
      print(res);
      print(jsonDecode(res)['results']);
      List result = jsonDecode(res)['results'];
      if (result != null && result.length > 0) {
        print(result.first);
        Map<String, dynamic> revs = new Map();
        for (Map log in result) {
          revs.putIfAbsent(log['id'], () => {});
          revs[log['id']].putIfAbsent('_revisions', () => []);
          print('deleted');
          print(log['deleted']);
          revs[log['id']]
              .putIfAbsent('_deleted', () => log['deleted'] ?? false);
          for (Map value in log['changes']) {
            revs[log['id']]['_revisions'].add(value['rev']);
          }
        }

        //Get ids to replicate
        Map revsDiff = await sqliteAdapter.revsDifferentWithSqlite(revs);
        await httpAdapter.getBulkDocs(revsDiff['missing']);
        print(revsDiff['deleted']);
        for (String id in revsDiff['deleted'].keys) {
          Dish dish = await sqliteAdapter.getSelectedDish(int.parse(id));
          SequenceLog sequenceLog = new SequenceLog(
              rev: revsDiff['deleted'][id],
              data: dish.data,
              deleted: 'true',
              changes: jsonEncode({
                "changes": [
                  {"rev": revsDiff['deleted'][id]}
                ]
              }),
              id: dish.id.toString());
          await sqliteAdapter.deleteDish(dish);
          await sqliteSequenceManager.addSequence(sequenceLog);
        }
      }
    });
    // dbs
    //     .changesIn(dbName,
    //         feed: 'normal',
    //         since: sourceLastSeq,
    //         descending: false,
    //         style: "all_docs",
    //         heartbeat: 10000)
    //     .asStream()
    //     .listen((event) {
    //   event.listen((databasesResponse) async {
    //     List result = jsonDecode(databasesResponse.result)['result'];
    //     print('I got result');
    //     print(result);

    //     if (result != null && result.length > 0) {
    //       print(result.first);
    //       Map<String, dynamic> revs = new Map();
    //       for (Map log in result) {
    //         revs.putIfAbsent(log['id'], () => {});
    //         revs[log['id']].putIfAbsent('_revisions', () => []);
    //         print('deleted');
    //         print(log['deleted']);
    //         revs[log['id']]
    //             .putIfAbsent('_deleted', () => log['deleted'] ?? false);
    //         for (Map value in log['changes']) {
    //           revs[log['id']]['_revisions'].add(value['rev']);
    //         }
    //       }

    //       //Get ids to replicate
    //       Map revsDiff = await sqliteAdapter.revsDifferentWithSqlite(revs);
    //       await httpAdapter.getBulkDocs(revsDiff['missing']);
    //       print(revsDiff['deleted']);
    //       for (String id in revsDiff['deleted'].keys) {
    //         Dish dish = await sqliteAdapter.getSelectedDish(int.parse(id));
    //         SequenceLog sequenceLog = new SequenceLog(
    //             rev: revsDiff['deleted'][id],
    //             data: dish.data,
    //             deleted: 'true',
    //             changes: jsonEncode({
    //               "changes": [
    //                 {"rev": revsDiff['deleted'][id]}
    //               ]
    //             }),
    //             id: dish.id.toString());
    //         await sqliteAdapter.deleteDish(dish);
    //         await sqliteSequenceManager.addSequence(sequenceLog);
    //       }
    //     }
    //   }, onDone: () {
    //     print("Task Done");
    //   }, onError: (error) {
    //     print("Some Error");
    //   });
    // });
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
