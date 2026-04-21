import 'package:edly/core/network/app_exception.dart';
import 'package:edly/models/account_device.dart';
import 'package:edly/services/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DeviceManagementView extends StatefulWidget {
  const DeviceManagementView({super.key});

  @override
  State<DeviceManagementView> createState() => _DeviceManagementViewState();
}

class _DeviceManagementViewState extends State<DeviceManagementView> {
  AccountDeviceListResponse? _response;
  bool _isLoading = true;
  bool _isLoggingOutOthers = false;
  Set<int> _busyDeviceIds = <int>{};
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices({bool showLoader = true}) async {
    if (showLoader) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    } else {
      setState(() {
        _errorMessage = null;
      });
    }

    try {
      final response = await AuthRepository.instance.fetchAccountDevices();
      if (!mounted) {
        return;
      }

      setState(() {
        _response = response;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = _messageFromError(error);
      });
    }
  }

  Future<void> _logoutDevice(AccountDevice device) async {
    final confirmed = await _confirmAction(
      title: 'Đăng xuất thiết bị',
      message:
          'Thiết bị này sẽ phải đăng nhập lại để tiếp tục sử dụng. Bạn có muốn tiếp tục không?',
      confirmText: 'Đăng xuất',
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _busyDeviceIds = <int>{..._busyDeviceIds, device.id};
    });

    try {
      final message = await AuthRepository.instance.logoutAccountDevice(
        device.id,
      );
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      await _loadDevices(showLoader: false);
    } on AppException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() {
          _busyDeviceIds = <int>{
            for (final id in _busyDeviceIds)
              if (id != device.id) id,
          };
        });
      }
    }
  }

  Future<void> _logoutOtherDevices() async {
    final confirmed = await _confirmAction(
      title: 'Đăng xuất thiết bị khác',
      message:
          'Tất cả thiết bị khác sẽ bị đăng xuất và cần đăng nhập lại. Bạn có muốn tiếp tục không?',
      confirmText: 'Đăng xuất tất cả',
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _isLoggingOutOthers = true;
    });

    try {
      final message = await AuthRepository.instance.logoutOtherAccountDevices();
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      await _loadDevices(showLoader: false);
    } on AppException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() {
          _isLoggingOutOthers = false;
        });
      }
    }
  }

  Future<bool?> _confirmAction({
    required String title,
    required String message,
    required String confirmText,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(confirmText),
            ),
          ],
        );
      },
    );
  }

  String _messageFromError(Object error) {
    if (error is AppException) {
      return error.message;
    }

    return 'Không thể tải danh sách thiết bị.';
  }

  @override
  Widget build(BuildContext context) {
    final devices = _response?.devices ?? const <AccountDevice>[];
    final maxDevices = _response?.maxDevices;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text('Quản lý thiết bị'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF17233A),
        elevation: 0,
        surfaceTintColor: Colors.white,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null && _response == null
            ? _DeviceErrorState(
                message: _errorMessage!,
                onRetry: _loadDevices,
              )
            : RefreshIndicator(
                onRefresh: () => _loadDevices(showLoader: false),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    _DeviceSummaryCard(
                      activeCount: devices.length,
                      maxDevices: maxDevices,
                      isBusy: _isLoggingOutOthers,
                      onLogoutOthers: devices.where((item) => !item.isCurrent).isEmpty
                          ? null
                          : _logoutOtherDevices,
                    ),
                    const SizedBox(height: 16),
                    if (_errorMessage != null) ...[
                      _InlineNotice(message: _errorMessage!),
                      const SizedBox(height: 16),
                    ],
                    if (devices.isEmpty)
                      const _EmptyDeviceState()
                    else
                      ...devices.map(
                        (device) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _DeviceTile(
                            device: device,
                            isBusy: _busyDeviceIds.contains(device.id),
                            onLogout: device.isCurrent
                                ? null
                                : () => _logoutDevice(device),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _DeviceSummaryCard extends StatelessWidget {
  const _DeviceSummaryCard({
    required this.activeCount,
    required this.maxDevices,
    required this.isBusy,
    required this.onLogoutOthers,
  });

  final int activeCount;
  final int? maxDevices;
  final bool isBusy;
  final VoidCallback? onLogoutOthers;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF16345D), Color(0xFF2C77F4)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Thiết bị đang đăng nhập',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            maxDevices == null
                ? '$activeCount thiết bị đang hoạt động'
                : '$activeCount/$maxDevices thiết bị đang hoạt động',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonal(
              onPressed: isBusy ? null : onLogoutOthers,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.16),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.white.withValues(alpha: 0.1),
                disabledForegroundColor: Colors.white70,
                minimumSize: const Size(double.infinity, 48),
              ),
              child: isBusy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Đăng xuất tất cả thiết bị khác'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({
    required this.device,
    required this.isBusy,
    required this.onLogout,
  });

  final AccountDevice device;
  final bool isBusy;
  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: device.isCurrent
              ? const Color(0xFF9FC2FF)
              : const Color(0xFFE2E8F3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: device.isCurrent
                      ? const Color(0xFFDDEBFF)
                      : const Color(0xFFF1F5FB),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.smartphone_rounded,
                  color: device.isCurrent
                      ? const Color(0xFF0F67F4)
                      : const Color(0xFF61708A),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.deviceName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF17233A),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      device.isCurrent
                          ? 'Thiết bị hiện tại'
                          : 'Thiết bị đã đăng nhập',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF61708A),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (device.isCurrent)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F7EC),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Hiện tại',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF1F8A46),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _DeviceInfoRow(
            label: 'Đăng nhập lúc',
            value: _formatDateTime(device.lastLoginAt),
          ),
          const SizedBox(height: 6),
          _DeviceInfoRow(
            label: 'Hoạt động gần nhất',
            value: _formatDateTime(device.lastActiveAt),
          ),
          if (!device.isCurrent) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: isBusy ? null : onLogout,
                icon: isBusy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.logout_rounded),
                label: const Text('Đăng xuất thiết bị này'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 46),
                  foregroundColor: const Color(0xFFB42318),
                  side: const BorderSide(color: Color(0xFFF0C7C2)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _formatDateTime(DateTime? value) {
    if (value == null) {
      return 'Chưa có dữ liệu';
    }

    return DateFormat('HH:mm dd/MM/yyyy').format(value.toLocal());
  }
}

class _DeviceInfoRow extends StatelessWidget {
  const _DeviceInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 116,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFF61708A),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF17233A),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEEF0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFCCD5)),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: const Color(0xFFC7254E),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EmptyDeviceState extends StatelessWidget {
  const _EmptyDeviceState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F3)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.devices_other_rounded,
            size: 40,
            color: Color(0xFF8A96AA),
          ),
          const SizedBox(height: 12),
          Text(
            'Chưa có thiết bị nào được ghi nhận.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: const Color(0xFF17233A),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Danh sách này sẽ hiển thị các thiết bị đã đăng nhập bằng tài khoản của bạn.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF61708A),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceErrorState extends StatelessWidget {
  const _DeviceErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 44,
              color: Color(0xFF9AA7BB),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: const Color(0xFF526176),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }
}
