import 'dart:async';
import 'package:couchdb_sqlite_sync/database/database.dart';
import 'package:couchdb_sqlite_sync/model_class/doc.dart';

class DatabaseDao {
  DatabaseProvider dbProvider;
  String dbName;

  DatabaseDao({this.dbName}) {
    dbProvider = new DatabaseProvider(dbName: dbName);
  }

  Future<String> isExistingDoc({String id}) async {
    final db = await dbProvider.database;
    List<Map<String, dynamic>> result;

    result = await db.query(dbName, where: "id = ?", whereArgs: [id]);

    if (result.length > 0) {
      return result[0]['rev'].toString();
    }
    return null;
  }

  // Future<int> createdID() async {
  //   final db = await dbProvider.database;
  //   var result = await db.query(dbName, orderBy: "id DESC", limit: 1);

  //   List<Doc> lastDoc = result.isNotEmpty
  //       ? result.map((item) => Doc.fromDatabaseJson(item)).toList()
  //       : [];

  //   return lastDoc.length == 0 ? 0 : lastDoc[0].id;
  // }

  Future<int> createDoc({Doc doc}) async {
    final db = await dbProvider.database;
    var result = await db.rawInsert(
        'INSERT INTO $dbName(id, data, rev, revisions) VALUES(\'${doc.id}\', \'${doc.data}\', "${doc.rev}", \'${doc.revisions}\')');

    return result;
  }

  Future<Doc> getDoc({String id}) async {
    final db = await dbProvider.database;
    List<Map<String, dynamic>> result;

    result = await db.query(dbName, where: 'id = ?', whereArgs: [id]);

    List<Doc> docs = result.isNotEmpty
        ? result.map((item) => Doc.fromDatabaseJson(item)).toList()
        : [];

    return docs.length == 0 ? null : docs[0];
  }

  Future<List<Doc>> getAllDocs(
      {List<String> columns, String query, String order}) async {
    final db = await dbProvider.database;
    List<Map<String, dynamic>> result;

    if (query != null) {
      if (query.isNotEmpty)
        result = await db.query(dbName,
            columns: columns,
            where: 'id LIKE ?',
            whereArgs: ["$query"],
            orderBy: order != null ? "id $order" : null);
    } else {
      result = await db.query(dbName, columns: columns);
    }

    List<Doc> docs = result.isNotEmpty
        ? result.map((item) => Doc.fromDatabaseJson(item)).toList()
        : [];

    return docs;
  }

  Future<int> updateDoc({Doc doc}) async {
    final db = await dbProvider.database;
    var result = await db.update(dbName, doc.toDatabaseJson(),
        where: "id = ?", whereArgs: [doc.id]);
    return result;
  }

  Future<int> deleteDoc({String id}) async {
    final db = await dbProvider.database;
    var result = await db.delete(dbName, where: 'id = ?', whereArgs: [id]);
    return result;
  }

  Future deleteAllDocs() async {
    final db = await dbProvider.database;
    var result = await db.delete(
      dbName,
    );
    return result;
  }
}
