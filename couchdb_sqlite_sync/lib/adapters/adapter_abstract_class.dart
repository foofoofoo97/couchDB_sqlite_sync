import 'package:couchdb_sqlite_sync/model_class/dish.dart';

abstract class Adapter {
  getSelectedDish(int id);
  getAllDish();
  deleteDish(Dish dish);
  updateDish(Dish dish);
  insertDish(Dish dish);
}
