import 'dart:async';
import 'package:couchdb_sqlite_sync/database/sequence_db.dart';
import 'package:couchdb_sqlite_sync/model_class/sequence_log.dart';

class SequenceRepository {
  String dbName;
  SequenceDatabaseProvider dbProvider;

  SequenceRepository({this.dbName}) {
    dbProvider = SequenceDatabaseProvider(dbName: dbName);
  }

  Future<String> isExistingData(int id) async {
    final db = await dbProvider.database;
    List<Map<String, dynamic>> result;

    result = await db.query(dbName, where: "id = ?", whereArgs: [id]);
    if (result.length > 0) {
      return result[0]['rev'].toString();
    }
    return null;
  }

  //Adds new
  Future<int> getUpdateSeq() async {
    final db = await dbProvider.database;

    var result = await db.query(dbName, orderBy: "seq DESC", limit: 1);
    List<SequenceLog> lastSequence = result.isNotEmpty
        ? result.map((item) => SequenceLog.fromDatabaseJson(item)).toList()
        : [];

    return lastSequence.length == 0 ? 0 : lastSequence[0].seq;
  }

  //Add New Sequence To Sqlite
  Future<int> addSequence(SequenceLog sequenceLog) async {
    final db = await dbProvider.database;
    var result = await db.rawInsert(
        'INSERT INTO $dbName(id, deleted, changes, data, rev) VALUES("${sequenceLog.id}", \'${sequenceLog.deleted}\', \'${sequenceLog.changes}\', \'${sequenceLog.data}\', "${sequenceLog.rev}")');
    return result;
  }

  //Get Sequence Which Is Missing From CouchDB
  Future<SequenceLog> getSequence(int seq) async {
    final db = await dbProvider.database;
    List<Map<String, dynamic>> result;

    result = await db.query(dbName, where: 'seq = ?', whereArgs: [seq]);
    List<SequenceLog> sequences = result.isNotEmpty
        ? result.map((item) => SequenceLog.fromDatabaseJson(item)).toList()
        : [];

    return sequences.length == 0 ? null : sequences[0];
  }

  Future<List<SequenceLog>> getSequenceById(String id) async {
    final db = await dbProvider.database;
    List<Map<String, dynamic>> result;

    result = await db
        .query(dbName, orderBy: "seq DESC", where: 'id = ?', whereArgs: [id]);
    List<SequenceLog> sequences = result.isNotEmpty
        ? result.map((item) => SequenceLog.fromDatabaseJson(item)).toList()
        : [];

    return sequences;
  }

  Future<List<SequenceLog>> getSequenceSince(int since) async {
    final db = await dbProvider.database;
    List<Map<String, dynamic>> result;

    result = await db.query(dbName,
        where: 'seq >= ?', orderBy: "seq DESC", whereArgs: [since]);
    List<SequenceLog> sequences = result.isNotEmpty
        ? result.map((item) => SequenceLog.fromDatabaseJson(item)).toList()
        : [];

    return sequences;
  }

  //Get All Sequences /Sequences from seq
  Future<List<SequenceLog>> getSequences(
      {List<String> columns, String query}) async {
    final db = await dbProvider.database;
    List<Map<String, dynamic>> result;
    if (query != null) {
      if (query.isNotEmpty)
        result = await db.query(dbName,
            columns: columns, where: 'name LIKE ?', whereArgs: ["%$query%"]);
    } else {
      result = await db.query(dbName, columns: columns);
    }
    List<SequenceLog> subjects = result.isNotEmpty
        ? result.map((item) => SequenceLog.fromDatabaseJson(item)).toList()
        : [];

    return subjects;
  }

  Future<int> deleteSequence(int id) async {
    final db = await dbProvider.database;
    var result = await db.delete(dbName, where: 'seq = ?', whereArgs: [id]);
    return result;
  }

  Future deleteAllSequences() async {
    final db = await dbProvider.database;
    var result = await db.delete(
      dbName,
    );
    return result;
  }
}
