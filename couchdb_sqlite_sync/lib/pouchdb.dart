import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:couchdb_sqlite_sync/adapters/http_adapter.dart';
import 'package:couchdb_sqlite_sync/adapters/sqllite_adapter.dart';
import 'package:couchdb_sqlite_sync/dish.dart';

class PouchDB {
  static final SqliteAdapter sqliteAdapter = SqliteAdapter();
  static final HttpAdapter httpAdapter = HttpAdapter();
  static final _dishController = StreamController<List<Dish>>.broadcast();
  static get dishStream => _dishController.stream;

  static bool isSql;

  dispose() {
    _dishController.close();
  }

  static String generateRandomString(int len) {
    var r = Random(DateTime.now().millisecond);
    const _chars = 'abcdefghijklmnopqrstuvwxyz1234567890';
    return List.generate(len, (index) => _chars[r.nextInt(_chars.length)])
        .join();
  }

  static Stream<List<Dish>> getStream({bool isSqlite}) {
    if (isSqlite) {
      return sqliteAdapter.subjectList;
    } else {
      return httpAdapter.subjectList;
    }
  }

  static void getDish() async {
    List<Dish> dishes = new List();

    if (isSql) {
      dishes = await sqliteAdapter.getAllDish();
    } else {
      dishes = await httpAdapter.getAllDish();
    }

    _dishController.sink.add(dishes);
  }

  static void deleteDish({bool isSync = false, Dish dish}) async {
    if (isSync) {
      String hasID = await sqliteAdapter.isExistingID(dish.id);
      if (hasID != null) {
        await sqliteAdapter.deleteDish(dish);
      }
    } else {
      await sqliteAdapter.deleteDish(dish);
      //await httpAdapter.deleteDish(dish);
    }

    getDish();
  }

  static void updateDish({bool isSync = false, Dish dish}) async {
    if (isSync) {
      await sqliteAdapter.updateDish(dish);
    } else {
      String head = dish.rev.split('-')[0];
      String code = dish.rev.split('-')[1];
      int version = int.parse(head);

      version = version + 1;
      dish.rev = version.toString() + '-' + code;
      await sqliteAdapter.updateDish(dish);
      await httpAdapter.updateDish(dish);
    }

    getDish();
  }

  static void insertDish({bool isSync = false, Dish dish}) async {
    if (isSync) {
      sqliteAdapter.insertDish(dish);
    } else {
      dish.id = await sqliteAdapter.createdID() + 1;
      dish.rev = "0-${generateRandomString(33)}";
      Map data = jsonDecode(dish.data);
      dish.data = jsonEncode(({
        "id": dish.id,
        "name": data["name"],
        "no": data['no'],
        "rev": dish.rev
      }));

      await sqliteAdapter.insertDish(dish);
      await httpAdapter.insertDish(dish);
    }

    getDish();
  }

  static void updateSyncing(Map data) async {
    Dish dish = new Dish(
      id: int.parse(data['doc']['_id']),
      data: data['doc']['data'],
      rev: data['doc']['_rev'],
    );
    String currentRev =
        await sqliteAdapter.isExistingID(int.parse(data['doc']['_id']));
    if (currentRev != null) {
      int currentVersion = int.parse(currentRev.split('-')[0]);
      int couchVersion = int.parse(dish.rev.split('-')[0]);
      if (currentVersion < couchVersion) {
        updateDish(isSync: true, dish: dish);
      }
    } else {
      insertDish(isSync: true, dish: dish);
    }
  }

  static void buildStreamSubscription(StreamSubscription subscription) {
    subscription = httpAdapter.changesIn().asStream().listen((event) {
      event.listen((databasesResponse) {
        List results = httpAdapter.listenToEvent(databasesResponse);
        for (Map doc in results) {
          if (doc.containsKey('deleted')) {
            deleteDish(
                isSync: true, dish: Dish(id: int.parse(doc['doc']['_id'])));
          } else {
            updateSyncing(doc);
          }
        }
      });
    }, onDone: () {
      print("Task Done");
      subscription.cancel();
      buildStreamSubscription(subscription);
    }, onError: (error) {
      print("Some Error");
    });
  }
}
