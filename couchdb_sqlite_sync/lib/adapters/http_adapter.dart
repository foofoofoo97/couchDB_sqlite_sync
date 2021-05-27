import 'dart:async';
import 'dart:convert';
import 'package:couchdb_sqlite_sync/adapter_abstract_class.dart';
import 'package:couchdb_sqlite_sync/dish.dart';
import 'package:couchdb/couchdb.dart';
import 'package:couchdb_sqlite_sync/todo_bloc.dart';

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
  DishBloc dishBloc;

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

  //POST (INSERT BULKDOCS)
  insertBulkDocs(List<Object> docs,
      {bool newEdits = true, Map<String, String> headers}) async {
    return await dbs.insertBulkDocs(dbName, docs,
        newEdits: newEdits, headers: headers);
  }

  //DB INFO
  dbInfo(String dbName) async {
    return await dbs.dbInfo(dbName);
  }

  //-----------------------------------------------------------------------------------------------------------------
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

      getDish();
    } on CouchDbException catch (e) {
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

      getDish();
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
    return documentsResponse.doc['data'];
  }

  //DELETE DOC
  @override
  deleteDish(Dish dish) async {
    try {
      await docs.deleteDoc(dbName, dish.id.toString(), dish.rev);
      getDish();
    } on CouchDbException catch (e) {
      print('$e - error');
    }
  }
}
