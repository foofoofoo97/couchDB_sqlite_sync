import 'dart:async';
import 'package:couchdb_sqlite_sync/model_class/dish.dart';
import 'package:couchdb_sqlite_sync/pouchdb.dart';
import 'package:couchdb_sqlite_sync/replication_protocol/synchronizer.dart';

class DishStream {
  static final _dishController = StreamController<List<Dish>>.broadcast();
  static get dishStream => _dishController.stream;
  static bool isSql;
  static bool isSync;

  static PouchDB remoteDB = new PouchDB(isLocal: false);
  static PouchDB localDB = new PouchDB(isLocal: true);
  static Sychronizer sychronizer = new Sychronizer();

  dispose() {
    _dishController.close();
  }

  DishStream({bool isSqlite, bool isSyc}) {
    isSql = isSqlite;
    isSync = isSyc;
    sychronizer.init(
        remoteDb: remoteDB,
        localDb: localDB,
        callback: () {
          getDish();
        });
    getDish();
  }

  static void setIsSql(bool isSqlite) {
    isSql = isSqlite;
    getDish();
  }

  static void updateSync(bool isSyc) async {
    isSync = isSyc;
    if (isSync) {
      sychronizer.init(
          remoteDb: remoteDB,
          localDb: localDB,
          callback: () {
            getDish();
          });
    } else {
      sychronizer.cancel();
    }
  }

  static void getDish() async {
    _dishController.sink
        .add(isSql ? await localDB.getAllDish() : await remoteDB.getAllDish());
  }

  static Future<void> deleteDish({Dish dish}) async {
    isSql
        ? await localDB.deleteDish(dish: dish)
        : await remoteDB.deleteDish(dish: dish);

    getDish();
  }

  static Future<void> insertDish({Dish dish}) async {
    isSql
        ? await localDB.insertDish(dish: dish)
        : await remoteDB.insertDish(dish: dish);

    getDish();
  }

  static Future<void> updateDish({Dish dish}) async {
    isSql
        ? await localDB.updateDish(dish: dish)
        : await remoteDB.updateDish(dish: dish);

    getDish();
  }
}
