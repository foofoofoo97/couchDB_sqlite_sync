import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:couchdb/couchdb.dart';
import 'package:couchdb_sqlite_sync/adapters/http_adapter.dart';
import 'package:couchdb_sqlite_sync/adapters/sqllite_adapter.dart';
import 'package:couchdb_sqlite_sync/model_class/dish.dart';
import 'package:synchronized/synchronized.dart' as Synchronized;

class PouchDB {
  var adapter;
  var lock = new Synchronized.Lock();

  String generateRandomString(int len) {
    var r = Random(DateTime.now().millisecond);
    const _chars = 'abcdefghijklmnopqrstuvwxyz1234567890';
    return List.generate(len, (index) => _chars[r.nextInt(_chars.length)])
        .join();
  }

  PouchDB({bool isLocal}) {
    if (isLocal) {
      adapter = new SqliteAdapter();
    } else {
      adapter = new HttpAdapter();
    }
  }

  Future<Stream<DatabasesResponse>> buildStreamSubscription(
      StreamSubscription subscription) async {
    return await adapter.changesIn();
  }

  Future<void> deleteDish({Dish dish}) async {
    await lock.synchronized(() async {
      await adapter.deleteDish(dish);
    });
  }

  Future<void> updateDish({Dish dish}) async {
    //update rev
    String head = dish.rev.split('-')[0];
    String code = generateRandomString(33);
    int version = int.parse(head);
    version = version + 1;
    dish.rev = version.toString() + '-' + code;

    //update revisions
    if (dish.revisions != null) {
      Map revisions = jsonDecode(dish.revisions);
      revisions['_revisions'].insert(0, dish.rev.split('-')[1]);
      dish.revisions = jsonEncode(revisions);
    }

    await lock.synchronized(() async {
      await adapter.updateDish(dish);
    });
  }

  Future<void> insertDish({Dish dish}) async {
    await lock.synchronized(() async {
      dish.id = await adapter.createdID() + 1;
      dish.rev = "0-${generateRandomString(33)}";
      dish.revisions = jsonEncode({
        "_revisions": [dish.rev.split('-')[1]]
      });

      await adapter.insertDish(dish);
    });
  }

  Future<List<Dish>> getAllDish() async {
    return await adapter.getAllDish();
  }

  Stream dishStream() {
    return adapter.dishStream;
  }

  Synchronized.Lock dbLock() {
    return lock;
  }
}
