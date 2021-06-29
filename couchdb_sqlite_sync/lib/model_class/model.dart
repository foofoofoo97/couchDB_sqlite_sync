import 'package:couchdb_sqlite_sync/model_class/doc.dart';

abstract class Model {
  fromDoc(Doc doc);
  Doc toDoc();
}
