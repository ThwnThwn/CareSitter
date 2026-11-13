class NutritionRecipeImageModel {
  NutritionRecipeImageModel.fromJson(Map<String, dynamic> json)
      : url = json['url']?.toString() ?? '',
        dishName = json['dishName']?.toString() ?? '',
        sourceUrl = json['sourceUrl']?.toString() ?? '',
        attribution = json['attribution']?.toString() ?? '',
        matchKind = json['matchKind']?.toString() ?? '';

  final String url;
  final String dishName;
  final String sourceUrl;
  final String attribution;
  final String matchKind;

  bool get hasHttpsImage {
    final uri = Uri.tryParse(url);
    return uri?.scheme == 'https' && uri?.host.isNotEmpty == true;
  }
}
