import 'dart:async';
import 'package:couchdb_sqlite_sync/database.dart';
import 'package:couchdb_sqlite_sync/dish.dart';

class DishDao {
  final dbProvider = DatabaseProvider.dbProvider;

  Future<bool> isExistingData(int id) async {
    final db = await dbProvider.database;
    List<Map<String, dynamic>> result;
    result = await db.query(tableName, where: "id = ?", whereArgs: [id]);
    if (result.length > 0) {
      return true;
    }
    return false;
  }

  //Adds new
  Future<int> createdID() async {
    final db = await dbProvider.database;
    var result = await db.query(tableName, orderBy: "id DESC", limit: 1);

    List<Dish> lastDish = result.isNotEmpty
        ? result.map((item) => Dish.fromDatabaseJson(item)).toList()
        : [];

    return lastDish[0].id;
  }

  //Add new
  //Create subject
  Future<int> createSubject(Dish dish) async {
    final db = await dbProvider.database;
    print(dish.toDatabaseJson());
    var result = db.rawInsert(
        'INSERT INTO $tableName(name, no, rev) VALUES({$dish.name}, ${dish.no}, ${dish.rev})');
    return result;
  }

  //Get All
  Future<List<Dish>> getSubject({List<String> columns, String query}) async {
    final db = await dbProvider.database;
    List<Map<String, dynamic>> result;
    if (query != null) {
      if (query.isNotEmpty)
        result = await db.query(tableName,
            columns: columns, where: 'name LIKE ?', whereArgs: ["%$query%"]);
    } else {
      result = await db.query(tableName, columns: columns);
    }
    List<Dish> subjects = result.isNotEmpty
        ? result.map((item) => Dish.fromDatabaseJson(item)).toList()
        : [];

    print(result.toList().last);
    return subjects;
  }

  //Update record
  //auto increment
  Future<int> updateSubject(Dish todo) async {
    final db = await dbProvider.database;
    var result = await db.update(tableName, todo.toDatabaseJson(),
        where: "id = ?", whereArgs: [todo.id]);
    return result;
  }

  Future<int> deleteSubject(int id) async {
    final db = await dbProvider.database;
    var result = await db.delete(tableName, where: 'id = ?', whereArgs: [id]);
    return result;
  }

  Future deleteAllSubject() async {
    final db = await dbProvider.database;
    var result = await db.delete(
      tableName,
    );
    return result;
  }
}