import 'dart:async';

import 'package:flutter/material.dart';

import '../../../services/supabase_account_service.dart';

enum DriveItAccountMode { choices, create, login, resetPassword, confirmation }

/// Shared onboarding and Profile-tab entry point for the optional cloud account.
class DriveItAccountScreen extends StatefulWidget {
  const DriveItAccountScreen({
    super.key,
    this.initialMode = DriveItAccountMode.choices,
    this.initialDisplayName,
    this.initialUsername,
    this.accountGateway,
  });

  final DriveItAccountMode initialMode;
  final String? initialDisplayName;
  final String? initialUsername;
  final DriveItAccountGateway? accountGateway;

  @override
  State<DriveItAccountScreen> createState() => _DriveItAccountScreenState();
}

class _DriveItAccountScreenState extends State<DriveItAccountScreen> {
  static const _blue = Color(0xff248fff);
  static const _surface = Color(0xff07162b);
  late final DriveItAccountGateway _service;
  late DriveItAccountMode _mode;
  late final TextEditingController _displayName;
  late final TextEditingController _username;
  late final TextEditingController _email;
  late final TextEditingController _password;
  late final TextEditingController _passwordRepeat;
  Timer? _usernameTimer;
  int _usernameRequest = 0;
  bool _busy = false;
  bool? _usernameAvailable;
  String? _usernameError;
  bool _usernameChecking = false;
  bool _usernameCheckFailed = false;
  String? _error;
  bool _confirmationRequired = false;

  @override
  void initState() {
    super.initState();
    _service = widget.accountGateway ?? SupabaseAccountService.instance;
    _mode = widget.initialMode;
    _displayName = TextEditingController(text: widget.initialDisplayName);
    _username = TextEditingController(
      text: widget.initialUsername?.trim().toLowerCase(),
    )..addListener(_onUsernameChanged);
    _email = TextEditingController();
    _password = TextEditingController();
    _passwordRepeat = TextEditingController();
    if (_username.text.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scheduleUsernameCheck();
      });
    }
  }

  @override
  void dispose() {
    _usernameTimer?.cancel();
    _displayName.dispose();
    _username
      ..removeListener(_onUsernameChanged)
      ..dispose();
    _email.dispose();
    _password.dispose();
    _passwordRepeat.dispose();
    super.dispose();
  }

  void _setMode(DriveItAccountMode mode) {
    setState(() {
      _mode = mode;
      _error = null;
    });
  }

  void _scheduleUsernameCheck() {
    final normalized = AccountInputRules.normalizeUsername(_username.text);
    final validation = AccountInputRules.validateUsername(normalized);
    _usernameTimer?.cancel();
    _usernameRequest++;
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
    final request = _usernameRequest;
    _usernameTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        final available = await _service.isUsernameAvailable(normalized);
        if (!mounted || request != _usernameRequest) return;
        setState(() {
          _usernameAvailable = available;
          _usernameChecking = false;
        });
      } catch (_) {
        if (!mounted || request != _usernameRequest) return;
        setState(() {
          _usernameChecking = false;
          _usernameCheckFailed = true;
          _usernameError = 'Kullanıcı adı şu anda kontrol edilemiyor.';
        });
      }
    });
  }

  void _onUsernameChanged() {
    final normalized = _username.text.toLowerCase();
    if (normalized != _username.text) {
      _username.value = _username.value.copyWith(
        text: normalized,
        selection: TextSelection.collapsed(offset: normalized.length),
        composing: TextRange.empty,
      );
      return;
    }
    _scheduleUsernameCheck();
  }

  String? get _createFormError {
    return AccountInputRules.validateDisplayName(_displayName.text) ??
        AccountInputRules.validateUsername(_username.text) ??
        AccountInputRules.validateEmail(_email.text) ??
        AccountInputRules.validatePassword(_password.text) ??
        AccountInputRules.validatePasswordConfirmation(
          _password.text,
          _passwordRepeat.text,
        );
  }

  bool get _canSignUp =>
      !_busy &&
      _service.isAvailable &&
      _createFormError == null &&
      _usernameAvailable == true;

  Future<void> _createAccount() async {
    if (!_canSignUp) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final hasSession = await _service.signUp(
        displayName: _displayName.text.trim(),
        username: AccountInputRules.normalizeUsername(_username.text),
        email: _email.text.trim(),
        password: _password.text,
      );
      if (!mounted) return;
      if (hasSession) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _confirmationRequired = true;
          _mode = DriveItAccountMode.confirmation;
        });
      }
    } on AccountServiceException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Hesap oluşturulamadı. Tekrar dene.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signIn() async {
    final invalid =
        AccountInputRules.validateEmail(_email.text) ??
        AccountInputRules.validatePassword(_password.text);
    if (_busy || invalid != null || !_service.isAvailable) {
      setState(() => _error = invalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _service.signIn(email: _email.text, password: _password.text);
      if (mounted) Navigator.of(context).pop(true);
    } on AccountServiceException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Giriş yapılamadı. Tekrar dene.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendResetEmail() async {
    final invalid = AccountInputRules.validateEmail(_email.text);
    if (_busy || invalid != null || !_service.isAvailable) {
      setState(() => _error = invalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _service.resetPasswordForEmail(_email.text);
      if (mounted) {
        setState(() {
          _confirmationRequired = false;
          _mode = DriveItAccountMode.confirmation;
        });
      }
    } on AccountServiceException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'E-posta gönderilemedi. Tekrar dene.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _action({
    required String label,
    required VoidCallback? onPressed,
    bool primary = false,
    Key? key,
  }) => SizedBox(
    width: double.infinity,
    child: primary
        ? FilledButton(
            key: key,
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: _blue,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          )
        : OutlinedButton(
            key: key,
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Color(0xff315071)),
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(label),
          ),
  );

  InputDecoration _decoration(String label, {String? prefix, String? error}) =>
      InputDecoration(
        labelText: label,
        prefixText: prefix,
        errorText: error,
        filled: true,
        fillColor: const Color(0xff0b1c31),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xff315071)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _blue, width: 1.4),
        ),
      );

  Widget _availabilityLine() {
    final status = AccountUsernameAvailability.resolve(
      username: _username.text,
      checking: _usernameChecking,
      available: _usernameAvailable,
      checkFailed: _usernameCheckFailed,
    );
    final text = switch (status) {
      AccountUsernameStatus.invalid =>
        _usernameError ?? 'Kullanıcı adı geçersiz.',
      AccountUsernameStatus.checking => 'Kontrol ediliyor…',
      AccountUsernameStatus.available => 'Kullanılabilir',
      AccountUsernameStatus.taken => 'Kullanımda',
      AccountUsernameStatus.unavailable =>
        _usernameError ?? 'Kontrol edilemiyor.',
    };
    final color =
        status == AccountUsernameStatus.invalid ||
            status == AccountUsernameStatus.unavailable ||
            status == AccountUsernameStatus.taken
        ? const Color(0xffff8a8a)
        : status == AccountUsernameStatus.available
        ? const Color(0xff79e3b1)
        : Colors.white60;
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 4),
      child: Row(
        children: [
          if (status == AccountUsernameStatus.checking)
            const SizedBox(
              width: 13,
              height: 13,
              child: CircularProgressIndicator(strokeWidth: 1.5),
            )
          else
            Icon(
              _usernameAvailable == true
                  ? Icons.check_circle_outline
                  : Icons.info_outline,
              size: 15,
              color: color,
            ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text, style: TextStyle(color: color, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAvailable = _service.isAvailable;
    return Scaffold(
      backgroundColor: const Color(0xff020a18),
      appBar: AppBar(
        title: const Text('DriveIt Hesabı'),
        backgroundColor: const Color(0xff020a18),
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.cloud_outlined, color: _blue, size: 40),
                  const SizedBox(height: 12),
                  Text(
                    switch (_mode) {
                      DriveItAccountMode.create => 'Hesap Oluştur',
                      DriveItAccountMode.login => 'Giriş Yap',
                      DriveItAccountMode.resetPassword => 'Şifremi Unuttum',
                      DriveItAccountMode.confirmation => 'E-postanı Kontrol Et',
                      DriveItAccountMode.choices => 'DriveIt Hesabı',
                    },
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isAvailable
                        ? 'DriveIt Gezegeni ve çevrimiçi özellikler için hesabını bağla.'
                        : 'Çevrimiçi hesap hizmeti şu anda kullanılamıyor.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  if (!isAvailable)
                    _messageCard(
                      'Hesap işlemleri için DEV Supabase yapılandırması gerekir. Yerel sürüş ve profil verilerin kullanılmaya devam eder.',
                    )
                  else
                    _buildModeContent(),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _error!,
                      key: const ValueKey('account_error'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xffff8a8a)),
                    ),
                  ],
                  if (_mode != DriveItAccountMode.choices &&
                      _mode != DriveItAccountMode.confirmation) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => _setMode(DriveItAccountMode.choices),
                      child: const Text('Hesap seçeneklerine dön'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeContent() => switch (_mode) {
    DriveItAccountMode.choices => Column(
      children: [
        _action(
          label: 'Hesap Oluştur',
          primary: true,
          key: const ValueKey('account_create_choice'),
          onPressed: () => _setMode(DriveItAccountMode.create),
        ),
        const SizedBox(height: 10),
        _action(
          label: 'Giriş Yap',
          key: const ValueKey('account_login_choice'),
          onPressed: () => _setMode(DriveItAccountMode.login),
        ),
      ],
    ),
    DriveItAccountMode.create => _createForm(),
    DriveItAccountMode.login => _loginForm(),
    DriveItAccountMode.resetPassword => _resetForm(),
    DriveItAccountMode.confirmation => _confirmationCard(),
  };

  Widget _createForm() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextField(
        key: const ValueKey('account_display_name'),
        controller: _displayName,
        maxLength: 40,
        textCapitalization: TextCapitalization.words,
        decoration: _decoration(
          'Görünen ad',
          error: _displayName.text.isEmpty
              ? null
              : AccountInputRules.validateDisplayName(_displayName.text),
        ),
        onChanged: (_) => setState(() {}),
      ),
      TextField(
        key: const ValueKey('account_username'),
        controller: _username,
        maxLength: 20,
        autocorrect: false,
        enableSuggestions: false,
        decoration: _decoration('Kullanıcı adı', prefix: '@'),
      ),
      _availabilityLine(),
      const SizedBox(height: 12),
      TextField(
        key: const ValueKey('account_email'),
        controller: _email,
        keyboardType: TextInputType.emailAddress,
        autocorrect: false,
        decoration: _decoration(
          'E-posta',
          error: _email.text.isEmpty
              ? null
              : AccountInputRules.validateEmail(_email.text),
        ),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 12),
      TextField(
        key: const ValueKey('account_password'),
        controller: _password,
        obscureText: true,
        decoration: _decoration(
          'Şifre (en az 8 karakter)',
          error: _password.text.isEmpty
              ? null
              : AccountInputRules.validatePassword(_password.text),
        ),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 12),
      TextField(
        key: const ValueKey('account_password_repeat'),
        controller: _passwordRepeat,
        obscureText: true,
        decoration: _decoration(
          'Şifre tekrarı',
          error: _passwordRepeat.text.isEmpty
              ? null
              : AccountInputRules.validatePasswordConfirmation(
                  _password.text,
                  _passwordRepeat.text,
                ),
        ),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 18),
      _action(
        label: _busy ? 'Hesap oluşturuluyor…' : 'Hesap Oluştur',
        primary: true,
        key: const ValueKey('account_submit_create'),
        onPressed: _canSignUp ? _createAccount : null,
      ),
    ],
  );

  Widget _loginForm() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextField(
        key: const ValueKey('account_email'),
        controller: _email,
        keyboardType: TextInputType.emailAddress,
        autocorrect: false,
        decoration: _decoration(
          'E-posta',
          error: _email.text.isEmpty
              ? null
              : AccountInputRules.validateEmail(_email.text),
        ),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 12),
      TextField(
        key: const ValueKey('account_password'),
        controller: _password,
        obscureText: true,
        decoration: _decoration(
          'Şifre',
          error: _password.text.isEmpty
              ? null
              : AccountInputRules.validatePassword(_password.text),
        ),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _signIn(),
      ),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: () => _setMode(DriveItAccountMode.resetPassword),
          child: const Text('Şifremi Unuttum'),
        ),
      ),
      _action(
        label: _busy ? 'Giriş yapılıyor…' : 'Giriş Yap',
        primary: true,
        key: const ValueKey('account_submit_login'),
        onPressed:
            !_busy &&
                AccountInputRules.validateEmail(_email.text) == null &&
                AccountInputRules.validatePassword(_password.text) == null
            ? _signIn
            : null,
      ),
    ],
  );

  Widget _resetForm() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextField(
        key: const ValueKey('account_email'),
        controller: _email,
        keyboardType: TextInputType.emailAddress,
        decoration: _decoration('E-posta'),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 14),
      _action(
        label: _busy ? 'Gönderiliyor…' : 'Sıfırlama Bağlantısı Gönder',
        primary: true,
        key: const ValueKey('account_submit_reset'),
        onPressed:
            !_busy && AccountInputRules.validateEmail(_email.text) == null
            ? _sendResetEmail
            : null,
      ),
    ],
  );

  Widget _confirmationCard() => Column(
    children: [
      _messageCard(
        _confirmationRequired
            ? 'E-posta adresine doğrulama bağlantısı gönderdik. Hesabını doğruladıktan sonra giriş yapabilirsin.'
            : 'Şifre sıfırlama bağlantısı e-posta adresine gönderildiyse gelen kutunu kontrol et.',
      ),
      const SizedBox(height: 16),
      _action(
        label: 'Giriş Yap',
        primary: true,
        onPressed: () => _setMode(DriveItAccountMode.login),
      ),
      TextButton(
        onPressed: () => _setMode(DriveItAccountMode.choices),
        child: const Text('Geri dön'),
      ),
    ],
  );

  Widget _messageCard(String text) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xff315071)),
    ),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(height: 1.45),
    ),
  );
}
