import 'package:couchdb_sqlite_sync/model_class/doc.dart';
import 'package:couchdb_sqlite_sync/database_service/database_dao.dart';

class DatabaseRepository {
  DatabaseDao databaseDao;
  DatabaseRepository({String dbName}) {
    databaseDao = new DatabaseDao(dbName: dbName);
  }

  Future getAllDocs({String query, String order}) =>
      databaseDao.getAllDocs(query: query, order: order);
  Future insertDoc({Doc doc}) => databaseDao.createDoc(doc: doc);
  Future updateDoc({Doc doc}) => databaseDao.updateDoc(doc: doc);
  Future deleteDoc({String id}) => databaseDao.deleteDoc(id: id);
  Future deleteAllDocs() => databaseDao.deleteAllDocs();
  Future getSelectedDoc({String id}) => databaseDao.getDoc(id: id);
  // Future createdID() => databaseDao.createdID();
  Future insertDocs({List<Doc> docs}) => databaseDao.insertDocs(docs: docs);
  Future deleteDocs({List<String> docs}) => databaseDao.deleteDocs(docs: docs);
  Future updateDocs({List<Doc> docs}) => databaseDao.updateDocs(docs: docs);
  // Future isExistingDoc({String id}) => databaseDao.isExistingDoc(id: id);
}
