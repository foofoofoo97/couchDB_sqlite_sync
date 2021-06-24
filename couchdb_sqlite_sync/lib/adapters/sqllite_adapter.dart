import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:couchdb_sqlite_sync/adapters/adapter_abstract_class.dart';
import 'package:couchdb_sqlite_sync/database_service/database_repository.dart';
import 'package:couchdb_sqlite_sync/model_class/doc.dart';
import 'package:couchdb_sqlite_sync/model_class/sequence_log.dart';
import 'package:couchdb_sqlite_sync/sequence_service/sqlite_sequence_manager.dart';

class SqliteAdapter extends Adapter {
  DatabaseRepository _tableRepository;
  SequenceRepository _sequenceRepository;

  final _tableController = StreamController<List<Doc>>.broadcast();

  SqliteAdapter({String dbName}) {
    _tableRepository = DatabaseRepository(dbName: dbName);
    _sequenceRepository = SequenceRepository(dbName: dbName);
  }

  get stream => _tableController.stream;

  dispose() {
    _tableController.close();
  }

  updateStream() async {
    _tableController.sink.add(await getAllDocs());
  }

  String generateRandomString(int len) {
    var r = Random(DateTime.now().millisecond);
    const _chars = 'abcdefghijklmnopqrstuvwxyz1234567890';
    return List.generate(len, (index) => _chars[r.nextInt(_chars.length)])
        .join();
  }

  @override
  getAllDocs({String query, String order}) async {
    List<Doc> docs =
        await _tableRepository.getAllDocs(query: query, order: order);
    return docs;
  }

  @override
  getSelectedDoc(String id) async {
    Doc doc = await _tableRepository.getSelectedDoc(id: id);
    return doc;
  }

  @override
  insertBulkDocs(List<Object> bulkDocs, List<String> deletedDocs) {}

  insertSourceDoc(Doc doc) async {
    SequenceLog sequneceLog = new SequenceLog(
        rev: doc.rev,
        data: doc.data,
        deleted: 'false',
        changes: jsonEncode({
          "changes": [
            {"rev": doc.rev}
          ]
        }),
        id: doc.id.toString());

    await _tableRepository.insertDoc(doc: doc);
    await _sequenceRepository.addSequence(sequneceLog);

    updateStream();
  }

  @override
  insertDoc(Doc doc) async {
    //doc.id = await createdID() + 1;
    doc.rev = "0-${generateRandomString(33)}";
    doc.revisions = jsonEncode({
      "_revisions": [doc.rev.split('-')[1]]
    });
    SequenceLog sequneceLog = new SequenceLog(
        rev: doc.rev,
        data: doc.data,
        deleted: 'false',
        changes: jsonEncode({
          "changes": [
            {"rev": doc.rev}
          ]
        }),
        id: doc.id.toString());

    await _tableRepository.insertDoc(doc: doc);
    await _sequenceRepository.addSequence(sequneceLog);

    updateStream();
  }

  updateSourceDoc(Doc doc) async {
    SequenceLog sequneceLog = new SequenceLog(
        rev: doc.rev,
        data: doc.data,
        deleted: 'false',
        changes: jsonEncode({
          "changes": [
            {"rev": doc.rev}
          ]
        }),
        id: doc.id.toString());

    //update sqlite dish
    await _tableRepository.updateDoc(doc: doc);
    await _sequenceRepository.addSequence(sequneceLog);
    updateStream();
  }

  @override
  updateDoc(Doc doc) async {
    //update rev
    String head = doc.rev.split('-')[0];
    String code = generateRandomString(33);
    int version = int.parse(head);
    version = version + 1;
    doc.rev = version.toString() + '-' + code;

    //update revisions
    Map revisions = jsonDecode(doc.revisions);
    revisions['_revisions'].insert(0, doc.rev.split('-')[1]);
    doc.revisions = jsonEncode(revisions);

    SequenceLog sequneceLog = new SequenceLog(
        rev: doc.rev,
        data: doc.data,
        deleted: 'false',
        changes: jsonEncode({
          "changes": [
            {"rev": doc.rev}
          ]
        }),
        id: doc.id.toString());

    //update sqlite dish
    await _tableRepository.updateDoc(doc: doc);
    await _sequenceRepository.addSequence(sequneceLog);

    updateStream();
  }

  @override
  deleteDoc(Doc doc) async {
    SequenceLog sequenceLog = new SequenceLog(
        rev: doc.rev,
        data: doc.data,
        deleted: 'true',
        changes: jsonEncode({
          "changes": [
            {"rev": doc.rev}
          ]
        }),
        id: doc.id.toString());

    await _tableRepository.deleteDoc(id: doc.id);
    await _sequenceRepository.addSequence(sequenceLog);

    updateStream();
  }

  // @override
  // createdID() async {
  //   return await _tableRepository.createdID();
  // }

  isExistingID(String id) async {
    return await _tableRepository.isExistingDoc(id: id);
  }

  @override
  getUpdateSeq() async {
    return (await _sequenceRepository.getUpdateSeq()).toString();
  }

  @override
  getChangesSince(String lastSeq) async {
    return await _sequenceRepository.getSequenceSince(int.parse(lastSeq));
  }

  @override
  getRevsDiff(Map revs) async {
    Map updateRevs = new Map();
    Map insertRevs = new Map();
    Map deletedRevs = new Map();
    for (String id in revs.keys) {
      Doc dish = await getSelectedDoc(id);
      List changedRevs = revs[id]['_revisions'];
      if (dish != null) {
        if (int.parse(changedRevs[0].split('-')[0]) >
            int.parse(dish.rev.split('-')[0])) {
          if (revs[id]['_deleted'] == true) {
            deletedRevs.putIfAbsent(id, () => revs[id]['_revisions'][0]);
          } else {
            List revisions = jsonDecode(dish.revisions)['_revisions'];
            for (String rev in changedRevs) {
              if (!revisions.contains(rev)) {
                updateRevs.putIfAbsent(id, () => []);
                updateRevs[id].add(rev);
              }
            }
          }
        }
      } else {
        if (revs[id]['_deleted'] == false) {
          insertRevs.putIfAbsent(id, () => []);
          insertRevs[id].addAll(revs[id]['_revisions']);
        }
      }
    }

    return {'update': updateRevs, 'insert': insertRevs, 'deleted': deletedRevs};
  }

  @override
  getBulkDocs(Map revsDiff) async {
    List<Object> bulkDocs = new List();
    for (String key in revsDiff.keys) {
      Doc dish = await getSelectedDoc(key);
      if (dish != null) {
        bulkDocs.add({
          "_id": dish.id.toString(),
          "_rev": dish.rev,
          "_revisions": {
            "ids": jsonDecode(dish.revisions)['_revisions'],
            "start": int.parse(dish.rev.split('-')[0])
          },
          "data": dish.data,
        });
      }
    }
    return bulkDocs;
  }
}
