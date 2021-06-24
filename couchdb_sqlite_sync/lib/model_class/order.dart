import 'dart:convert';

import 'package:couchdb_sqlite_sync/model_class/doc.dart';

class Order {
  String id;
  String name;
  int no;
  String rev;
  String revisions;

  Order({this.id, this.name, this.no, this.rev, this.revisions});

  factory Order.fromDoc(Doc doc) {
    Map data = jsonDecode(doc.data);
    return Order(
        id: doc.id,
        rev: doc.rev,
        revisions: doc.revisions,
        name: data['name'],
        no: data['no']);
  }

  Doc toDoc() {
    return Doc(
        id: id,
        rev: rev,
        revisions: revisions,
        data: jsonEncode({'name': name, 'no': no}));
  }
}
