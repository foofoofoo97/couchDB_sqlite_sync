import 'package:couchdb_sqlite_sync/dish.dart';
import 'package:couchdb_sqlite_sync/dish_dao.dart';

class DishRepository {
  final dishDao = DishDao();
  Future getAllSubject({String query}) => dishDao.getSubject(query: query);
  Future insertSubject(Dish dish) => dishDao.createSubject(dish);
  Future updateSubject(Dish dish) => dishDao.updateSubject(dish);
  Future deleteSubjectById(int id) => dishDao.deleteSubject(id);
  Future deleteAllSubject() => dishDao.deleteAllSubject();
  Future createdID() => dishDao.createdID();
  Future isExistingData(int id) => dishDao.isExistingData(id);
}
