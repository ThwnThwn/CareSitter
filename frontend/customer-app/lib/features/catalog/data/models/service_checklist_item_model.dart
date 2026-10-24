class ServiceChecklistItemModel {
  const ServiceChecklistItemModel({
    required this.id,
    required this.name,
    required this.description,
    required this.isRequired,
    required this.requiresPhoto,
    required this.sortOrder,
  });

  final String id;
  final String name;
  final String? description;
  final bool isRequired;
  final bool requiresPhoto;
  final int sortOrder;

  factory ServiceChecklistItemModel.fromJson(Map<String, dynamic> json) =>
      ServiceChecklistItemModel(
        id: (json['id'] ?? json['Id'])?.toString() ?? '',
        name: (json['name'] ?? json['Name'])?.toString() ?? '',
        description: (json['description'] ?? json['Description'])?.toString(),
        isRequired:
            (json['isRequired'] ?? json['IsRequired']) as bool? ?? false,
        requiresPhoto:
            (json['requiresPhoto'] ?? json['RequiresPhoto']) as bool? ?? false,
        sortOrder:
            ((json['sortOrder'] ?? json['SortOrder']) as num?)?.toInt() ?? 0,
      );
}
