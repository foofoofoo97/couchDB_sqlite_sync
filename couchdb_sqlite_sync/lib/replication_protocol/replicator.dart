import 'dart:convert';
import 'package:couchdb/couchdb.dart';
import 'package:couchdb_sqlite_sync/model_class/doc.dart';
import 'package:couchdb_sqlite_sync/model_class/sequence_log.dart';
import 'package:couchdb_sqlite_sync/pouchdb.dart';
import 'package:uuid/uuid.dart';

class Replicator {
  final String uuid = "2b93a1dd-c17f-4422-addd-d432c5ae39c6";
  final String uuid2 = "49ef41c4-6d12-4eff-8d22-62e2fdb82f5b";
  final uuidGenerator = new Uuid();
  final String dbName = "a-dish";

  PouchDB remoteDb;
  PouchDB localDb;

  int version;
  String curRev;
  String remoteLastSeq;
  String localLastSeq;
  String remoteUpperBound;
  String localUpperBound;

  Replicator({this.remoteDb, this.localDb}) {
    version = 0;
    localLastSeq = '0';
    remoteLastSeq = '0';
  }

  Future<void> replicateFromCouchDB() async {
    await localDb.dbLock().synchronized(() async {
      await getReplicationLogForSqlite();
      await getRemoteUpperBound();
      await couchDbReplication();
      await getLocalUpperbound();
      await writeReplicationLogForSqlite();
    });
  }

  Future<void> replicateFromSqlite() async {
    await remoteDb.dbLock().synchronized(() async {
      await getReplicationLogForCouchDb();
      await getLocalUpperbound();
      await sqliteReplication();
      await getRemoteUpperBound();
      await writeReplicationLogForCouchDb();
    });
  }

  Future<void> getLocalUpperbound() async {
    localUpperBound = await localDb.getUpdateSeq();
  }

  Future<void> getRemoteUpperBound() async {
    remoteUpperBound = await remoteDb.getUpdateSeq();
  }

  Future<void> getReplicationLogForCouchDb() async {
    try {
      DocumentsResponse document = await remoteDb.getLog(id: "_local/$uuid");

      List replicatorHistory = document.doc['history'];
      remoteLastSeq = replicatorHistory[0]['recorded_seq'];
      localLastSeq = document.doc['source_last_seq'];
      curRev = document.rev;
      version = document.doc["replication_id_version"];
    } catch (e) {
      print('no replication log for couchdb');
    }
  }

  Future<void> getReplicationLogForSqlite() async {
    try {
      DocumentsResponse document = await remoteDb.getLog(id: "_local/$uuid2");
      List replicatorHistory = document.doc['history'];
      localLastSeq = replicatorHistory[0]['recorded_seq'];
      remoteLastSeq = document.doc['source_last_seq'];
      curRev = document.rev;
      version = document.doc["replication_id_version"];
    } catch (e) {
      print('no replication log for sql');
    }
  }

  Future<void> writeReplicationLogForCouchDb() async {
    String sessionId = uuidGenerator.v4();
    await remoteDb.insertLog(id: '_local/$uuid', rev: curRev, body: {
      "history": [
        {"recorded_seq": remoteUpperBound, "session_id": sessionId}
      ],
      "replication_id_version": version + 1,
      "session_id": sessionId,
      "source_last_seq": localUpperBound
    });
  }

  Future<void> writeReplicationLogForSqlite() async {
    String sessionId = uuidGenerator.v4();
    await remoteDb.insertLog(id: '_local/$uuid2', rev: curRev, body: {
      "history": [
        {"recorded_seq": localUpperBound, "session_id": sessionId}
      ],
      "replication_id_version": version + 1,
      "session_id": sessionId,
      "source_last_seq": remoteUpperBound
    });
  }

  Future<void> couchDbReplication() async {
    List result = await remoteDb.getChangesSince(lastSeq: remoteLastSeq);

    if (result != null && result.length > 0) {
      Map<String, dynamic> revs = new Map();
      for (Map log in result) {
        revs.putIfAbsent(log['id'], () => {});
        revs[log['id']].putIfAbsent('_revisions', () => []);
        revs[log['id']].putIfAbsent('_deleted', () => log['deleted'] ?? false);
        for (Map value in log['changes']) {
          revs[log['id']]['_revisions'].add(value['rev']);
        }
      }

      //Get ids to replicate
      Map revsDiff = await localDb.getRevsDiff(revs: revs);

      List<Doc> updateDishes =
          await remoteDb.getBulkDocs(diff: revsDiff['update']);
      for (Doc doc in updateDishes) {
        await localDb.adapter.updateSourceDoc(doc);
      }

      List<Doc> newDishes =
          await remoteDb.getBulkDocs(diff: revsDiff['insert']);
      for (Doc doc in newDishes) {
        await localDb.adapter.insertSourceDoc(doc);
      }

      for (String id in revsDiff['deleted'].keys) {
        Doc doc = await localDb.getSelectedDoc(id: id);
        await localDb.adapter.deleteDoc(doc);
      }
    }
  }

  Future<void> sqliteReplication() async {
    //get revs
    List<SequenceLog> sequences =
        await localDb.getChangesSince(lastSeq: localLastSeq);
    Map<String, List<String>> revs = new Map();
    List<String> deletedDocs = new List();

    for (SequenceLog sequenceLog in sequences) {
      if (sequenceLog.deleted == 'true' && !revs.containsKey(sequenceLog.id)) {
        Doc doc = new Doc(id: int.parse(sequenceLog.id), rev: sequenceLog.rev);
        await remoteDb.adapter.deleteDoc(doc);
        deletedDocs.add(doc.id.toString());
      } else {
        revs.putIfAbsent(sequenceLog.id, () => []);
        List changesRev = jsonDecode(sequenceLog.changes)['changes'];
        for (Map value in changesRev) {
          revs[sequenceLog.id].add(value["rev"]);
        }
      }
    }

    Map<String, Map<String, List<String>>> revsDiff =
        await remoteDb.getRevsDiff(revs: revs);

    List<Object> bulkDocs = await localDb.getBulkDocs(diff: revsDiff);

    await remoteDb.insertBulkDocs(bulkDocs: bulkDocs, deletedDocs: deletedDocs);
  }
}
