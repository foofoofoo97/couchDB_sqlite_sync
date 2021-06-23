import 'dart:async';
import 'package:couchdb_sqlite_sync/model_class/doc.dart';
import 'package:couchdb_sqlite_sync/model_class/order.dart';
import 'package:couchdb_sqlite_sync/pouchdb.dart';
import 'package:couchdb_sqlite_sync/replication_protocol/synchronizer.dart';
import 'package:couchdb_sqlite_sync/repository/repository.dart';

class HomePageManager {
  final _controller = StreamController<List<Order>>.broadcast();
  get stream => _controller.stream;

  bool isSql;
  bool isSync;
  static String dbName = 'adish';
  static String type = 'order';

  PouchDB remoteDB = new PouchDB(isLocal: false, dbName: dbName);
  PouchDB localDB = new PouchDB(isLocal: true, dbName: dbName);
  Repository order = Repository(dbName: dbName, type: type);

  Sychronizer sychronizer = new Sychronizer();

  dispose() {
    _controller.close();
  }

  HomePageManager({this.isSql, this.isSync}) {
    sychronizer.init(
        remoteDb: remoteDB,
        localDb: localDB,
        callback: () {
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
      sychronizer.init(
          remoteDb: remoteDB,
          localDb: localDB,
          callback: () {
            updateStream();
          });

      //updateStream();
    } else {
      sychronizer.cancel();
    }
  }

  void updateStream() async {
    List<Doc> docs =
        isSql ? await localDB.getAllDocs() : await remoteDB.getAllDocs();

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
