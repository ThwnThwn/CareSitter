class RuntimeConfig {
  const RuntimeConfig(
      {this.catalogBannerEnabled = true,
      this.catalogPageSize = 20,
      this.source = 'defaults'});
  final bool catalogBannerEnabled;
  final int catalogPageSize;
  final String source;

  factory RuntimeConfig.fromValues(
          {required String banner,
          required String pageSize,
          required String source}) =>
      RuntimeConfig(
          catalogBannerEnabled: switch (banner.toLowerCase()) {
            'false' => false,
            _ => true
          },
          catalogPageSize: (int.tryParse(pageSize) ?? 20).clamp(1, 50),
          source: source);
}
