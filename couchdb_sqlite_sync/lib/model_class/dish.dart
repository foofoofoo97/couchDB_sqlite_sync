class Dish {
  int id;
  String data;
  String rev;
  String revisions;

  Dish({this.id, this.data, this.rev, this.revisions});
  factory Dish.fromDatabaseJson(Map<String, dynamic> data) => Dish(
      id: data['id'],
      data: data['data'],
      rev: data['rev'],
      revisions: data['revisions']);

  Map<String, dynamic> toDatabaseJson() => {
        "id": this.id,
        "data": this.data,
        "rev": this.rev,
        'revisions': this.revisions
      };
}
