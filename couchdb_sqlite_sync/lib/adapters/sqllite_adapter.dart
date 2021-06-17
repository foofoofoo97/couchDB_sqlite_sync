import 'dart:async';
import 'dart:convert';
import 'package:couchdb_sqlite_sync/adapters/adapter_abstract_class.dart';
import 'package:couchdb_sqlite_sync/model_class/dish.dart';
import 'package:couchdb_sqlite_sync/dish_service/dish_repository.dart';
import 'package:couchdb_sqlite_sync/model_class/sequence_log.dart';
import 'package:couchdb_sqlite_sync/sequence_service/sqlite_sequence_manager.dart';

class SqliteAdapter extends Adapter {
  final _dishRepository = DishRepository();
  final SqliteSequenceManager sqliteSequenceManager =
      new SqliteSequenceManager();
  final _dishController = StreamController<List<Dish>>.broadcast();

  get dishStream => _dishController.stream;

  SqliteAdapter() {
    getDish();
  }

  dispose() {
    _dishController.close();
  }

  getDish() async {
    _dishController.sink.add(await getAllDish());
  }

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
    SequenceLog sequneceLog = new SequenceLog(
        rev: dish.rev,
        data: dish.data,
        deleted: 'false',
        changes: jsonEncode({
          "changes": [
            {"rev": dish.rev}
          ]
        }),
        id: dish.id.toString());

    await _dishRepository.insertSubject(dish);
    await sqliteSequenceManager.addSequence(sequneceLog);

    getDish();
  }

  @override
  updateDish(Dish dish) async {
    SequenceLog sequneceLog = new SequenceLog(
        rev: dish.rev,
        data: dish.data,
        deleted: 'false',
        changes: jsonEncode({
          "changes": [
            {"rev": dish.rev}
          ]
        }),
        id: dish.id.toString());

    //update sqlite dish
    await _dishRepository.updateSubject(dish);
    await sqliteSequenceManager.addSequence(sequneceLog);
    getDish();
  }

  @override
  deleteDish(Dish dish) async {
    SequenceLog sequenceLog = new SequenceLog(
        rev: dish.rev,
        data: dish.data,
        deleted: 'true',
        changes: jsonEncode({
          "changes": [
            {"rev": dish.rev}
          ]
        }),
        id: dish.id.toString());

    await _dishRepository.deleteSubjectById(dish.id);
    await sqliteSequenceManager.addSequence(sequenceLog);

    getDish();
  }

  createdID() async {
    return await _dishRepository.createdID();
  }

  isExistingID(int id) async {
    return await _dishRepository.isExistingData(id);
  }

  revsDifferentWithSqlite(Map<String, dynamic> revs) async {
    Map updateRevs = new Map();
    Map insertRevs = new Map();
    Map deletedRevs = new Map();
    for (String id in revs.keys) {
      Dish dish = await _dishRepository.getSeletedDish(int.parse(id));
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

  getBulkDocs(Map<String, Map<String, List<String>>> revsDiff) async {
    List<Object> bulkDocs = new List();
    for (String key in revsDiff.keys) {
      Dish dish = await getSelectedDish(int.parse(key));
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
