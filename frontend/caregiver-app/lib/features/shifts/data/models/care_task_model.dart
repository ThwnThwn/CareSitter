class CareTaskModel {
  final String id;
  final String title;
  final String? description;
  final bool isRequired;
  final bool requiresPhoto;
  final int sortOrder;
  final String status; // PENDING | COMPLETED | SKIPPED
  final bool isCompleted;
  final List<String> photoUrls;

  /// PACKAGE | CAREGIVER_AD_HOC | SYSTEM
  final String source;
  final String? skipReason;
  final String? completedBy;
  final DateTime? createdAt;

  const CareTaskModel({
    required this.id,
    required this.title,
    this.description,
    this.isRequired = false,
    this.requiresPhoto = false,
    this.sortOrder = 0,
    this.status = 'PENDING',
    this.isCompleted = false,
    this.photoUrls = const [],
    this.source = 'PACKAGE',
    this.skipReason,
    this.completedBy,
    this.createdAt,
  });

  bool get isSkipped => status.toUpperCase() == 'SKIPPED';
  bool get isResolved => isCompleted || isSkipped;
  bool get isAdHoc => source == 'CAREGIVER_AD_HOC';

  /// Task đang ở trạng thái terminal (không thể tick/skip lại)
  bool get isTerminal => isCompleted || isSkipped;

  /// Evidence can only be attached while the task is still actionable.
  bool get canUploadEvidence => !isTerminal;

  /// Photo-required tasks cannot be completed before evidence exists.
  bool get canComplete =>
      !isTerminal && (!requiresPhoto || photoUrls.isNotEmpty);

  factory CareTaskModel.fromApi(Map<String, dynamic> json) {
    final status = json['status']?.toString().toUpperCase() ?? 'PENDING';
    return CareTaskModel(
      id: json['id']?.toString() ?? '',
      title: json['name']?.toString() ?? 'Nhiệm vụ chăm sóc',
      description: json['description']?.toString(),
      isRequired: json['isRequired'] as bool? ?? false,
      requiresPhoto: json['requiresPhoto'] as bool? ?? false,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      status: status,
      isCompleted: status == 'DONE' || status == 'COMPLETED',
      photoUrls: (json['photoUrls'] as List<dynamic>? ?? [])
          .map((value) => value.toString())
          .where((value) => value.isNotEmpty)
          .toList(growable: false),
      source: json['source']?.toString() ?? 'PACKAGE',
      skipReason: json['skipReason']?.toString(),
      completedBy: json['completedBy']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())?.toLocal()
          : null,
    );
  }

  CareTaskModel copyWith({
    String? status,
    bool? isCompleted,
    List<String>? photoUrls,
    String? skipReason,
  }) {
    final nextStatus = status ?? this.status;
    return CareTaskModel(
      id: id,
      title: title,
      description: description,
      isRequired: isRequired,
      requiresPhoto: requiresPhoto,
      sortOrder: sortOrder,
      status: nextStatus,
      isCompleted: isCompleted ??
          (nextStatus.toUpperCase() == 'DONE' ||
              nextStatus.toUpperCase() == 'COMPLETED'),
      photoUrls: photoUrls ?? this.photoUrls,
      source: source,
      skipReason: skipReason ?? this.skipReason,
      completedBy: completedBy,
      createdAt: createdAt,
    );
  }
}
