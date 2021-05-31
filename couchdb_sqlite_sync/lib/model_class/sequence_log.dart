class SequenceLog {
  int seq;
  String id;
  String changes;
  String deleted;
  String data;
  String rev;

  SequenceLog(
      {this.id, this.data, this.rev, this.seq, this.changes, this.deleted});
  factory SequenceLog.fromDatabaseJson(Map<String, dynamic> data) =>
      SequenceLog(
          seq: data['seq'],
          id: data['id'],
          changes: data['changes'],
          data: data['data'] ?? '',
          deleted: data['deleted'],
          rev: data['rev']);

  Map<String, dynamic> toDatabaseJson() => {
        "seq": this.seq,
        "id": this.id,
        "changes": this.changes,
        "data": this.data,
        "deleted": this.deleted,
        "rev": this.rev
      };
}
