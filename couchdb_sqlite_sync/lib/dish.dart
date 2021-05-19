import 'dart:math';

class Dish {
  int id;
  String name;
  int no;
  String rev;

  Dish({this.id, this.name, this.no, this.rev});
  factory Dish.fromDatabaseJson(Map<String, dynamic> data) => Dish(
      id: data['id'], name: data['name'], no: data['no'], rev: data['rev']);

  Map<String, dynamic> toDatabaseJson() =>
      {"id": this.id, "name": this.name, "no": this.no, "rev": this.rev};
}
