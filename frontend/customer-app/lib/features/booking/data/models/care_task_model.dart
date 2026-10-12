class CareTaskModel {
  final String id;
  final String title;
  final String? description;
  final bool isRequired;
  final bool requiresPhoto;
  final int sortOrder;
  final String status; // PENDING | COMPLETED | SKIPPED
  final List<String> photoUrls;

  /// PACKAGE | CAREGIVER_AD_HOC | SYSTEM
  final String source;
  final String? skipReason;
  final DateTime? completedAt;

  const CareTaskModel({
    required this.id,
    required this.title,
    this.description,
    this.isRequired = false,
    this.requiresPhoto = false,
    this.sortOrder = 0,
    this.status = 'PENDING',
    this.photoUrls = const [],
    this.source = 'PACKAGE',
    this.skipReason,
    this.completedAt,
  });

  bool get isCompleted =>
      status.toUpperCase() == 'DONE' || status.toUpperCase() == 'COMPLETED';
  bool get isSkipped => status.toUpperCase() == 'SKIPPED';
  bool get isAdHoc => source == 'CAREGIVER_AD_HOC';
  bool get isTerminal => isCompleted || isSkipped;

  factory CareTaskModel.fromApi(Map<String, dynamic> json) {
    final status = json['status']?.toString().toUpperCase() ?? 'PENDING';
    return CareTaskModel(
      id: json['id']?.toString() ?? '',
      title: json['name']?.toString() ?? 'Nhiệm vụ',
      description: json['description']?.toString(),
      isRequired: json['isRequired'] as bool? ?? false,
      requiresPhoto: json['requiresPhoto'] as bool? ?? false,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      status: status,
      photoUrls: (json['photoUrls'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList(growable: false),
      source: json['source']?.toString() ?? 'PACKAGE',
      skipReason: json['skipReason']?.toString(),
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'].toString())?.toLocal()
          : null,
    );
  }

  CareTaskModel copyWith({String? status, List<String>? photoUrls}) {
    final nextStatus = status ?? this.status;
    return CareTaskModel(
      id: id,
      title: title,
      description: description,
      isRequired: isRequired,
      requiresPhoto: requiresPhoto,
      sortOrder: sortOrder,
      status: nextStatus,
      photoUrls: photoUrls ?? this.photoUrls,
      source: source,
      skipReason: skipReason,
      completedAt: completedAt,
    );
  }
}
