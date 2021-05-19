import 'dart:async';
import 'dart:math';
import 'package:couchdb_sqlite_sync/dish.dart';
import 'package:couchdb_sqlite_sync/dish_publisher.dart';
import 'package:couchdb_sqlite_sync/dish_repository.dart';

class DishBloc {
  final _dishRepository = DishRepository();
  final _dishController = StreamController<List<Dish>>.broadcast();
  get subjectList => _dishController.stream;

  String generateRandomString(int len) {
    var r = Random.secure();
    const _chars = 'abcdefghijklmnopqrstuvwxyz1234567890';
    return List.generate(len, (index) => _chars[r.nextInt(_chars.length)])
        .join();
  }

  DishBloc() {
    getDish();
  }

  getDish({String query}) async {
    _dishController.sink.add(await _dishRepository.getAllSubject(query: query));
  }

  addSubject(Dish dish) async {
    dish.rev = "0-${generateRandomString(33)}";
    await _dishRepository.insertSubject(dish);
    dish.id = await _dishRepository.createdID();
    await DishPublisher.set(dish);
    getDish();
  }

  updateSubject(Dish dish) async {
    String head = dish.rev.split('-')[0];
    String code = dish.rev.split('-')[1];
    int version = int.parse(head);

    version = version + 1;
    dish.rev = version.toString() + '+' + code;

    await _dishRepository.updateSubject(dish);
    await DishPublisher.update(dish);
    getDish();
  }

  deleteSubjectById(int id) async {
    _dishRepository.deleteSubjectById(id);
    await DishPublisher.delete(id);
    getDish();
  }

  addSubjectSync(Dish dish) async {
    await _dishRepository.insertSubject(dish);
    dish.id = await _dishRepository.createdID();
    getDish();
  }

  updateSubjectSync(Dish dish) async {
    await _dishRepository.updateSubject(dish);
    getDish();
  }

  deleteSubjectByIdSync(int id) async {
    _dishRepository.deleteSubjectById(id);
    getDish();
  }

  isExistingID(int id) async {
    return _dishRepository.isExistingData(id);
  }

  dispose() {
    _dishController.close();
  }
}