class Dish {
  int id;
  String data;
  String rev;

  Dish({this.id, this.data, this.rev});
  factory Dish.fromDatabaseJson(Map<String, dynamic> data) =>
      Dish(id: data['id'], data: data['data'], rev: data['rev']);

  Map<String, dynamic> toDatabaseJson() =>
      {"id": this.id, "data": this.data, "rev": this.rev};
}
