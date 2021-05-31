import 'dart:async';

import 'package:couchdb_sqlite_sync/adapters/adapter_abstract_class.dart';
import 'package:couchdb_sqlite_sync/model_class/dish.dart';
import 'package:couchdb_sqlite_sync/dish_service/dish_repository.dart';

class SqliteAdapter extends Adapter {
  final _dishRepository = DishRepository();
  final _dishController = StreamController<List<Dish>>.broadcast();
  get subjectList => _dishController.stream;

  SqliteAdapter() {
    getDish();
  }

  @override
  getAllDish() async {
    List<Dish> dishes = await _dishRepository.getAllSubject();
    return dishes;
  }

  @override
  getSelectedDish(int id) async {
    Dish dish = await _dishRepository.getSeletedDish(id);
    return dish.data;
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

  getDish({String query}) async {
    List<Dish> dishes = await _dishRepository.getAllSubject(query: query);
    print(dishes.length > 0 ? dishes[0].toDatabaseJson() : null);
    _dishController.sink.add(await _dishRepository.getAllSubject(query: query));
  }

  createdID() async {
    return await _dishRepository.createdID();
  }

  isExistingID(int id) async {
    return await _dishRepository.isExistingData(id);
  }

  dispose() {
    _dishController.close();
  }
}
