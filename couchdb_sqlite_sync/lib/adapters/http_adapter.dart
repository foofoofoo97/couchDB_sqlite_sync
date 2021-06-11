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
  get subjectList => _dishController.stream;

  HttpAdapter() {
    getDish();
  }

  getDish() async {
    _dishController.sink.add(await getAllDish());
  }

  dispose() {
    _dishController.close();
  }

  //BY DATABASE
  //CHANGES IN
  changesIn() async {
    return await dbs.changesIn(dbName,
        feed: 'longpoll', includeDocs: true, heartbeat: 1000, since: 'now');
  }

  listenToEvent(DatabasesResponse databasesResponse) {
    Map data = jsonDecode(databasesResponse.result);
    return data['result'];
  }

  //POST/ insert BULKDOCS
  insertBulkDocs(List<Object> bulkDocs) async {
    DatabasesResponse databasesResponse =
        await dbs.insertBulkDocs(dbName, bulkDocs, newEdits: false);
    return databasesResponse;
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
      print('ya');
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

      //getDish();
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
    print(documentsResponse.revisions);
    return dish;
  }

  //DELETE DOC
  @override
  deleteDish(Dish dish) async {
    try {
      await docs.deleteDoc(dbName, dish.id.toString(), dish.rev);
      //getDish();
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
}
