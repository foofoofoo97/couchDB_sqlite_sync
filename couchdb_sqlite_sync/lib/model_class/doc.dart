class Doc {
  int id;
  String data;
  String rev;
  String revisions;

  Doc({this.id, this.data, this.rev, this.revisions});

  factory Doc.fromDatabaseJson(Map<String, dynamic> data) => Doc(
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
