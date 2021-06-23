import 'dart:async';
import 'package:couchdb/couchdb.dart';
import 'package:couchdb_sqlite_sync/adapters/http_adapter.dart';
import 'package:couchdb_sqlite_sync/adapters/sqllite_adapter.dart';
import 'package:couchdb_sqlite_sync/model_class/doc.dart';
import 'package:synchronized/synchronized.dart' as Synchronized;

class PouchDB {
  var adapter;
  var lock = new Synchronized.Lock();

  String dbName;

  PouchDB({bool isLocal, this.dbName}) {
    if (isLocal) {
      adapter = new SqliteAdapter(dbName: dbName);
    } else {
      adapter = new HttpAdapter(dbName: dbName);
    }
  }

  Future<void> deleteDoc({Doc doc}) async {
    await lock.synchronized(() async {
      await adapter.deleteDoc(doc);
    });
  }

  Future<void> updateDoc({Doc doc}) async {
    await lock.synchronized(() async {
      await adapter.updateDoc(doc);
    });
  }

  Future<void> insertDoc({Doc doc}) async {
    await lock.synchronized(() async {
      await adapter.insertDoc(doc);
    });
  }

  Future<List<Doc>> getAllDocs() async {
    return await adapter.getAllDocs();
  }

  Future<Doc> getSelectedDoc({String id}) async {
    return await adapter.getSelectedDoc(id);
  }

  Stream stream() {
    return adapter.stream;
  }

  Future<String> getUpdateSeq() async {
    return await adapter.getUpdateSeq();
  }

  Future<List> getChangesSince({String lastSeq}) async {
    return await adapter.getChangesSince(lastSeq);
  }

  Future<List> getBulkDocs({Map diff}) async {
    return await adapter.getBulkDocs(diff);
  }

  Future<Map> getRevsDiff({Map revs}) async {
    return await adapter.getRevsDiff(revs);
  }

  Future<void> insertBulkDocs(
      {List<Object> bulkDocs, List<String> deletedDocs}) async {
    return await adapter.insertBulkDocs(bulkDocs, deletedDocs);
  }

  Future<void> insertLog(
      {String id, String rev, Map<String, Object> body}) async {
    return await adapter.insertLog(id: id, rev: rev, body: body);
  }

  Future<DocumentsResponse> getLog({String id}) async {
    return await adapter.getLog(id);
  }

  Synchronized.Lock dbLock() {
    return lock;
  }
}
