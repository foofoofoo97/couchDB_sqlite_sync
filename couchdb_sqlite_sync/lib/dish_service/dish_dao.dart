import 'dart:async';
import 'package:couchdb_sqlite_sync/database/dish_db.dart';
import 'package:couchdb_sqlite_sync/model_class/dish.dart';

class DishDao {
  final dbProvider = DatabaseProvider.dbProvider;

  Future<String> isExistingData(int id) async {
    final db = await dbProvider.database;
    List<Map<String, dynamic>> result;
    result = await db.query(tableName, where: "id = ?", whereArgs: [id]);
    if (result.length > 0) {
      return result[0]['rev'].toString();
    }
    return null;
  }

  //Adds new
  Future<int> createdID() async {
    final db = await dbProvider.database;
    var result = await db.query(tableName, orderBy: "id DESC", limit: 1);

    List<Dish> lastDish = result.isNotEmpty
        ? result.map((item) => Dish.fromDatabaseJson(item)).toList()
        : [];

    return lastDish.length == 0 ? 0 : lastDish[0].id;
  }

  //Add new
  //Create subject
  Future<int> createSubject(Dish dish) async {
    final db = await dbProvider.database;
    print(dish.rev);
    var result = await db.rawInsert(
        'INSERT INTO $tableName(id, data, rev) VALUES(${dish.id}, \'${dish.data}\', "${dish.rev}")');

    return result;
  }

  Future<Dish> getSelectedDish(int id) async {
    final db = await dbProvider.database;
    List<Map<String, dynamic>> result;

    result = await db.query(tableName, where: 'id = ?', whereArgs: [id]);
    List<Dish> dishes = result.isNotEmpty
        ? result.map((item) => Dish.fromDatabaseJson(item)).toList()
        : [];

    return dishes.length == 0 ? null : dishes[0];
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
