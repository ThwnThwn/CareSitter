enum AnalyticsEvent {
  login('login', {'method', 'app_role'}),
  logout('logout', {'method', 'app_role'}),
  viewItem('view_item', {'item_category', 'item_id'}),
  bookingCreated('booking_created', {'service_category', 'match_mode'}),
  reportGenerated('report_generated', {'report_type', 'file_size_bytes'}),
  fileUploadCompleted('file_upload_completed',
      {'upload_purpose', 'file_type', 'file_size_bytes'}),
  fileUploadFailed('file_upload_failed', {'upload_purpose', 'error_code'});

  const AnalyticsEvent(this.eventName, this.parameters);
  final String eventName;
  final Set<String> parameters;
}
