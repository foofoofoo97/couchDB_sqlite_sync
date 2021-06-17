import 'package:couchdb_sqlite_sync/model_class/dish.dart';

class Repository {
  static const Map<String, Type> repository = {'a-dish': Dish, 'b-dish': Dish};
}
