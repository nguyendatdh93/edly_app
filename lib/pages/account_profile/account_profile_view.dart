import 'package:edly/core/network/app_exception.dart';
import 'package:edly/core/navigation/app_routes.dart';
import 'package:edly/models/account_profile.dart';
import 'package:edly/pages/home/home_view.dart';
import 'package:edly/pages/menu/user_course_list_view.dart';
import 'package:edly/services/auth_repository.dart';
import 'package:flutter/material.dart';

class AccountProfileView extends StatefulWidget {
  const AccountProfileView({super.key, this.isOnboarding = false});

  final bool isOnboarding;

  @override
  State<AccountProfileView> createState() => _AccountProfileViewState();
}

class _AccountProfileViewState extends State<AccountProfileView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  AccountProfileScreenData? _screenData;
  bool _isLoading = true;
  bool _isRefreshingOptions = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  Map<String, String> _fieldErrors = const {};
  String? _selectedBirthday;
  String? _selectedUserType;
  int? _selectedProvinceId;
  int? _selectedDistrictId;
  int? _selectedSchoolId;
  int _loadSequence = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile({
    int? provinceId,
    int? districtId,
    bool preserveDraft = false,
  }) async {
    final requestId = ++_loadSequence;
    final currentName = _nameController.text;
    final currentEmail = _emailController.text;
    final currentBirthday = _selectedBirthday;
    final currentUserType = _selectedUserType;
    final currentProvinceId = _selectedProvinceId;
    final currentDistrictId = _selectedDistrictId;
    final currentSchoolId = _selectedSchoolId;

    setState(() {
      if (_screenData == null) {
        _isLoading = true;
      } else {
        _isRefreshingOptions = preserveDraft;
      }
      _errorMessage = null;
    });

    try {
      final data = await AuthRepository.instance.fetchAccountProfile(
        provinceId: provinceId,
        districtId: districtId,
      );

      if (!mounted || requestId != _loadSequence) {
        return;
      }

      setState(() {
        _screenData = data;
        _isLoading = false;
        _isRefreshingOptions = false;
        _errorMessage = null;

        if (preserveDraft) {
          _nameController.text = currentName;
          _emailController.text = currentEmail;
          _selectedBirthday = _sanitizeSelectValue(
            currentBirthday,
            data.form.birthYearOptions.map((option) => option.value).toList(),
          );
          _selectedUserType = _sanitizeSelectValue(
            currentUserType,
            data.form.userTypeOptions.map((option) => option.value).toList(),
          );
          _selectedProvinceId = _sanitizeLocationValue(
            currentProvinceId,
            data.form.provinceOptions,
          );
          _selectedDistrictId = _sanitizeLocationValue(
            currentDistrictId,
            data.form.districtOptions,
          );
          _selectedSchoolId = _sanitizeLocationValue(
            currentSchoolId,
            data.form.schoolOptions,
          );
        } else {
          _applyProfile(data.profile, data.form);
        }
      });
    } catch (error) {
      if (!mounted || requestId != _loadSequence) {
        return;
      }

      setState(() {
        _isLoading = false;
        _isRefreshingOptions = false;
        _errorMessage = _messageFromError(error);
      });
    }
  }

  void _applyProfile(AccountProfile profile, AccountProfileFormSchema form) {
    _nameController.text = profile.name;
    _emailController.text = profile.email ?? '';
    _selectedBirthday = _sanitizeSelectValue(
      profile.birthday,
      form.birthYearOptions.map((option) => option.value).toList(),
    );
    _selectedUserType = _sanitizeSelectValue(
      profile.userType,
      form.userTypeOptions.map((option) => option.value).toList(),
    );
    _selectedProvinceId = _sanitizeLocationValue(
      profile.provinceId,
      form.provinceOptions,
    );
    _selectedDistrictId = _sanitizeLocationValue(
      profile.districtId,
      form.districtOptions,
    );
    _selectedSchoolId = _sanitizeLocationValue(
      profile.schoolId,
      form.schoolOptions,
    );
  }

  Future<void> _reloadLocationOptions({int? provinceId, int? districtId}) {
    return _loadProfile(
      provinceId: provinceId,
      districtId: districtId,
      preserveDraft: true,
    );
  }

  Future<void> _submit() async {
    final data = _screenData;
    if (data == null) {
      return;
    }

    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _fieldErrors = const {};
    });

    try {
      final response = await AuthRepository.instance.updateAccountProfile(
        payload: _buildPayload(data.form),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _screenData = response;
        _applyProfile(response.profile, response.form);
      });

      final message = response.message ?? 'Cập nhật trang cá nhân thành công.';

      if (widget.isOnboarding) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(
            settings: const RouteSettings(name: AppRoutes.home),
            builder: (_) => const HomeView(),
          ),
          (route) => false,
        );
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
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

  Map<String, dynamic> _buildPayload(AccountProfileFormSchema form) {
    final payload = <String, dynamic>{};

    if (form.name.enabled) {
      payload['name'] = _nameController.text.trim();
    }

    if (form.email.enabled && form.email.editable) {
      payload['email'] = _emailController.text.trim();
    }

    if (form.birthday.enabled) {
      payload['birthday'] = _selectedBirthday;
    }

    if (form.userType.enabled) {
      payload['user_type'] = _selectedUserType;
    }

    if (form.province.enabled) {
      payload['province_id'] = _selectedProvinceId;
    }

    if (form.district.enabled) {
      payload['district_id'] = _selectedDistrictId;
    }

    if (form.school.enabled) {
      payload['school_id'] = _selectedSchoolId;
    }

    return payload;
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

  String _messageFromError(Object? error) {
    if (error is AppException) {
      return error.message;
    }

    return 'Không thể tải thông tin tài khoản.';
  }

  void _handleProfileAction(String title) {
    if (title == 'Gói đã mua') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              const UserCourseListView(mode: UserCourseListMode.purchased),
        ),
      );
      return;
    }

    if (title == 'Tiến độ học tập') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              const UserCourseListView(mode: UserCourseListMode.progress),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$title đang được đồng bộ từ web.')));
  }

  String? _sanitizeSelectValue(String? value, List<String> options) {
    if (value == null || value.isEmpty) {
      return null;
    }

    return options.contains(value) ? value : null;
  }

  int? _sanitizeLocationValue(
    int? value,
    List<AccountProfileLocationOption> options,
  ) {
    if (value == null) {
      return null;
    }

    return options.any((option) => option.id == value) ? value : null;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.isOnboarding,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F7FB),
        body: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _screenData == null
              ? _ProfileErrorState(
                  message: _errorMessage ?? 'Không thể tải dữ liệu hồ sơ.',
                  onRetry: _loadProfile,
                )
              : _buildLoadedState(context, _screenData!),
        ),
      ),
    );
  }

  Widget _buildLoadedState(
    BuildContext context,
    AccountProfileScreenData data,
  ) {
    final profile = data.profile;
    final form = data.form;
    final theme = Theme.of(context);

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF16345D), Color(0xFF2C77F4)],
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(28),
              bottomRight: Radius.circular(28),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (!widget.isOnboarding)
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.16),
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                  if (!widget.isOnboarding) const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.isOnboarding ? 'Hoàn tất hồ sơ' : 'Trang cá nhân',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                  ),
                ],
              ),
              if (widget.isOnboarding) ...[
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Hoàn tất hồ sơ sau khi đăng ký',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Thêm vài thông tin cơ bản để Edly gợi ý lộ trình học phù hợp.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.92),
                    height: 1.45,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (_isRefreshingOptions || _isSubmitting)
          const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ProfileSummaryCard(profile: profile),
                  const SizedBox(height: 16),
                  _ProfileActionGrid(
                    isStaff:
                        AuthRepository.instance.currentUser?.isStaff ?? false,
                    onActionTap: _handleProfileAction,
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: 'Thông tin cơ bản',
                    child: Column(
                      children: [
                        _FieldLabel('Họ và tên'),
                        const SizedBox(height: 10),
                        _ProfileTextField(
                          controller: _nameController,
                          hintText: 'Nhập họ và tên',
                          textInputAction: TextInputAction.next,
                          errorText: _fieldErrors['name'],
                          onChanged: (_) => _clearFieldError('name'),
                          validator: (_) {
                            if (_nameController.text.trim().isEmpty) {
                              return 'Vui lòng nhập họ và tên.';
                            }

                            if (_nameController.text.trim().length > 100) {
                              return 'Họ và tên tối đa 100 ký tự.';
                            }

                            return null;
                          },
                        ),
                        if (form.email.enabled) ...[
                          const SizedBox(height: 16),
                          _FieldLabel('Email'),
                          const SizedBox(height: 10),
                          _ProfileTextField(
                            controller: _emailController,
                            hintText: 'Nhập địa chỉ email',
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            enabled: form.email.editable,
                            errorText: _fieldErrors['email'],
                            onChanged: (_) => _clearFieldError('email'),
                            validator: (_) {
                              if (!form.email.editable ||
                                  !form.email.required) {
                                return null;
                              }

                              final email = _emailController.text.trim();
                              if (email.isEmpty) {
                                return 'Vui lòng nhập email.';
                              }

                              final emailPattern = RegExp(
                                r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                              );
                              if (!emailPattern.hasMatch(email)) {
                                return 'Địa chỉ email không đúng định dạng.';
                              }

                              return null;
                            },
                          ),
                        ],
                        if (form.userType.enabled) ...[
                          const SizedBox(height: 16),
                          _FieldLabel('Bạn đang là?'),
                          const SizedBox(height: 10),
                          _ProfileSelectField<String>(
                            value: _selectedUserType,
                            hintText: 'Chọn loại tài khoản',
                            errorText: _fieldErrors['user_type'],
                            items: form.userTypeOptions
                                .map(
                                  (option) => DropdownMenuItem<String>(
                                    value: option.value,
                                    child: Text(option.label),
                                  ),
                                )
                                .toList(growable: false),
                            onChanged: _isRefreshingOptions
                                ? null
                                : (value) {
                                    setState(() {
                                      _selectedUserType = value;
                                    });
                                    _clearFieldError('user_type');
                                  },
                            validator: (value) {
                              if (!form.userType.required ||
                                  !form.userType.enabled) {
                                return null;
                              }
                              if (value == null || value.isEmpty) {
                                return 'Vui lòng chọn.';
                              }
                              return null;
                            },
                          ),
                        ],
                        if (form.birthday.enabled) ...[
                          const SizedBox(height: 16),
                          _FieldLabel('Năm sinh'),
                          const SizedBox(height: 10),
                          _ProfileSelectField<String>(
                            value: _selectedBirthday,
                            hintText: 'Chọn năm sinh',
                            errorText: _fieldErrors['birthday'],
                            items: form.birthYearOptions
                                .map(
                                  (option) => DropdownMenuItem<String>(
                                    value: option.value,
                                    child: Text(option.label),
                                  ),
                                )
                                .toList(growable: false),
                            onChanged: _isRefreshingOptions
                                ? null
                                : (value) {
                                    setState(() {
                                      _selectedBirthday = value;
                                    });
                                    _clearFieldError('birthday');
                                  },
                            validator: (value) {
                              if (!form.birthday.required ||
                                  !form.birthday.enabled) {
                                return null;
                              }
                              if (value == null || value.isEmpty) {
                                return 'Vui lòng chọn năm sinh.';
                              }
                              return null;
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (form.province.enabled ||
                      form.district.enabled ||
                      form.school.enabled) ...[
                    const SizedBox(height: 16),
                    _SectionCard(
                      title: 'Khu vực học tập',
                      child: Column(
                        children: [
                          if (form.province.enabled) ...[
                            _FieldLabel('Tỉnh/Thành phố'),
                            const SizedBox(height: 10),
                            _ProfileSelectField<int>(
                              value: _selectedProvinceId,
                              hintText: 'Chọn Tỉnh/Thành phố',
                              errorText: _fieldErrors['province_id'],
                              items: form.provinceOptions
                                  .map(
                                    (option) => DropdownMenuItem<int>(
                                      value: option.id,
                                      child: Text(option.name),
                                    ),
                                  )
                                  .toList(growable: false),
                              onChanged: _isRefreshingOptions
                                  ? null
                                  : (value) async {
                                      setState(() {
                                        _selectedProvinceId = value;
                                        _selectedDistrictId = null;
                                        _selectedSchoolId = null;
                                      });
                                      _clearFieldError('province_id');
                                      _clearFieldError('district_id');
                                      _clearFieldError('school_id');
                                      await _reloadLocationOptions(
                                        provinceId: value,
                                      );
                                    },
                              validator: (value) {
                                if (!form.province.required ||
                                    !form.province.enabled) {
                                  return null;
                                }
                                if (value == null) {
                                  return 'Vui lòng chọn Tỉnh/Thành phố.';
                                }
                                return null;
                              },
                            ),
                          ],
                          if (form.district.enabled) ...[
                            const SizedBox(height: 16),
                            _FieldLabel('Quận/Huyện'),
                            const SizedBox(height: 10),
                            _ProfileSelectField<int>(
                              value: _selectedDistrictId,
                              hintText: 'Chọn Quận/Huyện',
                              errorText: _fieldErrors['district_id'],
                              items: form.districtOptions
                                  .map(
                                    (option) => DropdownMenuItem<int>(
                                      value: option.id,
                                      child: Text(option.name),
                                    ),
                                  )
                                  .toList(growable: false),
                              onChanged: _isRefreshingOptions
                                  ? null
                                  : (value) async {
                                      setState(() {
                                        _selectedDistrictId = value;
                                        _selectedSchoolId = null;
                                      });
                                      _clearFieldError('district_id');
                                      _clearFieldError('school_id');
                                      await _reloadLocationOptions(
                                        provinceId: _selectedProvinceId,
                                        districtId: value,
                                      );
                                    },
                              validator: (value) {
                                if (!form.district.required ||
                                    !form.district.enabled) {
                                  return null;
                                }
                                if (value == null) {
                                  return 'Vui lòng chọn Quận/Huyện.';
                                }
                                return null;
                              },
                            ),
                          ],
                          if (form.school.enabled) ...[
                            const SizedBox(height: 16),
                            _FieldLabel('Trường học'),
                            const SizedBox(height: 10),
                            _ProfileSelectField<int>(
                              value: _selectedSchoolId,
                              hintText: 'Chọn trường học',
                              errorText: _fieldErrors['school_id'],
                              items: form.schoolOptions
                                  .map(
                                    (option) => DropdownMenuItem<int>(
                                      value: option.id,
                                      child: Text(option.name),
                                    ),
                                  )
                                  .toList(growable: false),
                              onChanged: _isRefreshingOptions
                                  ? null
                                  : (value) {
                                      setState(() {
                                        _selectedSchoolId = value;
                                      });
                                      _clearFieldError('school_id');
                                    },
                              validator: (value) {
                                if (!form.school.required ||
                                    !form.school.enabled) {
                                  return null;
                                }
                                if (value == null) {
                                  return 'Vui lòng chọn trường học.';
                                }
                                return null;
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    _InlineErrorNotice(message: _errorMessage!),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0F67F4),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
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
                          : Text(
                              widget.isOnboarding ? 'HOÀN TẤT' : 'LƯU THAY ĐỔI',
                              style: const TextStyle(
                                fontSize: 15,
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
      ],
    );
  }
}

class _ProfileSummaryCard extends StatelessWidget {
  const _ProfileSummaryCard({required this.profile});

  final AccountProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F3)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 18,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFE7F0FF),
              borderRadius: BorderRadius.circular(18),
            ),
            alignment: Alignment.center,
            child: Text(
              _initialsFromName(profile.name),
              style: theme.textTheme.titleLarge?.copyWith(
                color: const Color(0xFF0F67F4),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.name.isEmpty ? 'Tài khoản Edly' : profile.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF17233A),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  profile.phone ?? 'Chưa có số điện thoại',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF61708A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (profile.roleName != null &&
                    profile.roleName!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    profile.roleName!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF7A879C),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _initialsFromName(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .toList();

    if (parts.isEmpty) {
      return 'E';
    }

    return parts.map((part) => part.substring(0, 1).toUpperCase()).join();
  }
}

class _ProfileActionGrid extends StatelessWidget {
  const _ProfileActionGrid({required this.isStaff, required this.onActionTap});

  final bool isStaff;
  final ValueChanged<String> onActionTap;

  @override
  Widget build(BuildContext context) {
    final actions = <_ProfileActionData>[
      const _ProfileActionData(
        title: 'Đổi mật khẩu',
        icon: Icons.lock_reset_rounded,
      ),
      const _ProfileActionData(
        title: 'Quản lý thiết bị',
        icon: Icons.devices_other_rounded,
      ),
      const _ProfileActionData(
        title: 'Gói đã mua',
        icon: Icons.shopping_bag_outlined,
      ),
      const _ProfileActionData(
        title: 'Tiến độ học tập',
        icon: Icons.bar_chart_rounded,
      ),
      if (isStaff)
        const _ProfileActionData(
          title: 'Thông tin thanh toán',
          icon: Icons.receipt_long_rounded,
        ),
    ];

    return _SectionCard(
      title: 'Chức năng tài khoản',
      child: Column(
        children: [
          for (var index = 0; index < actions.length; index++) ...[
            _ProfileActionTile(
              data: actions[index],
              onTap: () => onActionTap(actions[index].title),
            ),
            if (index < actions.length - 1)
              const Divider(height: 1, color: Color(0xFFE2E8F3)),
          ],
        ],
      ),
    );
  }
}

class _ProfileActionData {
  const _ProfileActionData({required this.title, required this.icon});

  final String title;
  final IconData icon;
}

class _ProfileActionTile extends StatelessWidget {
  const _ProfileActionTile({required this.data, required this.onTap});

  final _ProfileActionData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFE7F0FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(data.icon, color: const Color(0xFF0F67F4)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  data.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF17233A),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF8A96AA)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              color: const Color(0xFF17233A),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: const Color(0xFF17233A),
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _ProfileTextField extends StatelessWidget {
  const _ProfileTextField({
    required this.controller,
    required this.hintText,
    this.keyboardType,
    this.textInputAction,
    this.enabled = true,
    this.validator,
    this.errorText,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hintText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool enabled;
  final String? Function(String?)? validator;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      enabled: enabled,
      validator: validator,
      forceErrorText: errorText,
      onChanged: onChanged,
      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: const Color(0xFF17233A),
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        filled: true,
        fillColor: enabled ? const Color(0xFFF7F9FD) : const Color(0xFFF1F4F8),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFD9E2F0)),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFDDE5F1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF0F67F4), width: 1.2),
        ),
        errorMaxLines: 2,
      ),
    );
  }
}

class _ProfileSelectField<T> extends StatelessWidget {
  const _ProfileSelectField({
    required this.value,
    required this.hintText,
    required this.items,
    this.errorText,
    this.onChanged,
    this.validator,
  });

  final T? value;
  final String hintText;
  final List<DropdownMenuItem<T>> items;
  final String? errorText;
  final ValueChanged<T?>? onChanged;
  final String? Function(T?)? validator;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      key: ValueKey<T?>(value),
      initialValue: value,
      items: items,
      onChanged: onChanged,
      validator: validator,
      decoration: InputDecoration(
        filled: true,
        fillColor: onChanged == null
            ? const Color(0xFFF1F4F8)
            : const Color(0xFFF7F9FD),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFD9E2F0)),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFDDE5F1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF0F67F4), width: 1.2),
        ),
        errorText: errorText,
        errorMaxLines: 2,
      ),
      hint: Text(hintText),
      icon: const Icon(Icons.expand_more_rounded),
      isExpanded: true,
      borderRadius: BorderRadius.circular(18),
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: const Color(0xFF17233A),
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _InlineErrorNotice extends StatelessWidget {
  const _InlineErrorNotice({required this.message});

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

class _ProfileErrorState extends StatelessWidget {
  const _ProfileErrorState({required this.message, required this.onRetry});

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
            FilledButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}
