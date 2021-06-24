import 'dart:async';
import 'package:couchdb_sqlite_sync/model_class/doc.dart';
import 'package:couchdb_sqlite_sync/model_class/order.dart';
import 'package:couchdb_sqlite_sync/pouchdb.dart';
import 'package:couchdb_sqlite_sync/replication_protocol/synchronizer.dart';
import 'package:couchdb_sqlite_sync/repository/repository.dart';
import 'package:couchdb_sqlite_sync/repository/sort_order.dart';

class HomePageManager {
  final _controller = StreamController<List<Order>>.broadcast();
  get stream => _controller.stream;

  bool isSql;
  bool isSync;
  static String dbName = 'adish';
  static String type = 'order';

  static PouchDB remoteDB = new PouchDB(isLocal: false, dbName: dbName);
  static PouchDB localDB = new PouchDB(isLocal: true, dbName: dbName);
  Repository orderRepo = Repository(dbName: dbName, type: type);

  SortOrder sortOrder;

  Sychronizer sychronizer =
      new Sychronizer(remoteDB: remoteDB, localDB: localDB);

  dispose() {
    _controller.close();
  }

  HomePageManager({this.isSql, this.isSync, this.sortOrder}) {
    sychronizer.init(callback: () {
      updateStream();
    });
    updateStream();
  }

  void setIsSql({bool isSql}) {
    this.isSql = isSql;
    updateStream();
  }

  void updateSync({bool isSync}) {
    this.isSync = isSync;
    if (this.isSync) {
      sychronizer.init(callback: () {
        updateStream();
      });
    } else {
      sychronizer.cancel();
    }
  }

  void changeOrder({SortOrder sortOrder}) {
    this.sortOrder = sortOrder;

    updateStream();
  }

  void updateStream() async {
    List<Doc> docs = isSql
        ? await localDB.getAllDocs(
            query: orderRepo.getQuery(isSql), order: sortOrder)
        : await remoteDB.getAllDocs(
            query: orderRepo.getQuery(isSql), order: sortOrder);

    List<Order> orders =
        docs.isNotEmpty ? docs.map((item) => Order.fromDoc(item)).toList() : [];

    _controller.sink.add(orders);
  }

  Future<void> deleteDoc({Order order}) async {
    isSql
        ? await localDB.deleteDoc(doc: order.toDoc())
        : await remoteDB.deleteDoc(doc: order.toDoc());

    updateStream();
  }

  Future<void> insertDoc({Order order}) async {
    order.id = orderRepo.generateNewId();
    isSql
        ? await localDB.insertDoc(doc: order.toDoc())
        : await remoteDB.insertDoc(doc: order.toDoc());
    updateStream();
  }

  Future<void> updateDoc({Order order}) async {
    isSql
        ? await localDB.updateDoc(doc: order.toDoc())
        : await remoteDB.updateDoc(doc: order.toDoc());

    updateStream();
  }
}
