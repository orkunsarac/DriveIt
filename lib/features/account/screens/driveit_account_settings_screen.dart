import 'dart:async';

import 'package:flutter/material.dart';

import '../../../services/supabase_account_service.dart';

class DriveItAccountSettingsScreen extends StatefulWidget {
  const DriveItAccountSettingsScreen({super.key, this.accountGateway});

  final DriveItAccountGateway? accountGateway;

  @override
  State<DriveItAccountSettingsScreen> createState() =>
      _DriveItAccountSettingsScreenState();
}

class _DriveItAccountSettingsScreenState
    extends State<DriveItAccountSettingsScreen> {
  static const _blue = Color(0xff248fff);
  static const _surface = Color(0xff07162b);
  late final DriveItAccountGateway _service;
  late final TextEditingController _displayName;
  late final TextEditingController _username;
  late final TextEditingController _currentPassword;
  late final TextEditingController _newPassword;
  late final TextEditingController _newPasswordRepeat;
  Timer? _usernameTimer;
  int _usernameRequest = 0;
  DriveItAccountProfile? _profile;
  String _originalDisplayName = '';
  String _originalUsername = '';
  String? _profileError;
  String? _usernameError;
  String? _passwordError;
  bool? _usernameAvailable;
  bool _usernameChecking = false;
  bool _usernameCheckFailed = false;
  bool _loading = true;
  bool _savingProfile = false;
  bool _changingPassword = false;
  bool _normalizingUsername = false;

  @override
  void initState() {
    super.initState();
    _service = widget.accountGateway ?? SupabaseAccountService.instance;
    _displayName = TextEditingController();
    _username = TextEditingController()..addListener(_onUsernameChanged);
    _currentPassword = TextEditingController();
    _newPassword = TextEditingController();
    _newPasswordRepeat = TextEditingController();
    _loadProfile();
  }

  @override
  void dispose() {
    _usernameTimer?.cancel();
    _displayName.dispose();
    _username
      ..removeListener(_onUsernameChanged)
      ..dispose();
    _currentPassword.dispose();
    _newPassword.dispose();
    _newPasswordRepeat.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    if (!_service.isAvailable || !_service.hasSession) {
      if (mounted) {
        setState(() {
          _loading = false;
          _profileError =
              'Bu ekranı kullanmak için DriveIt hesabına giriş yap.';
        });
      }
      return;
    }
    setState(() {
      _loading = true;
      _profileError = null;
    });
    try {
      final profile = await _service.fetchCurrentProfile();
      if (!mounted) return;
      if (profile == null) {
        setState(() {
          _loading = false;
          _profileError = 'Hesap bilgileri alınamadı. Yeniden deneyebilirsin.';
        });
        return;
      }
      _normalizingUsername = true;
      _displayName.text = profile.displayName?.trim() ?? '';
      _username.text = AccountInputRules.normalizeUsername(
        profile.username ?? '',
      );
      _normalizingUsername = false;
      setState(() {
        _profile = profile;
        _originalDisplayName = profile.displayName?.trim() ?? '';
        _originalUsername = AccountInputRules.normalizeUsername(
          profile.username ?? '',
        );
        _usernameAvailable = true;
        _usernameChecking = false;
        _usernameCheckFailed = false;
        _loading = false;
      });
    } catch (_) {
      _normalizingUsername = false;
      if (mounted) {
        setState(() {
          _loading = false;
          _profileError = 'Hesap bilgileri alınamadı. Yeniden deneyebilirsin.';
        });
      }
    }
  }

  void _onUsernameChanged() {
    if (_loading || _normalizingUsername || !mounted) return;
    var normalized = AccountInputRules.normalizeUsername(_username.text);
    if (normalized != _username.text) {
      _normalizingUsername = true;
      _username.value = _username.value.copyWith(
        text: normalized,
        selection: TextSelection.collapsed(offset: normalized.length),
        composing: TextRange.empty,
      );
      _normalizingUsername = false;
    }
    _usernameTimer?.cancel();
    final request = ++_usernameRequest;
    if (normalized == _originalUsername) {
      setState(() {
        _usernameError = null;
        _usernameAvailable = true;
        _usernameChecking = false;
        _usernameCheckFailed = false;
      });
      return;
    }
    final validation = AccountInputRules.validateUsername(normalized);
    if (validation != null) {
      setState(() {
        _usernameError = validation;
        _usernameAvailable = null;
        _usernameChecking = false;
        _usernameCheckFailed = false;
      });
      return;
    }
    setState(() {
      _usernameError = null;
      _usernameAvailable = null;
      _usernameChecking = true;
      _usernameCheckFailed = false;
    });
    _usernameTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        final available = await _service.isUsernameAvailable(normalized);
        if (!mounted || request != _usernameRequest) return;
        setState(() {
          _usernameAvailable = available;
          _usernameChecking = false;
          _usernameCheckFailed = false;
          _usernameError = available ? null : 'Bu kullanıcı adı kullanımda.';
        });
      } catch (_) {
        if (!mounted || request != _usernameRequest) return;
        setState(() {
          _usernameAvailable = null;
          _usernameChecking = false;
          _usernameCheckFailed = true;
          _usernameError = 'Kullanıcı adı şu anda kontrol edilemiyor.';
        });
      }
    });
  }

  String? get _usernameStatus {
    final state = AccountUsernameAvailability.resolve(
      username: _username.text,
      checking: _usernameChecking,
      available: _usernameAvailable,
      checkFailed: _usernameCheckFailed,
    );
    return switch (state) {
      AccountUsernameStatus.invalid => _usernameError,
      AccountUsernameStatus.checking => 'Kontrol ediliyor…',
      AccountUsernameStatus.available => 'Kullanılabilir',
      AccountUsernameStatus.taken => 'Bu kullanıcı adı kullanımda.',
      AccountUsernameStatus.unavailable => 'Kullanıcı adı kontrol edilemedi.',
    };
  }

  Color get _usernameStatusColor {
    if (_usernameChecking) return Colors.white60;
    if (_usernameAvailable == true) return const Color(0xff69e4b1);
    return const Color(0xffff8a8a);
  }

  bool get _profileCanSave =>
      !_loading &&
      !_savingProfile &&
      _service.hasSession &&
      (_username.text.trim().toLowerCase() == _originalUsername ||
          _usernameAvailable == true);

  Future<void> _saveProfile() async {
    final displayError = AccountInputRules.validateDisplayName(
      _displayName.text,
    );
    final normalizedUsername = AccountInputRules.normalizeUsername(
      _username.text,
    );
    final usernameError = AccountInputRules.validateUsername(
      normalizedUsername,
    );
    if (displayError != null || usernameError != null) {
      setState(() {
        _profileError = displayError ?? usernameError;
      });
      return;
    }
    final usernameChanged = normalizedUsername != _originalUsername;
    if (usernameChanged && _usernameAvailable != true) {
      setState(() {
        _profileError = _usernameError ?? 'Kullanıcı adını kontrol et.';
      });
      return;
    }
    setState(() {
      _savingProfile = true;
      _profileError = null;
    });
    try {
      var profile = _profile!;
      if (usernameChanged) {
        profile = await _service.updateUsername(normalizedUsername);
        _originalUsername = normalizedUsername;
      }
      final normalizedName = _displayName.text.trim();
      if (normalizedName != _originalDisplayName) {
        profile = await _service.updateDisplayName(normalizedName);
        _originalDisplayName = normalizedName;
      }
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _profileError = null;
        _usernameAvailable = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil bilgilerin güncellendi.')),
      );
    } on AccountServiceException catch (error) {
      if (mounted) setState(() => _profileError = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _profileError =
              'Profil bilgileri kaydedilemedi. Tekrar deneyebilirsin.',
        );
      }
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _changePassword() async {
    final error =
        AccountInputRules.validateCurrentPassword(_currentPassword.text) ??
        AccountInputRules.validatePassword(_newPassword.text) ??
        AccountInputRules.validatePasswordConfirmation(
          _newPassword.text,
          _newPasswordRepeat.text,
        );
    if (error != null) {
      setState(() => _passwordError = error);
      return;
    }
    setState(() {
      _changingPassword = true;
      _passwordError = null;
    });
    try {
      await _service.changePassword(
        currentPassword: _currentPassword.text,
        newPassword: _newPassword.text,
      );
      if (!mounted) return;
      _currentPassword.clear();
      _newPassword.clear();
      _newPasswordRepeat.clear();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Şifren güncellendi.')));
    } on AccountServiceException catch (error) {
      if (mounted) setState(() => _passwordError = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _passwordError =
              'Şifre değiştirilemedi. Bilgilerini kontrol edip tekrar dene.',
        );
      }
    } finally {
      if (mounted) setState(() => _changingPassword = false);
    }
  }

  Widget _section(String title, List<Widget> children) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xff315071), width: .75),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        ...children,
      ],
    ),
  );

  InputDecoration _inputDecoration(String label, {String? prefixText}) =>
      InputDecoration(
        labelText: label,
        prefixText: prefixText,
        filled: true,
        fillColor: const Color(0xff020a18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xff315071)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _blue),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xff020a18),
    appBar: AppBar(
      title: const Text('DriveIt Hesap Ayarları'),
      backgroundColor: const Color(0xff020a18),
      surfaceTintColor: Colors.transparent,
    ),
    body: SafeArea(
      child: _loading
          ? const Center(child: CircularProgressIndicator(color: _blue))
          : !_service.isAvailable || !_service.hasSession || _profile == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _profileError ?? 'DriveIt hesabına giriş yapılmamış.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _section('Profil', [
                        TextField(
                          key: const ValueKey('account_settings_display_name'),
                          controller: _displayName,
                          textCapitalization: TextCapitalization.words,
                          maxLength: 40,
                          decoration: _inputDecoration('Görünen Ad'),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          key: const ValueKey('account_settings_username'),
                          controller: _username,
                          autocorrect: false,
                          enableSuggestions: false,
                          decoration:
                              _inputDecoration(
                                'Kullanıcı Adı',
                                prefixText: '@',
                              ).copyWith(
                                errorText: _usernameError,
                                helperText: _usernameStatus,
                                helperStyle: TextStyle(
                                  color: _usernameStatusColor,
                                ),
                              ),
                        ),
                        if (_profileError != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _profileError!,
                            key: const ValueKey(
                              'account_settings_profile_error',
                            ),
                            style: const TextStyle(color: Color(0xffff8a8a)),
                          ),
                        ],
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 50,
                          child: FilledButton(
                            key: const ValueKey(
                              'account_settings_save_profile',
                            ),
                            onPressed: _profileCanSave ? _saveProfile : null,
                            style: FilledButton.styleFrom(
                              backgroundColor: _blue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: _savingProfile
                                ? const SizedBox.square(
                                    dimension: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Değişiklikleri Kaydet'),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 18),
                      _section('Güvenlik', [
                        TextField(
                          key: const ValueKey(
                            'account_settings_current_password',
                          ),
                          controller: _currentPassword,
                          obscureText: true,
                          autofillHints: const [AutofillHints.password],
                          decoration: _inputDecoration('Mevcut Şifre'),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          key: const ValueKey('account_settings_new_password'),
                          controller: _newPassword,
                          obscureText: true,
                          decoration: _inputDecoration('Yeni Şifre'),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          key: const ValueKey(
                            'account_settings_new_password_repeat',
                          ),
                          controller: _newPasswordRepeat,
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) =>
                              _changingPassword ? null : _changePassword(),
                          decoration: _inputDecoration('Yeni Şifre Tekrar'),
                        ),
                        if (_passwordError != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _passwordError!,
                            key: const ValueKey(
                              'account_settings_password_error',
                            ),
                            style: const TextStyle(color: Color(0xffff8a8a)),
                          ),
                        ],
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 50,
                          child: OutlinedButton(
                            key: const ValueKey(
                              'account_settings_change_password',
                            ),
                            onPressed: _changingPassword
                                ? null
                                : _changePassword,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Color(0xff315071)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: _changingPassword
                                ? const SizedBox.square(
                                    dimension: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Şifreyi Değiştir'),
                          ),
                        ),
                      ]),
                    ],
                  ),
                ),
              ),
            ),
    ),
  );
}
