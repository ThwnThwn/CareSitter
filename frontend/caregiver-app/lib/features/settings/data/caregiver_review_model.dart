class CaregiverReviewModel {
  final String id;
  final String reviewerName;
  final String reviewerInitial;
  final double rating;
  final String comment;
  final String date;
  final String shiftService;

  const CaregiverReviewModel({
    required this.id,
    required this.reviewerName,
    required this.reviewerInitial,
    required this.rating,
    required this.comment,
    required this.date,
    required this.shiftService,
  });

  factory CaregiverReviewModel.fromJson(Map<String, dynamic> json) {
    final name = json['reviewerName']?.toString() ??
        json['customerName']?.toString() ??
        'Khách hàng';
    final createdAt =
        DateTime.tryParse(json['createdAt']?.toString() ?? '')?.toLocal();
    return CaregiverReviewModel(
      id: json['id']?.toString() ?? '',
      reviewerName: name,
      reviewerInitial: _initials(name),
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      comment: json['comment']?.toString() ?? '',
      date: createdAt == null
          ? ''
          : '${createdAt.day}/${createdAt.month}/${createdAt.year}',
      shiftService: json['serviceName']?.toString() ?? 'Ca chăm sóc',
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return 'KH';
    final list = parts.toList();
    if (list.length == 1) {
      final first = list.first;
      return first
          .substring(0, first.length < 2 ? first.length : 2)
          .toUpperCase();
    }
    return '${list.first[0]}${list.last[0]}'.toUpperCase();
  }
}
