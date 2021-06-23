import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:couchdb_sqlite_sync/adapters/adapter_abstract_class.dart';
import 'package:couchdb_sqlite_sync/model_class/doc.dart';
import 'package:couchdb/couchdb.dart';
import 'package:dio/dio.dart';

class HttpAdapter extends Adapter {
  //Connect
  static final client = CouchDbClient(
    username: 'admin',
    password: 'secret',
    scheme: 'https',
    host: 'sync-dev.feedmeapi.com',
    port: 443,
    cors: true,
  );

  String dbName;
  final dbs = Databases(client);
  final docs = Documents(client);

  final _tableController = StreamController<List<Doc>>.broadcast();
  StreamSubscription _subscription;

  get stream => _tableController.stream;

  HttpAdapter({this.dbName}) {
    updateStream();
    changesSubscription(_subscription);
  }

  updateStream() async {
    _tableController.sink.add(await getAllDocs());
  }

  dispose() {
    _tableController.close();
    _subscription.cancel();
  }

  String generateRandomString(int len) {
    var r = Random(DateTime.now().millisecond);
    const _chars = 'abcdefghijklmnopqrstuvwxyz1234567890';
    return List.generate(len, (index) => _chars[r.nextInt(_chars.length)])
        .join();
  }

  //BY DATABASE
  //CHANGES IN
  changesIn() async {
    return await dbs.changesIn(dbName,
        feed: 'longpoll', includeDocs: true, heartbeat: 1000, since: 'now');
  }

  changesSubscription(StreamSubscription subscription) {
    subscription = changesIn().asStream().listen((event) {
      event.listen((databasesResponse) {
        updateStream();
      });
    }, onDone: () {
      subscription.cancel();
      changesSubscription(subscription);
    }, onError: (error) {
      print(error);
    });
  }

  resolveConflicts(List<Object> bulkDocs, List<String> deletedDocs) async {
    for (Map doc in bulkDocs) {
      DocumentsResponse documentsResponse = await docs.doc(
        dbName,
        doc['_id'],
        conflicts: true,
        revs: true,
      );

      if (documentsResponse.conflicts != null &&
          documentsResponse.conflicts.length > 0) {
        if (doc['_revisions']['start'] >=
            documentsResponse.revisions['start']) {
          // if (doc['_rev'] != documentsResponse.rev) {
          //   await docs.deleteDoc(dbName, doc['_id'], documentsResponse.rev);
          // } else {
          //   for (String conflict in documentsResponse.conflicts) {
          //     await docs.deleteDoc(dbName, doc['_id'], conflict);
          //   }
          // }
          for (String conflict in documentsResponse.conflicts) {
            int index = int.parse(conflict.split('-')[0]);
            String tail = conflict.split('-')[1];
            if (doc['_revisions']['ids'].length > index) {
              if (tail != doc['_revisions']['ids'][index]) {
                await docs.deleteDoc(dbName, doc['_id'], conflict);
              } else {
                List winnerRevisions = documentsResponse.revisions['ids'];
                if (winnerRevisions.length > index) {
                  await docs.deleteDoc(dbName, doc['_id'],
                      '$index-${winnerRevisions[winnerRevisions.length - 1 - index]}');
                }
              }
            }
          }
        } else {
          await docs.deleteDoc(dbName, doc['_id'], doc['_rev']);
        }
      }
    }
    //do i need to put condition like completely new revision, then should i follow couchdb??
    for (String id in deletedDocs) {
      try {
        DocumentsResponse documentsResponse = await docs.doc(
          dbName,
          id,
          conflicts: true,
          revs: true,
        );

        await docs.deleteDoc(dbName, id, documentsResponse.rev);
      } catch (e) {
        print(e);
      }
    }
  }

  doc(String docId) async {
    return await docs.doc(dbName, docId);
  }

  @override
  insertBulkDocs(List<Object> bulkDocs, List<String> deletedDocs) async {
    await dbs.insertBulkDocs(dbName, bulkDocs, newEdits: false);
    await resolveConflicts(bulkDocs, deletedDocs);
    await ensureFullCommit();
  }

  @override
  getRevsDiff(Map revs) async {
    ApiResponse result = await client.post('$dbName/_revs_diff', body: revs);
    Map<String, Map<String, List<String>>> revsDiff = result.json.keys
            .every(RegExp('[a-z0-9-]{1,36}').hasMatch)
        ? result.json?.map((k, v) =>
            MapEntry<String, Map<String, List<String>>>(
                k.toString(),
                (v as Map<String, Object>)?.map((k, v) =>
                    MapEntry<String, List<String>>(
                        k,
                        (v as List<Object>)
                            ?.map((e) => e as String)
                            ?.toList()))))
        : null;

    return revsDiff;
  }

  ensureFullCommit() async {
    await dbs.ensureFullCommit(dbName);
  }

  @override
  getChangesSince(String lastSeq) async {
    var streamRes = await Dio().get(
        'https://sync-dev.feedmeapi.com/$dbName/_changes?descending=false&feed=normal&heartbeat=10000&since=$lastSeq&style=all_docs&descending=true');

    return streamRes.data['results'];
  }

  //GET ALL DOCS
  @override
  getAllDocs() async {
    DatabasesResponse databasesResponse =
        await dbs.allDocs(dbName, includeDocs: true);

    List<Doc> dishes = new List();
    for (Map value in databasesResponse.rows) {
      Doc dish = new Doc();

      dish.id = int.parse(value['doc']['_id']);
      dish.data = value['doc']['data'];
      dish.rev = value['doc']['_rev'];
      dishes.add(dish);
    }

    return dishes;
  }

  // //POST (BULKDOCS)
  // bulkDocs(List<Object> docs, {bool revs}) async {
  //   return await dbs.bulkDocs(dbName, docs, revs: revs);
  // }

  //DB INFO
  dbInfo() async {
    return await dbs.dbInfo(dbName);
  }

  @override
  getUpdateSeq() async {
    DatabasesResponse databasesResponse = await dbInfo();
    return databasesResponse.updateSeq;
  }

  @override
  insertDoc(Doc doc) async {
    try {
      doc.id = await createdID() + 1;
      doc.rev = "0-${generateRandomString(33)}";
      doc.revisions = jsonEncode({
        "_revisions": [doc.rev.split('-')[1]]
      });

      await docs.insertDoc(
          dbName,
          doc.id.toString(),
          {
            'data': doc.data,
            '_revisions': {
              "ids": [doc.rev.split('-')[1].toString()],
              "start": 0
            }
          },
          rev: doc.rev,
          newEdits: false);
    } catch (e) {
      print('$e - error');
    }
  }

  @override
  updateDoc(Doc doc) async {
    try {
      //update rev
      String oldRev = doc.rev;
      String head = doc.rev.split('-')[0];
      String code = generateRandomString(33);
      int version = int.parse(head);
      version = version + 1;
      doc.rev = version.toString() + '-' + code;

      await docs.insertDoc(
        dbName,
        doc.id.toString(),
        {
          'data': doc.data,
          '_revisions': {
            "ids": [
              doc.rev.split('-')[1].toString(),
              oldRev.split('-')[1].toString()
            ],
            "start": int.parse(doc.rev.split('-')[0])
          }
        },
        rev: doc.rev,
        newEdits: false,
      );
    } on CouchDbException catch (e) {
      print('$e - error');
    }
  }

  //GET SPECIFIC DOC
  @override
  getSelectedDoc(String id) async {
    DocumentsResponse documentsResponse = await docs.doc(
      dbName,
      id,
    );
    Doc dish = new Doc(
        id: int.parse(documentsResponse.id),
        data: documentsResponse.doc['data'],
        rev: documentsResponse.rev,
        revisions: jsonEncode(documentsResponse.revisions));

    return dish;
  }

  //DELETE DOC
  @override
  deleteDoc(Doc doc) async {
    try {
      await docs.deleteDoc(dbName, doc.id.toString(), doc.rev);
    } on CouchDbException catch (e) {
      print('$e - error');
    }
  }

  insertLog({String id, String rev, Map<String, Object> body}) async {
    try {
      await docs.insertDoc(dbName, id, body, rev: rev, newEdits: false);
    } on CouchDbException catch (e) {
      print('$e - error');
    }
  }

  getLog(String id) async {
    try {
      DocumentsResponse documentsResponse = await docs.doc(dbName, id);
      return documentsResponse;
    } on CouchDbException catch (e) {
      print('$e - error');
    }
  }

  @override
  getBulkDocs(Map revsDiff) async {
    try {
      List<Doc> dishes = new List();
      for (String id in revsDiff.keys) {
        DocumentsResponse documentsResponse =
            await docs.doc(dbName, id, revs: true, latest: true);

        Doc dish = new Doc();
        dish.data = documentsResponse.doc['data'];
        dish.id = int.parse(id);
        dish.rev = documentsResponse.doc['_rev'];
        dish.revisions =
            jsonEncode({'_revisions': documentsResponse.revisions['ids']});
        dishes.add(dish);
      }

      return dishes;
    } on CouchDbException catch (e) {
      print('$e - error');
    }
  }

  @override
  createdID() async {
    List<Doc> dishes = new List();
    dishes = await getAllDocs();
    int id = dishes.length == 0 ? 0 : dishes.last.id;
    return id;
  }
}
