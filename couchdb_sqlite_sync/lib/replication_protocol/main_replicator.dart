import 'dart:convert';
import 'dart:typed_data';

import 'package:couchdb/couchdb.dart';
import 'package:couchdb_sqlite_sync/adapters/http_adapter.dart';
import 'package:couchdb_sqlite_sync/adapters/sqllite_adapter.dart';
import 'package:couchdb_sqlite_sync/model_class/dish.dart';
import 'package:couchdb_sqlite_sync/model_class/sequence_log.dart';
import 'package:couchdb_sqlite_sync/sequence_service/sqlite_sequence_manager.dart';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

class MainReplicator {
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

  int version;
  String curRev;
  String couchDbLastSeq;
  int sqliteLastSeq;
  String couchDbUpperBound;
  int sqliteUpperBound;

  MainReplicator() {
    version = 0;
    sqliteLastSeq = 0;
    couchDbLastSeq = '0';
  }

  Future<void> replicateFromCouchDB() async {
    await getReplicationLog();
    await getCouchDBUpperBound();
    await couchDbReplication();
    await getSqliteUpperbound();
    await writeReplicationLog();
  }

  Future<void> replicateFromSqlite() async {
    await getReplicationLog();
    await getSqliteUpperbound();
    await sqliteReplication();
    await getCouchDBUpperBound();
    await writeReplicationLog();
  }

  Future<void> getSqliteUpperbound() async {
    sqliteUpperBound = await sqliteSequenceManager.getUpdateSeq();
  }

  Future<void> getCouchDBUpperBound() async {
    DatabasesResponse databasesResponse = await dbs.dbInfo(dbName);
    couchDbUpperBound = databasesResponse.updateSeq;
  }

  Future<void> getReplicationLog() async {
    try {
      DocumentsResponse document = await docs.doc(dbName, "_local/$uuid");
      List replicatorHistory = document.doc['history'];
      couchDbLastSeq = replicatorHistory[0]['recorded_seq'];
      sqliteLastSeq = document.doc['source_last_seq'];
      curRev = document.rev;
      version = document.doc["replication_id_version"];
    } on CouchDbException catch (e) {
      print(e);
    }
  }

  Future<void> writeReplicationLog() async {
    String sessionId = uuidGenerator.v4();

    await httpAdapter
        .insertReplicationLog(id: '_local/$uuid', rev: curRev, body: {
      "history": [
        {"recorded_seq": couchDbUpperBound, "session_id": sessionId}
      ],
      "replication_id_version": version + 1,
      "session_id": sessionId,
      "source_last_seq": sqliteUpperBound
    });
  }

  Future<void> couchDbReplication() async {
    var streamRes = await Dio().get<ResponseBody>(
        'https://sync-dev.feedmeapi.com/a-dish/_changes?descending=false&feed=normal&heartbeat=10000&since=$couchDbLastSeq&style=all_docs&descending=true',
        options: Options(responseType: ResponseType.stream));

    streamRes.data.stream.listen((event) async {
      Uint8List bytes = Uint8List.fromList(event);
      String res = String.fromCharCodes(bytes);

      // var res = Utf8Decoder().convert(event);

      List result;
      print(res);
      if (res.isNotEmpty) {
        result = json.decode(res)['results'];
      }
      print(result.toString());

      if (result != null && result.length > 0) {
        print(result.first);
        Map<String, dynamic> revs = new Map();
        for (Map log in result) {
          revs.putIfAbsent(log['id'], () => {});
          revs[log['id']].putIfAbsent('_revisions', () => []);
          revs[log['id']]
              .putIfAbsent('_deleted', () => log['deleted'] ?? false);
          for (Map value in log['changes']) {
            revs[log['id']]['_revisions'].add(value['rev']);
          }
        }

        //Get ids to replicate
        Map revsDiff = await sqliteAdapter.revsDifferentWithSqlite(revs);
        List<Dish> updateDishes =
            await httpAdapter.getBulkDocs(revsDiff['update']);
        for (Dish dish in updateDishes) {
          await sqliteAdapter.updateDish(dish);
        }

        List<Dish> newDishes =
            await httpAdapter.getBulkDocs(revsDiff['insert']);
        for (Dish dish in newDishes) {
          await sqliteAdapter.insertDish(dish);
        }

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
  }

  //source = Sqlite
  //target = CouchDB
  //ask king do past revisions before deleted need include?
  Future<void> sqliteReplication() async {
    //get revs
    List<SequenceLog> sequences =
        await sqliteSequenceManager.getSequenceSince(sqliteLastSeq);
    Map<String, List<String>> revs = new Map();

    for (SequenceLog sequenceLog in sequences) {
      if (sequenceLog.deleted == 'true' && !revs.containsKey(sequenceLog.id)) {
        Dish dish =
            new Dish(id: int.parse(sequenceLog.id), rev: sequenceLog.rev);
        httpAdapter.deleteDish(dish);
      } else {
        revs.putIfAbsent(sequenceLog.id, () => []);
        List changesRev = jsonDecode(sequenceLog.changes)['changes'];
        for (Map value in changesRev) {
          revs[sequenceLog.id].add(value["rev"]);
        }
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
