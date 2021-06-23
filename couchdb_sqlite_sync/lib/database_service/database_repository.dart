import 'package:couchdb_sqlite_sync/model_class/doc.dart';
import 'package:couchdb_sqlite_sync/database_service/database_dao.dart';

class DatabaseRepository {
  DatabaseDao databaseDao;
  DatabaseRepository({String dbName}) {
    databaseDao = new DatabaseDao(dbName: dbName);
  }

  Future getAllDocs({String query}) => databaseDao.getAllDocs(query: query);
  Future insertDoc({Doc doc}) => databaseDao.createDoc(doc: doc);
  Future updateDoc({Doc doc}) => databaseDao.updateDoc(doc: doc);
  Future deleteDoc({int id}) => databaseDao.deleteDoc(id: id);
  Future deleteAllDocs() => databaseDao.deleteAllDocs();
  Future getSelectedDoc({int id}) => databaseDao.getDoc(id: id);
  Future createdID() => databaseDao.createdID();
  Future isExistingDoc({int id}) => databaseDao.isExistingDoc(id: id);
}
