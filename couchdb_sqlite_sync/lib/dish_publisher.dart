import 'dart:convert';
import 'package:couchdb/couchdb.dart';
import 'package:couchdb_sqlite_sync/dish.dart';
import 'package:couchdb_sqlite_sync/todo_bloc.dart';

class DishPublisher {
  static final client = CouchDbClient(
    username: 'admin',
    password: 'secret',
    scheme: 'https',
    host: 'sync-dev.feedmeapi.com',
    port: 443,
    cors: true,
  );
  static final dbs = Databases(client);
  static final docs = Documents(client);
  static DishBloc dishBloc;
  //listen to online database changes
  static Future<Stream<DatabasesResponse>> onChanges() async {
    return await dbs.changesIn('a-dish',
        feed: 'longpoll', includeDocs: true, heartbeat: 1000, since: 'now');
  }

  static const Map<String, dynamic> triggerEvents = {
    "set": [setCouchDishDB],
    "update": [updateCouchDishDB],
    "delete": [deleteCouchDishDB],
    "sync_delete": [deleteSqllite],
    "sync_update": [updateSqllite],
  };

  static Future<void> updateSqllite(Map value) async {
    Dish dish = new Dish(
        id: int.parse(value['doc']['_id']),
        name: value['doc']['name'],
        rev: value['doc']['_rev'],
        no: value['doc']['no']);

    String currentRev =
        await dishBloc.isExistingID(int.parse(value['doc']['_id']));
    if (currentRev != null) {
      if (currentRev == dish.rev) {
        dishBloc.updateSubjectSync(dish);
      }
    } else {
      dishBloc.addSubjectSync(dish);
    }
  }

  static Future<void> deleteSqllite(Map value) async {
    String currentRev =
        await dishBloc.isExistingID(int.parse(value['doc']['_id']));
    if (currentRev != null && currentRev == value['doc']['_rev']) {
      dishBloc.deleteSubjectByIdSync(int.parse(value['id']));
    }
  }

  static Future<void> setCouchDishDB(Dish dish) async {
    try {
      await docs.insertDoc(
          'a-dish', dish.id.toString(), {'name': dish.name, 'no': dish.no},
          rev: dish.rev, newEdits: false);
    } on CouchDbException catch (e) {
      print('$e - error');
    }
  }

  static Future<void> updateCouchDishDB(Dish dish) async {
    try {
      await docs.insertDoc(
          'a-dish', dish.id.toString(), {'name': dish.name, 'no': dish.no},
          rev: dish.rev, newEdits: false);
    } on CouchDbException catch (e) {
      print('$e - error');
    }
  }

  static Future<void> deleteCouchDishDB(Dish dish) async {
    try {
      int count = 1 + int.parse(dish.rev.split('-')[0]);
      String newRev = count.toString() + '-' + dish.rev.split('-')[1];
      await docs.insertDoc('a-dish', dish.id.toString(),
          {'name': dish.name, 'no': dish.no, '_deleted': true},
          rev: newRev, newEdits: false);
    } on CouchDbException catch (e) {
      print('$e - error');
    }
  }

  //listen to changes
  static Future<void> update(Dish dish) async {
    //publish update
    for (Function func in triggerEvents['update']) {
      await func(dish);
    }
  }

  //listen to changes
  static Future<void> set(Dish dish) async {
    //publish update
    for (Function func in triggerEvents['set']) {
      await func(dish);
    }
  }

  static Future<void> delete(Dish dish) async {
    for (Function func in triggerEvents['delete']) {
      await func(dish);
    }
  }

  //listen to CouchDB Event
  static Future<void> listen(
      DatabasesResponse databasesResponse, DishBloc bloc) async {
    Map data = jsonDecode(databasesResponse.result);
    dishBloc = bloc;
    List result = data['result'];
    for (Map value in result) {
      if (value.containsKey('deleted')) {
        for (Function func in triggerEvents['sync_delete']) {
          await func(value);
        }
      } else {
        for (Function func in triggerEvents['sync_update']) {
          await func(value);
        }
      }
    }
  }
}
