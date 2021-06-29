import 'package:couchdb_sqlite_sync/model_class/doc.dart';

abstract class Adapter {
  getSelectedDoc(String id);
  getAllDocs({String query, String order});
  deleteDoc(Doc doc);
  updateDoc(Doc doc);
  insertDoc(Doc doc);
  getUpdateSeq();
  getChangesSince(String lastSeq);
  getBulkDocs(Map diff);
  getRevsDiff(Map revs);
  // createdID();
  replicateDatabase(List<Object> bulkDocs, List<String> deletedDocs);
  insertBulkDocs(List<Object> bulkDocs);
  insertDocs(List<Doc> docs);
  updateDocs(List<Doc> docs);
  deleteDocs(List<Doc> docs);
}
