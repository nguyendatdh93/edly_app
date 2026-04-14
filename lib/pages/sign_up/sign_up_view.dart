import 'package:edly/core/network/app_exception.dart';
import 'package:edly/core/navigation/auth_destination.dart';
import 'package:edly/core/navigation/app_routes.dart';
import 'package:edly/pages/sign_in/sign_in_view.dart';
import 'package:edly/pages/sign_up/sign_up_constants.dart';
import 'package:edly/services/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Màn hình đăng ký hiển thị theo layout mobile và gọi API thật.
class SignUpView extends StatefulWidget {
  const SignUpView({super.key});

  @override
  State<SignUpView> createState() => _SignUpViewState();
}

class _SignUpViewState extends State<SignUpView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmationController = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;
  Map<String, String> _fieldErrors = const {};

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _passwordConfirmationController.dispose();
    super.dispose();
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
      await AuthRepository.instance.signUp(
        name: _nameController.text.trim(),
        phone: normalizedPhone,
        password: _passwordController.text,
        passwordConfirmation: _passwordConfirmationController.text,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: AppRoutes.home),
          builder: (_) => buildSignedInDestination(),
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
        _fieldErrors = const {};
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _goToSignIn(BuildContext context) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }

    navigator.push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: AppRoutes.signIn),
        builder: (_) => const SignInView(),
      ),
    );
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

  String _normalizePhone(String rawValue) {
    var phone = rawValue.trim().replaceAll(RegExp(r'[^0-9+]'), '');

    if (phone.startsWith('+84')) {
      phone = '0${phone.substring(3)}';
    } else if (phone.startsWith('84') && phone.length == 11) {
      phone = '0${phone.substring(2)}';
    }

    return phone;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: SignUpPalette.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(26, 68, 26, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Image.asset(
                      SignUpContent.logoAsset,
                      height: 62,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 25),
                    Text(
                      SignUpContent.title,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: SignUpPalette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      SignUpContent.subtitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: SignUpPalette.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 30),
                    const _FieldLabel(SignUpContent.fullNameLabel),
                    const SizedBox(height: 10),
                    _SignUpField(
                      controller: _nameController,
                      hintText: SignUpContent.fullNameHint,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      errorText: _fieldErrors['name'],
                      onChanged: (_) => _clearFieldError('name'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Vui lòng nhập họ và tên.';
                        }
                        if (value.trim().length > 100) {
                          return 'Họ và tên tối đa 100 ký tự.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    const _FieldLabel(SignUpContent.phoneLabel),
                    const SizedBox(height: 10),
                    _SignUpField(
                      controller: _phoneController,
                      hintText: SignUpContent.phoneHint,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      errorText: _fieldErrors['phone'],
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9+\s().-]'),
                        ),
                      ],
                      onChanged: (_) => _clearFieldError('phone'),
                      validator: (value) {
                        final phone = _normalizePhone(value ?? '');
                        if (phone.isEmpty) {
                          return 'Vui lòng nhập số điện thoại.';
                        }
                        if (!RegExp(r'^(03|05|07|08|09)\d{8}$').hasMatch(phone)) {
                          return 'Số điện thoại không đúng định dạng.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    const _FieldLabel(SignUpContent.passwordLabel),
                    const SizedBox(height: 10),
                    _SignUpField(
                      controller: _passwordController,
                      hintText: SignUpContent.passwordHint,
                      obscureText: true,
                      textInputAction: TextInputAction.next,
                      errorText: _fieldErrors['password'],
                      onChanged: (_) => _clearFieldError('password'),
                      validator: (value) {
                        final password = value ?? '';
                        if (password.isEmpty) {
                          return 'Vui lòng nhập mật khẩu.';
                        }
                        if (password.length < 6 || password.length > 25) {
                          return 'Mật khẩu cần từ 6 đến 25 ký tự.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    const _FieldLabel(SignUpContent.confirmPasswordLabel),
                    const SizedBox(height: 10),
                    _SignUpField(
                      controller: _passwordConfirmationController,
                      hintText: SignUpContent.confirmPasswordHint,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      errorText: _fieldErrors['password_confirmation'],
                      onChanged: (_) {
                        _clearFieldError('password_confirmation');
                        _clearFieldError('password');
                      },
                      onFieldSubmitted: (_) => _submit(),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Vui lòng nhập lại mật khẩu.';
                        }
                        if (value != _passwordController.text) {
                          return 'Mật khẩu nhập lại không khớp.';
                        }
                        return null;
                      },
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      _ErrorNotice(message: _errorMessage!),
                    ],
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _isSubmitting ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: SignUpPalette.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
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
                                SignUpContent.primaryButton,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          SignUpContent.footerPrompt,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: SignUpPalette.textSecondary,
                          ),
                        ),
                        TextButton(
                          onPressed: () => _goToSignIn(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.only(left: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            foregroundColor: SignUpPalette.primary,
                          ),
                          child: const Text(
                            SignUpContent.footerAction,
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Nhãn tiêu đề nhỏ cho từng ô nhập liệu của màn đăng ký.
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: SignUpPalette.textPrimary,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

/// Ô nhập liệu dựng sẵn cho các trường thông tin trên màn đăng ký.
class _SignUpField extends StatefulWidget {
  const _SignUpField({
    required this.controller,
    required this.hintText,
    this.keyboardType,
    this.obscureText = false,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.validator,
    this.errorText,
    this.inputFormatters,
    this.onChanged,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;
  final String hintText;
  final TextInputType? keyboardType;
  final bool obscureText;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final String? Function(String?)? validator;
  final String? errorText;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  State<_SignUpField> createState() => _SignUpFieldState();
}

class _SignUpFieldState extends State<_SignUpField> {
  late bool _isObscured;

  @override
  void initState() {
    super.initState();
    _isObscured = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      keyboardType: widget.keyboardType,
      obscureText: _isObscured,
      textInputAction: widget.textInputAction,
      textCapitalization: widget.textCapitalization,
      validator: widget.validator,
      forceErrorText: widget.errorText,
      inputFormatters: widget.inputFormatters,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onFieldSubmitted,
      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
      decoration: InputDecoration(
        hintText: widget.hintText,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: SignUpPalette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: SignUpPalette.primary,
            width: 1.2,
          ),
        ),
        errorMaxLines: 2,
        hintStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: SignUpPalette.hint,
              fontWeight: FontWeight.w400,
            ),
        suffixIcon: widget.obscureText
            ? IconButton(
                onPressed: () {
                  setState(() {
                    _isObscured = !_isObscured;
                  });
                },
                icon: Icon(
                  _isObscured
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: SignUpPalette.hint,
                ),
              )
            : null,
      ),
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: SignUpPalette.textPrimary,
            fontWeight: FontWeight.w500,
          ),
    );
  }
}

class _ErrorNotice extends StatelessWidget {
  const _ErrorNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEEF0),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFC7D0)),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFFC7254E),
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
