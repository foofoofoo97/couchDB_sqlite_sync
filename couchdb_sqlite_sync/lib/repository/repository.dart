class Repository {
  String dbName;
  String type;

  Repository({this.dbName, this.type});

  generateNewId(String id) {
    return '${this.getIdPrefix()}${id ?? new DateTime.now().toIso8601String()}${this.getIdSuffix()}';
  }

  String getIdPrefix() {
    return type;
  }

  String getIdSuffix() {
    return '';
  }

  String getQuery() {
    return '';
  }
}
