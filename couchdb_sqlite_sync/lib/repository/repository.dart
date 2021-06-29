import 'package:couchdb_sqlite_sync/model_class/doc.dart';
import 'package:couchdb_sqlite_sync/model_class/model.dart';
import 'package:couchdb_sqlite_sync/pouchdb.dart';
import 'package:couchdb_sqlite_sync/repository/sort_order.dart';

class Repository<T extends Model> {
  String dbName;
  String type;
  PouchDB pouchdb;
  SortOrder order;
  T t;

  Repository({this.pouchdb, this.dbName, this.type, this.t, this.order});

  String generateNewId({String id}) {
    return '${this.getIdPrefix()}${id ?? new DateTime.now().toIso8601String()}${this.getIdSuffix()}';
  }

  void changePouchDb(pouchdb) {
    this.pouchdb = pouchdb;
  }

  void changeOrder(order) {
    this.order = order;
  }

  Future<List<T>> getAllDocs() async {
    List<Doc> docs =
        await pouchdb.getAllDocs(query: getQuery(), order: getOrder());
    List<T> orders = docs.isNotEmpty
        ? docs.map<T>((item) {
            return this.t.fromDoc(item);
          }).toList()
        : [];

    return orders;
  }

  Future<void> deleteDoc(T t) async {
    await pouchdb.deleteDoc(doc: t.toDoc());
  }

  Future<void> insertDoc(T t) async {
    Doc doc = t.toDoc();
    doc.id = generateNewId();

    await pouchdb.insertDoc(doc: doc);
  }

  Future<void> updateDoc(T t) async {
    await pouchdb.updateDoc(doc: t.toDoc());
  }

  Future<void> updateDocs(List<T> tDocs) async {
    await pouchdb.updateDocs(docs: tDocs.map((t) => t.toDoc()).toList());
  }

  Future<void> insertDocs(List<T> tDocs) async {
    List<Doc> docs = tDocs.map((t) {
      Doc doc = t.toDoc();
      doc.id = generateNewId();
      return doc;
    }).toList();
    await pouchdb.insertDocs(docs: docs);
  }

  Future<void> deleteDocs(List<T> tDocs) async {
    await pouchdb.deleteDocs(docs: tDocs.map((t) => t.toDoc()).toList());
  }

  String getIdPrefix() {
    return type;
  }

  String getIdSuffix() {
    return '';
  }

  String getOrder() {
    return order == SortOrder.ASCENDING ? "asc" : "desc";
  }

  String getQuery() {
    return type;
  }
}
