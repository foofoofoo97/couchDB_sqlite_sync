import 'dart:async';
import 'package:couchdb_sqlite_sync/model_class/order.dart';
import 'package:couchdb_sqlite_sync/pouchdb.dart';
import 'package:couchdb_sqlite_sync/replication_protocol/synchronizer.dart';
import 'package:couchdb_sqlite_sync/repository/repository.dart';
import 'package:couchdb_sqlite_sync/repository/sort_order.dart';

class HomePageManager {
  final _controller = StreamController<List<Order>>.broadcast();
  get stream => _controller.stream;

  bool isSync;
  static String dbName = 'adish';
  static String type = 'order';

  static PouchDB remoteDB = new PouchDB(isLocal: false, dbName: dbName);
  static PouchDB localDB = new PouchDB(isLocal: true, dbName: dbName);

  Repository orderRepo = Repository<Order>(
      pouchdb: localDB,
      dbName: dbName,
      type: type,
      t: Order(),
      order: SortOrder.ASCENDING);

  SortOrder sortOrder;

  Sychronizer sychronizer =
      new Sychronizer(remoteDB: remoteDB, localDB: localDB);

  dispose() {
    _controller.close();
  }

  HomePageManager({this.isSync, this.sortOrder}) {
    sychronizer.init(callback: () {
      updateStream();
    });
    updateStream();
  }

  void setIsSql({bool isSql}) {
    orderRepo.changePouchDb(isSql ? localDB : remoteDB);
    updateStream();
  }

  Future<void> updateSync({bool isSync}) async {
    this.isSync = isSync;
    if (this.isSync) {
      await sychronizer.init(callback: () {
        updateStream();
      });
    } else {
      sychronizer.cancel();
    }
  }

  void changeOrder({SortOrder sortOrder}) {
    orderRepo.changeOrder(sortOrder);
    updateStream();
  }

  void updateStream() async {
    List<Order> orders = await orderRepo.getAllDocs();
    _controller.sink.add(orders);
  }

  Future<void> deleteDoc({Order order}) async {
    await orderRepo.deleteDoc(order);
    updateStream();
  }

  Future<void> insertDoc({Order order}) async {
    await orderRepo.insertDoc(order);
    updateStream();
  }

  Future<void> updateDoc({Order order}) async {
    await orderRepo.updateDoc(order);
    updateStream();
  }

  Future<void> updateDocs({List<Order> docs}) async {
    await orderRepo.updateDocs(docs);
  }

  Future<void> insertDocs({List<Order> docs}) async {
    await orderRepo.insertDocs(docs);
  }

  Future<void> deleteDocs({List<Order> docs}) async {
    await orderRepo.deleteDocs(docs);
  }
}
