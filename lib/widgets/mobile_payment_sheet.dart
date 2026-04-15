import 'dart:async';

import 'package:edly/core/network/app_exception.dart';
import 'package:edly/pages/course_detail/course_detail_models.dart';
import 'package:edly/services/auth_repository.dart';
import 'package:edly/services/payment_repository.dart';
import 'package:edly/services/transaction_realtime_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

typedef BalancePurchaseHandler = Future<BalancePurchaseResult> Function();

class MobilePaymentSheetResult {
  const MobilePaymentSheetResult({
    required this.completed,
    required this.message,
  });

  final bool completed;
  final String message;
}

Future<MobilePaymentSheetResult?> showContentPaymentSheet({
  required BuildContext context,
  required String title,
  required int amount,
  required String contentType,
  required String contentId,
  String? courseId,
  required BalancePurchaseHandler onBalancePurchase,
}) {
  return showModalBottomSheet<MobilePaymentSheetResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      return _MobilePaymentSheet(
        title: title,
        amount: amount,
        contentType: contentType,
        contentId: contentId,
        courseId: courseId,
        onBalancePurchase: onBalancePurchase,
      );
    },
  );
}

Future<MobilePaymentSheetResult?> showDepositSheet(
  BuildContext context, {
  int initialAmount = 0,
}) {
  return showModalBottomSheet<MobilePaymentSheetResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      return _MobilePaymentSheet.deposit(initialDepositAmount: initialAmount);
    },
  );
}

class _MobilePaymentSheet extends StatefulWidget {
  const _MobilePaymentSheet({
    required this.title,
    required this.amount,
    required this.contentType,
    required this.contentId,
    required this.courseId,
    required this.onBalancePurchase,
  }) : isDeposit = false,
       initialDepositAmount = 0;

  const _MobilePaymentSheet.deposit({required this.initialDepositAmount})
    : isDeposit = true,
      title = 'Nạp tiền',
      amount = 0,
      contentType = null,
      contentId = null,
      courseId = null,
      onBalancePurchase = null;

  final bool isDeposit;
  final String title;
  final int amount;
  final int initialDepositAmount;
  final String? contentType;
  final String? contentId;
  final String? courseId;
  final BalancePurchaseHandler? onBalancePurchase;

  @override
  State<_MobilePaymentSheet> createState() => _MobilePaymentSheetState();
}

class _MobilePaymentSheetState extends State<_MobilePaymentSheet> {
  final NumberFormat _currencyFormat = NumberFormat.decimalPattern('vi_VN');
  late final TextEditingController _depositAmountController;
  StreamSubscription<MobilePaymentTransaction>? _transactionSubscription;

  MobileQrPayment? _qrPayment;
  MobilePaymentTransaction? _successTransaction;
  List<DepositOption> _depositOptions = const [];
  bool _isWorking = false;
  bool _isLoadingDepositOptions = false;
  bool _completed = false;
  String? _errorMessage;
  String? _saveSuccessMessage;

  int get _balance => AuthRepository.instance.currentUser?.balance ?? 0;

  int get _activeAmount {
    if (!widget.isDeposit) {
      return widget.amount;
    }
    return _parseAmount(_depositAmountController.text);
  }

  bool get _hasEnoughBalance => !widget.isDeposit && _balance >= widget.amount;

  @override
  void initState() {
    super.initState();
    _depositAmountController = TextEditingController(
      text: widget.initialDepositAmount > 0
          ? widget.initialDepositAmount.toString()
          : '',
    );
    if (widget.isDeposit) {
      _loadDepositOptions();
    }
  }

  @override
  void dispose() {
    _transactionSubscription?.cancel();
    _depositAmountController.dispose();
    super.dispose();
  }

  Future<void> _payByBalance() async {
    final handler = widget.onBalancePurchase;
    if (handler == null || _isWorking || widget.isDeposit) {
      return;
    }

    if (!_hasEnoughBalance) {
      setState(() {
        _errorMessage = 'Số dư không đủ để thanh toán bằng ví.';
      });
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Xác nhận mua gói'),
          content: Text(
            'Bạn muốn dùng số dư ví để thanh toán ${_formatMoney(widget.amount)} cho "${widget.title}"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Xác nhận'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _isWorking = true;
      _errorMessage = null;
      _saveSuccessMessage = null;
    });

    try {
      final result = await handler();
      await AuthRepository.instance.refreshCurrentUser();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(
        MobilePaymentSheetResult(
          completed: result.purchased || result.alreadyPurchased,
          message: result.message,
        ),
      );
    } on AppException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isWorking = false;
        });
      }
    }
  }

  Future<void> _loadDepositOptions() async {
    setState(() {
      _isLoadingDepositOptions = true;
    });

    try {
      final options = await PaymentRepository.instance.fetchDepositOptions();
      if (!mounted) {
        return;
      }
      setState(() {
        _depositOptions = options;
      });
    } on AppException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingDepositOptions = false;
        });
      }
    }
  }

  Future<void> _createQrPayment() async {
    if (_isWorking) {
      return;
    }

    final amount = _activeAmount;
    if (widget.isDeposit && amount < 1000) {
      setState(() {
        _errorMessage = 'Số tiền nạp tối thiểu là 1.000đ.';
      });
      return;
    }

    setState(() {
      _isWorking = true;
      _errorMessage = null;
    });

    try {
      final payment = widget.isDeposit
          ? await PaymentRepository.instance.createDepositQr(amount: amount)
          : await PaymentRepository.instance.createPurchaseQr(
              contentType: widget.contentType!,
              contentId: widget.contentId!,
              courseId: widget.courseId,
            );

      if (!mounted) {
        return;
      }

      if (payment.alreadyPurchased ||
          (payment.transaction?.isCompleted ?? false)) {
        await AuthRepository.instance.refreshCurrentUser();
        if (!mounted) {
          return;
        }
        Navigator.of(context).pop(
          MobilePaymentSheetResult(completed: true, message: payment.message),
        );
        return;
      }

      if (!payment.hasQr) {
        throw AppException(payment.message);
      }

      setState(() {
        _qrPayment = payment;
      });
      await _listenForTransaction(payment);
    } on AppException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isWorking = false;
        });
      }
    }
  }

  Future<void> _listenForTransaction(MobileQrPayment payment) async {
    await _transactionSubscription?.cancel();
    final expectedTransactionId = payment.transaction?.id;
    final expectedTransactionCode =
        payment.code ?? payment.transaction?.code ?? '';
    if ((expectedTransactionId == null || expectedTransactionId <= 0) &&
        expectedTransactionCode.isEmpty) {
      return;
    }
    try {
      _transactionSubscription = TransactionRealtimeService.instance
          .listenForCurrentUserTransactions()
          .listen(
            (transaction) async {
              final matchesId =
                  expectedTransactionId != null &&
                  expectedTransactionId > 0 &&
                  transaction.id == expectedTransactionId;
              final matchesCode =
                  expectedTransactionCode.isNotEmpty &&
                  transaction.code == expectedTransactionCode;

              if ((!matchesId && !matchesCode) || _completed || !mounted) {
                return;
              }

              setState(() {
                _qrPayment = _qrPayment?.copyWith(transaction: transaction);
              });

              if (transaction.isCompleted) {
                await _finishQrPayment(transaction);
                return;
              }

              if (transaction.isFailed) {
                await _transactionSubscription?.cancel();
                if (!mounted) {
                  return;
                }
                setState(() {
                  _errorMessage =
                      'Giao dịch bị từ chối. Vui lòng tạo lại mã QR hoặc liên hệ hỗ trợ.';
                });
              }
            },
            onError: (Object error) {
              if (!mounted) {
                return;
              }
              setState(() {
                _errorMessage = error is AppException
                    ? error.message
                    : 'Không nhận được thông báo thanh toán realtime.';
              });
            },
          );
    } on AppException catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = error.message;
        });
      }
    }
  }

  Future<void> _finishQrPayment(MobilePaymentTransaction transaction) async {
    if (_completed) {
      return;
    }
    _completed = true;
    await _transactionSubscription?.cancel();

    try {
      await AuthRepository.instance.refreshCurrentUser();
    } catch (_) {
      // Giao dịch đã xong, caller vẫn sẽ reload lại màn hình.
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _successTransaction = transaction;
      _errorMessage = null;
    });
  }

  void _closeWithSuccess() {
    Navigator.of(
      context,
    ).pop(MobilePaymentSheetResult(completed: true, message: _successMessage));
  }

  Future<void> _saveQrImage() async {
    final payment = _qrPayment;
    final qrUrl = payment?.qr;
    final code = payment?.code ?? payment?.transaction?.code;

    if (qrUrl == null || qrUrl.isEmpty || code == null || code.isEmpty) {
      return;
    }

    setState(() {
      _isWorking = true;
      _errorMessage = null;
    });

    try {
      await PaymentRepository.instance.saveQrImage(qrUrl: qrUrl, code: code);
      if (!mounted) {
        return;
      }
      const message = 'Đã lưu ảnh thành công';
      setState(() {
        _saveSuccessMessage = message;
      });
      _showSnackBar(message);
    } on AppException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.message;
        _saveSuccessMessage = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isWorking = false;
        });
      }
    }
  }

  Future<void> _openDepositSheet() async {
    final missing = widget.amount - _balance;
    final shortfall = missing <= 1000 ? 1000 : missing;
    final result = await showDepositSheet(context, initialAmount: shortfall);
    if (result?.completed == true) {
      try {
        await AuthRepository.instance.refreshCurrentUser();
      } catch (_) {}
      if (!mounted) {
        return;
      }
      setState(() {});
      _showSnackBar(result!.message);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    final bottomSafePadding = bottomInset > 0
        ? 0.0
        : mediaQuery.viewPadding.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(18, 16, 18, 22 + bottomSafePadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SheetHandle(),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.isDeposit ? 'Nạp tiền vào ví' : 'Thanh toán',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                widget.title,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              if (_successTransaction != null)
                _buildSuccessView()
              else if (_qrPayment == null)
                widget.isDeposit ? _buildDepositEntry() : _buildPaymentChoices()
              else
                _buildQrView(),
              if (_errorMessage != null) ...[
                const SizedBox(height: 14),
                _PaymentNotice(
                  icon: Icons.error_outline_rounded,
                  text: _errorMessage!,
                  backgroundColor: const Color(0xFFFFF1F2),
                  foregroundColor: const Color(0xFFBE123C),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentChoices() {
    final shortfall = widget.amount - _balance;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AmountSummary(
          label: 'Cần thanh toán',
          amount: widget.amount,
          balance: _balance,
        ),
        const SizedBox(height: 12),
        if (_hasEnoughBalance)
          _PaymentNotice(
            icon: Icons.check_circle_outline_rounded,
            text: 'Số dư đủ để thanh toán bằng ví.',
            backgroundColor: const Color(0xFFECFDF3),
            foregroundColor: const Color(0xFF047857),
          )
        else
          _PaymentNotice(
            icon: Icons.info_outline_rounded,
            text:
                'Số dư còn thiếu ${_formatMoney(shortfall)}. Bạn có thể nạp thêm hoặc thanh toán trực tiếp qua QR.',
            backgroundColor: const Color(0xFFFFFBEB),
            foregroundColor: const Color(0xFFB45309),
          ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _hasEnoughBalance && !_isWorking ? _payByBalance : null,
            icon: _isWorking
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.account_balance_wallet_outlined),
            label: Text(
              _hasEnoughBalance ? 'Thanh toán bằng số dư' : 'Số dư không đủ',
            ),
          ),
        ),
        if (!_hasEnoughBalance) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isWorking ? null : _openDepositSheet,
              icon: const Icon(Icons.add_card_rounded),
              label: const Text('Nạp thêm số dư'),
            ),
          ),
        ],
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isWorking ? null : _createQrPayment,
            icon: const Icon(Icons.qr_code_2_rounded),
            label: const Text('Thanh toán qua QR'),
          ),
        ),
      ],
    );
  }

  Widget _buildDepositEntry() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AmountSummary(
          label: 'Số dư hiện tại',
          amount: _balance,
          balance: null,
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _depositAmountController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Số tiền muốn nạp',
            suffixText: 'đ',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        if (_isLoadingDepositOptions)
          const Center(child: CircularProgressIndicator())
        else if (_depositOptions.isEmpty)
          const _PaymentNotice(
            icon: Icons.info_outline_rounded,
            text:
                'Chưa có mệnh giá nạp tiền từ hệ thống. Bạn vẫn có thể nhập số tiền muốn nạp.',
            backgroundColor: Color(0xFFEFF6FF),
            foregroundColor: Color(0xFF1D4ED8),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _depositOptions
                .map((option) {
                  final bonus = option.bonusPercentage;
                  final label = bonus > 0
                      ? '${_formatMoney(option.amount)} - Tặng ${_formatBonus(bonus)}%'
                      : _formatMoney(option.amount);
                  return ActionChip(
                    label: Text(label),
                    onPressed: () {
                      _depositAmountController.text = option.amount.toString();
                      setState(() {
                        _errorMessage = null;
                      });
                    },
                  );
                })
                .toList(growable: false),
          ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _isWorking ? null : _createQrPayment,
            icon: _isWorking
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.qr_code_2_rounded),
            label: const Text('Tạo mã QR nạp tiền'),
          ),
        ),
      ],
    );
  }

  Widget _buildQrView() {
    final payment = _qrPayment!;
    final transaction = payment.transaction;
    final bankAccount = payment.bankAccount;
    final qrUrl = payment.qr;
    final code = payment.code ?? transaction?.code ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PaymentNotice(
          icon: Icons.sync_rounded,
          text:
              'Sau khi chuyển khoản, app sẽ nhận thông báo tự động khi giao dịch thành công.',
          backgroundColor: const Color(0xFFEFF6FF),
          foregroundColor: const Color(0xFF1D4ED8),
        ),
        const SizedBox(height: 14),
        Center(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE5E7EB)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: qrUrl == null || qrUrl.isEmpty
                ? const SizedBox(
                    width: 220,
                    height: 220,
                    child: Center(child: Text('Không có ảnh QR')),
                  )
                : Image.network(
                    Uri.encodeFull(qrUrl),
                    width: 240,
                    height: 240,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const SizedBox(
                        width: 220,
                        height: 220,
                        child: Center(child: Text('Không tải được ảnh QR')),
                      );
                    },
                  ),
          ),
        ),
        const SizedBox(height: 14),
        _QrInfoRow(label: 'Số tiền', value: _formatMoney(payment.price)),
        if (bankAccount != null) ...[
          _QrInfoRow(label: 'Ngân hàng', value: bankAccount.bank),
          _QrInfoRow(label: 'Số tài khoản', value: bankAccount.accountNo),
          _QrInfoRow(label: 'Chủ tài khoản', value: bankAccount.accountName),
        ],
        if (code.isNotEmpty) _QrInfoRow(label: 'Nội dung', value: code),
        const SizedBox(height: 14),
        if (_saveSuccessMessage != null) ...[
          _PaymentNotice(
            icon: Icons.check_circle_outline_rounded,
            text: _saveSuccessMessage!,
            backgroundColor: const Color(0xFFECFDF3),
            foregroundColor: const Color(0xFF047857),
          ),
          const SizedBox(height: 10),
        ],
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isWorking ? null : _saveQrImage,
            icon: const Icon(Icons.download_rounded),
            label: const Text('Lưu ảnh QR'),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isWorking
                ? null
                : () async {
                    await _transactionSubscription?.cancel();
                    setState(() {
                      _qrPayment = null;
                      _errorMessage = null;
                      _saveSuccessMessage = null;
                    });
                  },
            icon: Icon(
              widget.isDeposit ? Icons.edit_rounded : Icons.payments_outlined,
            ),
            label: Text(
              widget.isDeposit ? 'Đổi số tiền' : 'Chọn phương thức khác',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessView() {
    final transaction = _successTransaction;
    final amount = transaction?.amount ?? _qrPayment?.price ?? _activeAmount;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF3),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFA7F3D0)),
          ),
          child: Column(
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 42,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _successTitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: const Color(0xFF065F46),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _successMessage,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF047857),
                  height: 1.45,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      widget.isDeposit ? 'Số tiền nạp' : 'Số tiền thanh toán',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatMoney(amount),
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: const Color(0xFF0F172A),
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _closeWithSuccess,
            child: const Text('Hoàn tất'),
          ),
        ),
      ],
    );
  }

  String get _successTitle =>
      widget.isDeposit ? 'Nạp tiền thành công!' : 'Thanh toán thành công!';

  String get _successMessage => widget.isDeposit
      ? 'Số dư ví của bạn đã được cập nhật.'
      : 'Bạn đã có quyền truy cập nội dung này.';

  String _formatMoney(int value) => '${_currencyFormat.format(value)}đ';

  String _formatBonus(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }
}

class _SheetHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 42,
        height: 4,
        decoration: BoxDecoration(
          color: const Color(0xFFE5E7EB),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _AmountSummary extends StatelessWidget {
  const _AmountSummary({
    required this.label,
    required this.amount,
    required this.balance,
  });

  final String label;
  final int amount;
  final int? balance;

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.decimalPattern('vi_VN');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${currencyFormat.format(amount)}đ',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: const Color(0xFF0F172A),
              fontWeight: FontWeight.w900,
            ),
          ),
          if (balance != null) ...[
            const SizedBox(height: 6),
            Text(
              'Số dư ví: ${currencyFormat.format(balance)}đ',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF475569),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PaymentNotice extends StatelessWidget {
  const _PaymentNotice({
    required this.icon,
    required this.text,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final IconData icon;
  final String text;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: foregroundColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: foregroundColor,
                height: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QrInfoRow extends StatelessWidget {
  const _QrInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF64748B)),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF0F172A),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

int _parseAmount(String value) {
  final normalized = value.replaceAll(RegExp(r'[^0-9]'), '');
  return int.tryParse(normalized) ?? 0;
}
