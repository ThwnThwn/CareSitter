class ReportRequest<T> {
  const ReportRequest(this.result, this.cancel);
  final Future<T> result;
  final void Function() cancel;
}
