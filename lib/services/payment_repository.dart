import 'dart:io';

import 'package:dio/dio.dart';
import 'package:edly/core/config/api_config.dart';
import 'package:edly/core/network/app_exception.dart';
import 'package:edly/services/auth_repository.dart';
import 'package:flutter/services.dart';

class PaymentRepository {
  PaymentRepository._internal()
    : _dio = Dio(
        BaseOptions(
          baseUrl: ApiConfig.baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 20),
          sendTimeout: const Duration(seconds: 15),
          headers: const {'Accept': 'application/json'},
          contentType: Headers.jsonContentType,
          responseType: ResponseType.json,
        ),
      );

  static final PaymentRepository instance = PaymentRepository._internal();
  static const MethodChannel _mediaChannel = MethodChannel('edly/media');

  final Dio _dio;

  Future<MobileQrPayment> createPurchaseQr({
    required String contentType,
    required String contentId,
    String? courseId,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        '/mobile/purchases/qr',
        data: {
          'content_type': contentType,
          'content_id': contentId,
          if (courseId != null && courseId.trim().isNotEmpty)
            'course_id': courseId.trim(),
        },
        options: _requiredAuthorizedOptions(),
      );

      return MobileQrPayment.fromJson(_responseMap(response));
    } on DioException catch (error) {
      throw AppException(
        _messageFromError(error, fallback: 'Không thể tạo mã QR thanh toán.'),
        statusCode: error.response?.statusCode,
      );
    }
  }

  Future<MobileQrPayment> createDepositQr({required int amount}) async {
    try {
      final response = await _dio.post<dynamic>(
        '/mobile/deposits/qr',
        data: {'price': amount},
        options: _requiredAuthorizedOptions(),
      );

      return MobileQrPayment.fromJson(_responseMap(response));
    } on DioException catch (error) {
      throw AppException(
        _messageFromError(error, fallback: 'Không thể tạo mã QR nạp tiền.'),
        statusCode: error.response?.statusCode,
      );
    }
  }

  Future<List<DepositOption>> fetchDepositOptions() async {
    try {
      final response = await _dio.get<dynamic>(
        '/mobile/deposits',
        options: _requiredAuthorizedOptions(),
      );
      final payload = _responseMap(response);
      final rawItems = payload['deposits'];

      if (rawItems is! List) {
        return const [];
      }

      return rawItems
          .whereType<Map>()
          .map(
            (item) => DepositOption.fromJson(Map<String, dynamic>.from(item)),
          )
          .where((item) => item.amount > 0)
          .toList(growable: false);
    } on DioException catch (error) {
      throw AppException(
        _messageFromError(
          error,
          fallback: 'Không thể tải danh sách mệnh giá nạp tiền.',
        ),
        statusCode: error.response?.statusCode,
      );
    }
  }

  Future<String> saveQrImage({
    required String qrUrl,
    required String code,
  }) async {
    try {
      final response = await _dio.get<Uint8List>(
        Uri.encodeFull(qrUrl),
        options: Options(
          responseType: ResponseType.bytes,
          headers: const {'Accept': 'image/png,image/*'},
        ),
      );

      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) {
        throw const AppException('Không nhận được dữ liệu ảnh QR.');
      }

      final fileName = 'edly_qr_${_safeFileName(code)}.png';
      if (Platform.isAndroid) {
        try {
          final savedUri = await _mediaChannel.invokeMethod<String>(
            'savePngToPictures',
            {'fileName': fileName, 'bytes': bytes},
          );
          if (savedUri == null || savedUri.isEmpty) {
            throw const AppException('Không nhận được vị trí ảnh đã lưu.');
          }
          return savedUri;
        } on MissingPluginException {
          return _saveBytesToFallbackFile(fileName: fileName, bytes: bytes);
        } on PlatformException {
          return _saveBytesToFallbackFile(fileName: fileName, bytes: bytes);
        }
      }

      return _saveBytesToFallbackFile(fileName: fileName, bytes: bytes);
    } on AppException {
      rethrow;
    } on DioException catch (error) {
      throw AppException(
        _messageFromError(error, fallback: 'Không thể tải ảnh QR để lưu.'),
        statusCode: error.response?.statusCode,
      );
    } catch (_) {
      throw const AppException(
        'Không thể lưu ảnh QR trên thiết bị này. Hãy mở ảnh QR rồi lưu thủ công.',
      );
    }
  }

  Future<String> _saveBytesToFallbackFile({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final candidates = _downloadDirectories();

    Object? lastError;
    for (final directory in candidates) {
      try {
        if (!directory.existsSync()) {
          directory.createSync(recursive: true);
        }
        final file = File('${directory.path}/$fileName');
        await file.writeAsBytes(bytes, flush: true);
        return file.path;
      } catch (error) {
        lastError = error;
      }
    }

    throw AppException(
      'Không thể lưu ảnh QR trên thiết bị này. ${lastError ?? ''}'.trim(),
    );
  }

  Options _requiredAuthorizedOptions() {
    final token = AuthRepository.instance.currentToken;
    if (token == null || token.isEmpty) {
      throw const AppException('Bạn cần đăng nhập để thực hiện giao dịch.');
    }

    return Options(
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );
  }
}

class DepositOption {
  const DepositOption({
    required this.id,
    required this.amount,
    required this.bonusPercentage,
    required this.isActive,
  });

  final int id;
  final int amount;
  final double bonusPercentage;
  final String isActive;

  factory DepositOption.fromJson(Map<String, dynamic> json) {
    return DepositOption(
      id: _asInt(json['id']),
      amount: _asInt(json['amount']),
      bonusPercentage: _asDouble(json['bonus_percentage']),
      isActive: _asStr(json['is_active']),
    );
  }
}

class MobileQrPayment {
  const MobileQrPayment({
    required this.message,
    required this.price,
    required this.transaction,
    required this.qr,
    required this.bankAccount,
    required this.code,
    required this.purchased,
    required this.alreadyPurchased,
  });

  final String message;
  final int price;
  final MobilePaymentTransaction? transaction;
  final String? qr;
  final MobileBankAccount? bankAccount;
  final String? code;
  final bool purchased;
  final bool alreadyPurchased;

  bool get hasQr => qr != null && qr!.isNotEmpty && transaction != null;

  factory MobileQrPayment.fromJson(Map<String, dynamic> json) {
    final transactionMap = _asMapOrNull(json['transaction']);
    final bankAccountMap = _asMapOrNull(json['bank_account']);

    return MobileQrPayment(
      message: _asStr(json['message']).isNotEmpty
          ? _asStr(json['message'])
          : 'Đã tạo mã QR thanh toán.',
      price: _asInt(json['price']),
      transaction: transactionMap == null
          ? null
          : MobilePaymentTransaction.fromJson(transactionMap),
      qr: _asNullableStr(json['qr']),
      bankAccount: bankAccountMap == null
          ? null
          : MobileBankAccount.fromJson(bankAccountMap),
      code: _asNullableStr(json['code'] ?? transactionMap?['code']),
      purchased: json['purchased'] == true,
      alreadyPurchased: json['already_purchased'] == true,
    );
  }

  MobileQrPayment copyWith({MobilePaymentTransaction? transaction}) {
    return MobileQrPayment(
      message: message,
      price: price,
      transaction: transaction ?? this.transaction,
      qr: qr,
      bankAccount: bankAccount,
      code: code,
      purchased: purchased,
      alreadyPurchased: alreadyPurchased,
    );
  }
}

class MobilePaymentTransaction {
  const MobilePaymentTransaction({
    required this.id,
    required this.type,
    required this.status,
    required this.amount,
    required this.code,
  });

  final int id;
  final String type;
  final String status;
  final int amount;
  final String? code;

  bool get isCompleted => status.toUpperCase() == 'COMPLETED';
  bool get isFailed => status.toUpperCase() == 'FAILED';
  bool get isPending => status.toUpperCase() == 'PENDING';

  factory MobilePaymentTransaction.fromJson(Map<String, dynamic> json) {
    return MobilePaymentTransaction(
      id: _asInt(json['id']),
      type: _asStr(json['type']),
      status: _asStr(json['status']),
      amount: _asInt(json['amount']),
      code: _asNullableStr(json['code']),
    );
  }
}

class MobileBankAccount {
  const MobileBankAccount({
    required this.bank,
    required this.accountNo,
    required this.accountName,
  });

  final String bank;
  final String accountNo;
  final String accountName;

  factory MobileBankAccount.fromJson(Map<String, dynamic> json) {
    return MobileBankAccount(
      bank: _asStr(json['bank']),
      accountNo: _asStr(json['account_no']),
      accountName: _asStr(json['account_name']),
    );
  }
}

Map<String, dynamic> _responseMap(Response<dynamic> response) {
  final data = response.data;

  if (data is Map<String, dynamic>) {
    return data;
  }

  if (data is Map) {
    return data.map((key, value) => MapEntry(key.toString(), value));
  }

  throw const AppException('Phản hồi thanh toán không hợp lệ.');
}

String _messageFromError(DioException error, {required String fallback}) {
  final data = error.response?.data;

  if (data is Map) {
    final message = data['message'];
    if (message is String && message.trim().isNotEmpty) {
      return message.trim();
    }
  }

  if (error.response?.statusCode == 404) {
    return 'Backend chưa bật API thanh toán mobile.';
  }

  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.sendTimeout:
      return 'Kết nối tới API thanh toán bị quá thời gian.';
    case DioExceptionType.connectionError:
      return 'Không thể kết nối tới API thanh toán.';
    default:
      return fallback;
  }
}

List<Directory> _downloadDirectories() {
  if (Platform.isAndroid) {
    return <Directory>[
      Directory('/storage/emulated/0/Pictures/Edly'),
      Directory('/sdcard/Pictures/Edly'),
      Directory('/storage/emulated/0/Download'),
      Directory('/sdcard/Download'),
      Directory.systemTemp,
    ];
  }

  final home = Platform.environment['HOME'];
  return <Directory>[
    if (home != null && home.isNotEmpty) Directory('$home/Downloads'),
    if (home != null && home.isNotEmpty) Directory('$home/Documents'),
    Directory.systemTemp,
  ];
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, dynamic item) => MapEntry(key.toString(), item));
  }
  return const {};
}

Map<String, dynamic>? _asMapOrNull(dynamic value) {
  final map = _asMap(value);
  return map.isEmpty ? null : map;
}

String _asStr(dynamic value) => (value ?? '').toString().trim();

String? _asNullableStr(dynamic value) {
  final text = _asStr(value);
  return text.isEmpty ? null : text;
}

int _asInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? 0;
}

double _asDouble(dynamic value) {
  if (value == null) return 0;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}

String _safeFileName(String value) {
  final normalized = value.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_');
  if (normalized.isEmpty) {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }
  return normalized;
}
