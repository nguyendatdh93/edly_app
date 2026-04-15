import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:edly/core/config/api_config.dart';
import 'package:edly/core/network/app_exception.dart';
import 'package:edly/services/auth_repository.dart';
import 'package:edly/services/payment_repository.dart';

class TransactionRealtimeService {
  TransactionRealtimeService._internal();

  static final TransactionRealtimeService instance =
      TransactionRealtimeService._internal();

  WebSocket? _socket;
  StreamSubscription<dynamic>? _socketSubscription;
  StreamController<MobilePaymentTransaction>? _transactionController;
  int? _subscribedUserId;

  Stream<MobilePaymentTransaction> listenForCurrentUserTransactions() {
    final user = AuthRepository.instance.currentUser;
    if (user == null) {
      throw const AppException(
        'Bạn cần đăng nhập để nhận thông báo giao dịch.',
      );
    }

    if (_transactionController == null || _transactionController!.isClosed) {
      _transactionController =
          StreamController<MobilePaymentTransaction>.broadcast(
            onCancel: () {
              if (_transactionController?.hasListener != true) {
                disconnect();
              }
            },
          );
    }

    if (_socket == null || _subscribedUserId != user.id) {
      unawaited(_connect(user.id));
    }

    return _transactionController!.stream;
  }

  Future<void> disconnect() async {
    _subscribedUserId = null;
    await _socketSubscription?.cancel();
    _socketSubscription = null;
    final socket = _socket;
    _socket = null;
    await socket?.close();
  }

  Future<void> _connect(int userId) async {
    await disconnect();

    final key = ApiConfig.pusherAppKey;
    final host = ApiConfig.pusherHost;
    if (key.isEmpty || host.isEmpty) {
      _transactionController?.addError(
        const AppException('Thiếu cấu hình realtime thanh toán.'),
      );
      return;
    }

    final scheme = ApiConfig.pusherUseTls ? 'wss' : 'ws';
    final uri = Uri(
      scheme: scheme,
      host: host,
      port: ApiConfig.pusherPort,
      path: '/app/$key',
      queryParameters: const {
        'protocol': '7',
        'client': 'edly-mobile',
        'version': '1.0.0',
        'flash': 'false',
      },
    );

    try {
      final socket = await WebSocket.connect(uri.toString());
      _socket = socket;
      _subscribedUserId = userId;
      _socketSubscription = socket.listen(
        (message) => _handleMessage(message, userId),
        onError: (Object error) {
          _transactionController?.addError(
            const AppException('Mất kết nối thông báo thanh toán.'),
          );
        },
        onDone: () {
          _socket = null;
          _subscribedUserId = null;
        },
        cancelOnError: false,
      );
    } catch (_) {
      _transactionController?.addError(
        const AppException('Không kết nối được thông báo thanh toán.'),
      );
    }
  }

  void _handleMessage(dynamic message, int userId) {
    final payload = _decodeMap(message);
    final event = _asStr(payload['event']);

    if (event == 'pusher:connection_established') {
      _subscribeToUserTransactions(userId);
      return;
    }

    if (event == 'pusher:ping') {
      _send({'event': 'pusher:pong', 'data': const {}});
      return;
    }

    if (!event.endsWith('TransactionProcessed')) {
      return;
    }

    final data = _decodeMap(payload['data']);
    final transactionMap = _asMap(data['transaction']);
    if (transactionMap.isEmpty) {
      return;
    }

    _transactionController?.add(
      MobilePaymentTransaction.fromJson(transactionMap),
    );
  }

  void _subscribeToUserTransactions(int userId) {
    _send({
      'event': 'pusher:subscribe',
      'data': {'channel': 'user.transaction.$userId'},
    });
  }

  void _send(Map<String, dynamic> payload) {
    final socket = _socket;
    if (socket == null || socket.readyState != WebSocket.open) {
      return;
    }
    socket.add(jsonEncode(payload));
  }
}

Map<String, dynamic> _decodeMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, dynamic item) => MapEntry(key.toString(), item));
  }
  if (value is String && value.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.map(
          (key, dynamic item) => MapEntry(key.toString(), item),
        );
      }
    } catch (_) {
      return const {};
    }
  }
  return const {};
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

String _asStr(dynamic value) => (value ?? '').toString().trim();
