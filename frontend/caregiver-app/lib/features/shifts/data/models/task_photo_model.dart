class TaskPhotoModel {
  TaskPhotoModel.fromJson(Map<String, dynamic> json)
      : _json = Map.unmodifiable(json);
  final Map<String, dynamic> _json;
  String? get url => _json['url']?.toString();
  Map<String, dynamic> toJson() => Map.of(_json);
}
