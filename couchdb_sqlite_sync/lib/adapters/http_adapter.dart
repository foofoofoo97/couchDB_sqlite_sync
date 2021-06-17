import 'dart:async';
import 'dart:convert';
import 'package:couchdb_sqlite_sync/adapters/adapter_abstract_class.dart';
import 'package:couchdb_sqlite_sync/model_class/dish.dart';
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

  final String dbName = 'a-dish';
  final dbs = Databases(client);
  final docs = Documents(client);

  final _dishController = StreamController<List<Dish>>.broadcast();
  get dishStream => _dishController.stream;
  StreamSubscription subscription;

  HttpAdapter() {
    getDish();
    changesSubscription(subscription);
  }

  getDish() async {
    _dishController.sink.add(await getAllDish());
  }

  dispose() {
    subscription.cancel();
    _dishController.close();
  }

  get stream => _dishController.stream;

  //BY DATABASE
  //CHANGES IN
  changesIn() async {
    return await dbs.changesIn(dbName,
        feed: 'longpoll', includeDocs: true, heartbeat: 1000, since: 'now');
  }

  changesSubscription(StreamSubscription subscription) {
    subscription = changesIn().asStream().listen((event) {
      event.listen((databasesResponse) {
        getDish();
      });
    }, onDone: () {
      print("Task Done");
      subscription.cancel();
      changesSubscription(subscription);
    }, onError: (error) {
      print("Some Error");
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
        for (String conflict in documentsResponse.conflicts) {
          int index = int.parse(conflict.split('-')[0]);
          String tail = conflict.split('-')[1];
          //check if inserted bulkdocs has index
          //otherwise conflict is kept
          if (doc['_revisions']['ids'].length > index) {
            //conflicted revision is not a revision to be kept
            if (tail != doc['_revisions']['ids'][index]) {
              await docs.deleteDoc(dbName, doc['_id'], conflict);
            }
            //conflicted revision is wanted revision
            else {
              //delete wrong revision from winner revisions
              //first check its existence
              if (documentsResponse.revisions.length > index) {
                List winnerRevisions = documentsResponse.revisions['ids'];
                await docs.deleteDoc(
                    dbName, doc['_id'], '$index-${winnerRevisions[index]}');
              }
            }
          }
        }
      }
    }

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

  doc(String dbName, String docId) async {
    return await docs.doc(dbName, docId);
  }

  //POST/ insert BULKDOCS
  insertBulkDocs(List<Object> bulkDocs) async {
    await dbs.insertBulkDocs(dbName, bulkDocs, newEdits: false);
  }

  //Get documents with revsdifference
  revsDifferentWithCouchDb(Map<String, List<String>> revs) async {
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

  changesSince(String couchDbLastSeq) async {
    var streamRes = await Dio().get<ResponseBody>(
        'https://sync-dev.feedmeapi.com/a-dish/_changes?descending=false&feed=normal&heartbeat=10000&since=$couchDbLastSeq&style=all_docs&descending=true',
        options: Options(responseType: ResponseType.stream));

    return streamRes.data.stream;
  }

  //GET ALL DOCS
  @override
  getAllDish() async {
    DatabasesResponse databasesResponse =
        await dbs.allDocs(dbName, includeDocs: true);

    List<Dish> dishes = new List();
    for (Map value in databasesResponse.rows) {
      Dish dish = new Dish();

      dish.id = int.parse(value['doc']['_id']);
      dish.data = value['doc']['data'];
      dish.rev = value['doc']['_rev'];
      dishes.add(dish);
    }

    return dishes;
  }

  //POST (BULKDOCS)
  bulkDocs(List<Object> docs, {bool revs}) async {
    return await dbs.bulkDocs(dbName, docs, revs: revs);
  }

  //DB INFO
  dbInfo(String dbName) async {
    return await dbs.dbInfo(dbName);
  }

  //--------------------------------------------------------

  //BY DOCUMENT
  //PUT (INSERT)
  @override
  insertDish(Dish dish) async {
    try {
      await docs.insertDoc(
          'a-dish',
          dish.id.toString(),
          {
            'data': dish.data,
            '_revisions': {
              "ids": [dish.rev.split('-')[1].toString()],
              "start": 0
            }
          },
          rev: dish.rev,
          newEdits: false);
    } catch (e) {
      print('$e - error');
    }
  }

  //PUT (UPDATE)
  @override
  updateDish(Dish dish) async {
    try {
      await docs.insertDoc(
        'a-dish',
        dish.id.toString(),
        {
          'data': dish.data,
          '_revisions': {
            "ids": [
              dish.rev.split('-')[1].toString(),
              dish.rev.split('-')[1].toString()
            ],
            "start": int.parse(dish.rev.split('-')[0])
          }
        },
        rev: dish.rev,
        newEdits: false,
      );
    } on CouchDbException catch (e) {
      print('$e - error');
    }
  }

  //GET SPECIFIC DOC
  @override
  getSelectedDish(int docId) async {
    DocumentsResponse documentsResponse = await docs.doc(
      dbName,
      docId.toString(),
    );
    Dish dish = new Dish(
        id: int.parse(documentsResponse.id),
        data: documentsResponse.doc['data'],
        rev: documentsResponse.rev,
        revisions: jsonEncode(documentsResponse.revisions));

    return dish;
  }

  //DELETE DOC
  @override
  deleteDish(Dish dish) async {
    try {
      await docs.deleteDoc(dbName, dish.id.toString(), dish.rev);
    } on CouchDbException catch (e) {
      print('$e - error');
    }
  }

  insertReplicationLog(
      {String id, String rev, Map<String, Object> body}) async {
    try {
      await docs.insertDoc(dbName, id, body, rev: rev, newEdits: false);
    } catch (e) {
      print('$e - error');
    }
  }

  getBulkDocs(Map missingRevs) async {
    List<Dish> dishes = new List();
    for (String id in missingRevs.keys) {
      DocumentsResponse documentsResponse =
          await docs.doc(dbName, id, revs: true, latest: true);

      Dish dish = new Dish();
      dish.data = documentsResponse.doc['data'];
      dish.id = int.parse(id);
      dish.rev = documentsResponse.doc['_rev'];
      dish.revisions =
          jsonEncode({'_revisions': documentsResponse.revisions['ids']});
      dishes.add(dish);
    }

    return dishes;
  }

  createdID() async {
    List<Dish> dishes = new List();
    dishes = await getAllDish();
    int id = dishes.length == 0 ? 0 : dishes.last.id;
    return id;
  }
}
