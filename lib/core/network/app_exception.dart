/// Exception chuẩn hóa lỗi từ API để hiện message cho người dùng.
class AppException implements Exception {
  const AppException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Exception cho lỗi validate từ API, kèm lỗi chi tiết theo từng field.
class ApiValidationException extends AppException {
  const ApiValidationException(
    super.message, {
    super.statusCode,
    required this.fieldErrors,
  });

  final Map<String, String> fieldErrors;
}
