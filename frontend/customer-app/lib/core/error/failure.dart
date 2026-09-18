/// Giá trị lỗi bất biến để controller có thể biểu diễn lỗi mà không phụ thuộc Dio.
class Failure {
  final String message;
  final String? code;

  const Failure(this.message, {this.code});
}
