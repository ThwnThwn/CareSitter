class PaymentProviderModel {
  const PaymentProviderModel(
      {required this.code,
      required this.name,
      required this.description,
      required this.enabled});
  final String code;
  final String name;
  final String description;
  final bool enabled;
  factory PaymentProviderModel.fromJson(Map<String, dynamic> json) =>
      PaymentProviderModel(
          code: json['code']?.toString() ?? '',
          name: json['name']?.toString() ?? '',
          description: json['description']?.toString() ?? '',
          enabled: json['enabled'] == true);
}
