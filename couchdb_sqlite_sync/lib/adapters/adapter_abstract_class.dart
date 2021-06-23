import 'package:couchdb_sqlite_sync/model_class/doc.dart';

abstract class Adapter {
  getSelectedDoc(String id);
  getAllDocs();
  deleteDoc(Doc doc);
  updateDoc(Doc doc);
  insertDoc(Doc doc);
  getUpdateSeq();
  getChangesSince(String lastSeq);
  getBulkDocs(Map diff);
  getRevsDiff(Map revs);
  createdID();
  insertBulkDocs(List<Object> bulkDocs, List<String> deletedDocs);
}
