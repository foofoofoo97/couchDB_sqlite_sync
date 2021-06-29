import 'dart:convert';

import 'package:couchdb_sqlite_sync/model_class/doc.dart';
import 'package:couchdb_sqlite_sync/model_class/model.dart';

class Order extends Model {
  String id;
  String name;
  int no;
  String rev;
  String revisions;

  Order({this.id, this.name, this.no, this.rev, this.revisions});

  @override
  Order fromDoc(Doc doc) {
    Map data = jsonDecode(doc.data);
    return new Order(
        id: doc.id,
        rev: doc.rev,
        revisions: doc.revisions,
        name: data['name'],
        no: data['no']);
  }

  @override
  Doc toDoc() {
    return Doc(
        id: id,
        rev: rev,
        revisions: revisions,
        data: jsonEncode({'name': name, 'no': no}));
  }
}
