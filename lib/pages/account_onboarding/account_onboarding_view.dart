import 'package:edly/core/network/app_exception.dart';
import 'package:edly/pages/home/home_view.dart';
import 'package:edly/services/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AccountOnboardingView extends StatefulWidget {
  const AccountOnboardingView({super.key});

  @override
  State<AccountOnboardingView> createState() => _AccountOnboardingViewState();
}

class _AccountOnboardingViewState extends State<AccountOnboardingView> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();

  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _phoneLocked = false;
  bool _examInterestSat = true;
  bool _examInterestIelts = false;
  String? _selectedRole;
  String? _errorMessage;
  Map<String, String> _fieldErrors = const {};

  @override
  void initState() {
    super.initState();
    _loadOnboarding();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadOnboarding() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await AuthRepository.instance.fetchAccountOnboarding();

      if (!mounted) {
        return;
      }

      if (!data.show) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(
            builder: (_) => const HomeView(),
          ),
          (route) => false,
        );
        return;
      }

      setState(() {
        _isLoading = false;
        _phoneLocked = data.phoneLocked;
        _phoneController.text = data.phone ?? '';
        _examInterestSat = data.examInterestSat;
        _examInterestIelts = data.examInterestIelts;
        _selectedRole = data.role;
      });
    } on AppException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = error.message;
      });
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final normalizedPhone = _normalizePhone(_phoneController.text);
    _phoneController.value = _phoneController.value.copyWith(
      text: normalizedPhone,
      selection: TextSelection.collapsed(offset: normalizedPhone.length),
      composing: TextRange.empty,
    );

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _fieldErrors = const {};
    });

    try {
      final response = await AuthRepository.instance.updateAccountOnboarding(
        phone: normalizedPhone,
        examInterestSat: _examInterestSat,
        examInterestIelts: _examInterestIelts,
        role: _selectedRole ?? '',
      );

      if (!mounted) {
        return;
      }

      if (response.show) {
        setState(() {
          _phoneLocked = response.phoneLocked;
          _phoneController.text = response.phone ?? '';
          _examInterestSat = response.examInterestSat;
          _examInterestIelts = response.examInterestIelts;
          _selectedRole = response.role;
        });
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => const HomeView(),
        ),
        (route) => false,
      );
    } on ApiValidationException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.message;
        _fieldErrors = error.fieldErrors;
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
          _isSubmitting = false;
        });
      }
    }
  }

  String _normalizePhone(String rawValue) {
    var phone = rawValue.trim().replaceAll(RegExp(r'[^0-9+]'), '');

    if (phone.startsWith('+84')) {
      phone = '0${phone.substring(3)}';
    } else if (phone.startsWith('84') && phone.length == 11) {
      phone = '0${phone.substring(2)}';
    }

    return phone;
  }

  void _clearFieldError(String field) {
    if (!_fieldErrors.containsKey(field)) {
      return;
    }

    final clearedMessage = _fieldErrors[field];

    setState(() {
      final nextErrors = Map<String, String>.from(_fieldErrors);
      nextErrors.remove(field);
      _fieldErrors = nextErrors;

      if (_fieldErrors.isEmpty && _errorMessage == clearedMessage) {
        _errorMessage = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF152237).withValues(alpha: 0.86),
        body: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(18),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x2A0F172A),
                              blurRadius: 36,
                              offset: Offset(0, 22),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(22, 24, 22, 10),
                                child: Center(
                                  child: Text(
                                    'Cập nhật thông tin tài khoản',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(
                                          color: const Color(0xFF2B313A),
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(
                                        Icons.info_outline_rounded,
                                        color: Color(0xFF3B82F6),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          _phoneLocked
                                              ? 'Số điện thoại của bạn đã được cập nhật. Bạn có thể tiếp tục hoàn thiện thông tin bên dưới.'
                                              : 'Vui lòng nhập chính xác số điện thoại của bạn để nhận đầy đủ quyền lợi và sử dụng toàn bộ tính năng của app.',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                color: const Color(0xFF1D4ED8),
                                                height: 1.45,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Thông tin liên hệ',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            color: const Color(0xFF2B313A),
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Số điện thoại',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            color: const Color(0xFF374151),
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: _phoneController,
                                      enabled: !_phoneLocked,
                                      keyboardType: TextInputType.phone,
                                      textInputAction: TextInputAction.next,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(
                                          RegExp(r'[0-9+\s().-]'),
                                        ),
                                      ],
                                      validator: (value) {
                                        if (_phoneLocked) {
                                          return null;
                                        }

                                        final phone = _normalizePhone(value ?? '');
                                        if (phone.isEmpty) {
                                          return 'Không được để trống!';
                                        }

                                        if (!RegExp(r'^(0|\+84)?[35789]\d{8}$')
                                            .hasMatch(phone)) {
                                          return 'Số điện thoại không chính xác!';
                                        }

                                        return null;
                                      },
                                      onChanged: (_) => _clearFieldError('phone'),
                                      forceErrorText: _fieldErrors['phone'],
                                      decoration: InputDecoration(
                                        hintText: 'Nhập số điện thoại của bạn',
                                        prefixIcon: const Icon(
                                          Icons.phone_outlined,
                                          color: Color(0xFF6B7280),
                                        ),
                                        filled: true,
                                        fillColor: const Color(0xFFFBFBFB),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(14),
                                          borderSide: const BorderSide(
                                            color: Color(0xFFE5E7EB),
                                          ),
                                        ),
                                        disabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(14),
                                          borderSide: const BorderSide(
                                            color: Color(0xFFE5E7EB),
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(14),
                                          borderSide: const BorderSide(
                                            color: Color(0xFF3B82F6),
                                            width: 1.2,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 26),
                                    Text(
                                      '* Bạn quan tâm đến',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            color: const Color(0xFF2B313A),
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 18,
                                      runSpacing: 8,
                                      children: [
                                        _InterestCheckbox(
                                          label: 'SAT',
                                          value: _examInterestSat,
                                          onChanged: (value) {
                                            setState(() {
                                              _examInterestSat = value ?? false;
                                            });
                                            _clearFieldError('exam_interest_sat');
                                          },
                                        ),
                                        _InterestCheckbox(
                                          label: 'IELTS',
                                          value: _examInterestIelts,
                                          onChanged: (value) {
                                            setState(() {
                                              _examInterestIelts = value ?? false;
                                            });
                                            _clearFieldError('exam_interest_sat');
                                          },
                                        ),
                                      ],
                                    ),
                                    if (_fieldErrors['exam_interest_sat'] != null) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        _fieldErrors['exam_interest_sat']!,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: const Color(0xFFDC2626),
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ],
                                    const SizedBox(height: 26),
                                    Text(
                                      '* Vai trò',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            color: const Color(0xFF2B313A),
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Bạn là: Học sinh / Phụ huynh / Giáo viên',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: const Color(0xFF6B7280),
                                          ),
                                    ),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 22,
                                      runSpacing: 10,
                                      children: [
                                        _RoleRadio(
                                          label: 'Học sinh',
                                          value: 'student',
                                          groupValue: _selectedRole,
                                          onChanged: (value) {
                                            setState(() {
                                              _selectedRole = value;
                                            });
                                            _clearFieldError('role');
                                          },
                                        ),
                                        _RoleRadio(
                                          label: 'Phụ huynh',
                                          value: 'parent',
                                          groupValue: _selectedRole,
                                          onChanged: (value) {
                                            setState(() {
                                              _selectedRole = value;
                                            });
                                            _clearFieldError('role');
                                          },
                                        ),
                                        _RoleRadio(
                                          label: 'Giáo viên',
                                          value: 'teacher',
                                          groupValue: _selectedRole,
                                          onChanged: (value) {
                                            setState(() {
                                              _selectedRole = value;
                                            });
                                            _clearFieldError('role');
                                          },
                                        ),
                                      ],
                                    ),
                                    if (_fieldErrors['role'] != null) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        _fieldErrors['role']!,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: const Color(0xFFDC2626),
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ],
                                    if (_errorMessage != null) ...[
                                      const SizedBox(height: 18),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFEEF0),
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(
                                            color: const Color(0xFFFFCDD5),
                                          ),
                                        ),
                                        child: Text(
                                          _errorMessage!,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                color: const Color(0xFFC7254E),
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.fromLTRB(22, 16, 22, 22),
                                decoration: const BoxDecoration(
                                  border: Border(
                                    top: BorderSide(color: Color(0xFFF1F5F9)),
                                  ),
                                ),
                                child: FilledButton(
                                  onPressed: _isSubmitting ? null : _submit,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF14B8A6),
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(double.infinity, 52),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: _isSubmitting
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.4,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text(
                                          'Cập nhật',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _InterestCheckbox extends StatelessWidget {
  const _InterestCheckbox({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Checkbox(
            value: value,
            onChanged: onChanged,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5),
            ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF2B313A),
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _RoleRadio extends StatelessWidget {
  const _RoleRadio({
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  final String label;
  final String value;
  final String? groupValue;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final isSelected = groupValue == value;

    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF2563EB)
                    : const Color(0xFF9CA3AF),
                width: 1.4,
              ),
            ),
            alignment: Alignment.center,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? const Color(0xFF2563EB)
                    : Colors.transparent,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF2B313A),
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
