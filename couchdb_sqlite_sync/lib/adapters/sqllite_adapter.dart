import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:couchdb_sqlite_sync/adapters/adapter_abstract_class.dart';
import 'package:couchdb_sqlite_sync/database_service/database_repository.dart';
import 'package:couchdb_sqlite_sync/model_class/doc.dart';
import 'package:couchdb_sqlite_sync/model_class/sequence_log.dart';
import 'package:couchdb_sqlite_sync/sequence_service/sequence_repository.dart';

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
  insertDocs(List<Doc> docs) async {
    List<SequenceLog> sequenceLogs = new List();
    for (Doc doc in docs) {
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

      sequenceLogs.add(sequneceLog);
    }
    print('insert-ing');
    print(sequenceLogs.length);

    await _tableRepository.insertDocs(docs: docs);
    await _sequenceRepository.addSequences(sequenceLogs);

    updateStream();
  }

  @override
  updateDocs(List<Doc> docs) async {
    await _tableRepository.updateDocs(docs: docs);

    updateStream();
  }

  @override
  deleteDocs(List<Doc> docs) async {
    List<String> ids = new List();
    List<SequenceLog> sequenceLogs = new List();

    for (Doc doc in docs) {
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
      sequenceLogs.add(sequenceLog);
      ids.add(doc.id);
    }

    await _tableRepository.deleteDocs(docs: ids);
    await _sequenceRepository.addSequences(sequenceLogs);

    updateStream();
  }

  @override
  replicateDatabase(List<Object> bulkDocs, List<String> deletedDocs) async {
    await insertBulkDocs(bulkDocs);
    await _tableRepository.deleteDocs(docs: deletedDocs);
  }

  @override
  insertBulkDocs(List<Object> bulkDocs) async {
    List<Doc> insertBulkDocs = bulkDocs[0];
    List<Doc> updateBulkDocs = bulkDocs[1];
    List<SequenceLog> sequenceLogs = new List();

    if (insertBulkDocs.length > 0) {
      await _tableRepository.insertDocs(docs: insertBulkDocs);
      for (Doc doc in insertBulkDocs) {
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

        sequenceLogs.add(sequneceLog);
      }
    }
    if (updateBulkDocs.length > 0) {
      await _tableRepository.updateDocs(docs: updateBulkDocs);
      for (Doc doc in insertBulkDocs) {
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

        sequenceLogs.add(sequneceLog);
      }
    }
    if (sequenceLogs.length > 0) _sequenceRepository.addSequences(sequenceLogs);
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

  @override
  updateDoc(Doc doc) async {
    //update rev
    String head = doc.rev.split('-')[0];
    String code = generateRandomString(33);
    int version = int.parse(head);
    version = version + 1;
    doc.rev = version.toString() + '-' + code;

    //update revisions
    print(doc.revisions);
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

  // isExistingID(String id) async {
  //   return await _tableRepository.isExistingDoc(id: id);
  // }

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
    Map<String, dynamic> updateRevs = new Map();
    Map<String, dynamic> insertRevs = new Map();
    Map<String, dynamic> deletedRevs = new Map();
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
      Doc doc = await getSelectedDoc(key);
      if (doc != null) {
        bulkDocs.add({
          "_id": doc.id.toString(),
          "_rev": doc.rev,
          "_revisions": {
            "ids": jsonDecode(doc.revisions)['_revisions'],
            "start": int.parse(doc.rev.split('-')[0])
          },
          "data": doc.data,
        });
      }
    }
    return bulkDocs;
  }
}
