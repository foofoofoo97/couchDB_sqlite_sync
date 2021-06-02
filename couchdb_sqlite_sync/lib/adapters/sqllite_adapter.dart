import 'dart:convert';
import 'package:couchdb_sqlite_sync/adapters/adapter_abstract_class.dart';
import 'package:couchdb_sqlite_sync/adapters/http_adapter.dart';
import 'package:couchdb_sqlite_sync/model_class/dish.dart';
import 'package:couchdb_sqlite_sync/dish_service/dish_repository.dart';
import 'package:couchdb_sqlite_sync/sequence_service/sqlite_sequence_manager.dart';

class SqliteAdapter extends Adapter {
  final _dishRepository = DishRepository();
  final SqliteSequenceManager sqliteSequenceManager =
      new SqliteSequenceManager();
  // final _dishController = StreamController<List<Dish>>.broadcast();
  //get subjectList => _dishController.stream;

  // SqliteAdapter() {
  //   getDish();
  // }

  @override
  getAllDish() async {
    List<Dish> dishes = await _dishRepository.getAllSubject();
    return dishes;
  }

  @override
  getSelectedDish(int id) async {
    Dish dish = await _dishRepository.getSeletedDish(id);
    return dish;
  }

  @override
  insertDish(Dish dish) async {
    await _dishRepository.insertSubject(dish);
    //getDish();
  }

  @override
  updateDish(Dish dish) async {
    await _dishRepository.updateSubject(dish);
    //getDish();
  }

  @override
  deleteDish(Dish dish) async {
    await _dishRepository.deleteSubjectById(dish.id);
    print('deleted');
    //getDish();
  }

  // getDish({String query}) async {
  //   List<Dish> dishes = await _dishRepository.getAllSubject(query: query);
  //   print(dishes.length > 0 ? dishes[0].toDatabaseJson() : null);
  //   _dishController.sink.add(await _dishRepository.getAllSubject(query: query));
  // }

  createdID() async {
    return await _dishRepository.createdID();
  }

  isExistingID(int id) async {
    return await _dishRepository.isExistingData(id);
  }

  getBulkDocs(Map<String, Map<String, List<String>>> revsDiff) async {
    List<Object> bulkDocs = new List();
    for (String key in revsDiff.keys) {
      Dish dish = await getSelectedDish(int.parse(key));
      //check whether it is deleted
      if (dish == null) {
        dish = new Dish(id: int.parse(key), rev: revsDiff[key]['missing'][0]);
        HttpAdapter httpAdapter = new HttpAdapter();
        await httpAdapter.deleteDish(dish);

        // List<SequenceLog> sequences =
        //     await sqliteSequenceManager.getSequenceById(key);
        // List revisions = new List();
        // int n = 0;
        // for (SequenceLog sequenceLog in sequences) {
        //   if (n == 0) {
        //     dish.data = sequenceLog.data;
        //   }
        //   revisions.add(sequenceLog.rev.split('-')[1]);
        // }

        // bulkDocs.add({
        //   "_id": dish.id.toString(),
        //   "_rev": dish.rev,
        //   "_deleted": true,
        //   "_revisions": {
        //     "ids": revisions,
        //     "start": int.parse(dish.rev.split('-')[0])
        //   },
        //   "data": dish.data,
        // });
      } else {
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
    print(bulkDocs);
    return bulkDocs;
  }

  // dispose() {
  //   _dishController.close();
  // }
}
