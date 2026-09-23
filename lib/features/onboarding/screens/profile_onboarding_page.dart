import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../services/profile_storage_service.dart';
import '../widgets/onboarding_primary_button.dart';
import '../widgets/onboarding_progress_indicator.dart';

class ProfileInputRules {
  static String normalizeUsername(String value) => value.trim().toLowerCase();

  static String? validateDisplayName(String value) {
    final length = value.trim().runes.length;
    if (length < 2 || length > 40) {
      return 'İsim 2–40 karakter arasında olmalı.';
    }
    return null;
  }

  static String? validateUsername(String value) {
    final normalized = normalizeUsername(value);
    if (normalized.length < 3 || normalized.length > 20) {
      return 'Kullanıcı adı 3–20 karakter olmalı.';
    }
    if (!RegExp(r'^[a-z0-9_.]+$').hasMatch(normalized)) {
      return 'Yalnızca a-z, 0-9, _ ve . kullanabilirsin.';
    }
    return null;
  }
}

class ProfileOnboardingPage extends StatefulWidget {
  const ProfileOnboardingPage({
    super.key,
    required this.onContinue,
    this.profileLoader,
    this.saveProfile,
  });

  final VoidCallback onContinue;
  final Future<ProfileStorageService> Function()? profileLoader;
  final Future<void> Function(String displayName, String username)? saveProfile;

  @override
  State<ProfileOnboardingPage> createState() => _ProfileOnboardingPageState();
}

class _ProfileOnboardingPageState extends State<ProfileOnboardingPage> {
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _nameFocus = FocusNode();
  final _usernameFocus = FocusNode();
  final _formScrollController = ScrollController();
  bool _keyboardWasOpen = false;
  ProfileStorageService? _profile;
  bool _nameTouched = false;
  bool _usernameTouched = false;
  bool _saving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_refresh);
    _usernameController.addListener(_normalizeUsername);
    _loadExistingProfile();
  }

  Future<void> _loadExistingProfile() async {
    if (widget.saveProfile != null && widget.profileLoader == null) return;
    try {
      final profile =
          await (widget.profileLoader ?? ProfileStorageService.open)();
      if (!mounted) return;
      _profile = profile;
      if (_nameController.text.isEmpty) {
        _nameController.text = profile.name ?? '';
      }
      if (_usernameController.text.isEmpty) {
        _usernameController.text = profile.username ?? '';
      }
    } catch (_) {
      if (mounted) setState(() => _saveError = 'Profil bilgileri yüklenemedi.');
    }
  }

  void _refresh() {
    if (mounted) setState(() => _saveError = null);
  }

  void _normalizeUsername() {
    final normalized = _usernameController.text.toLowerCase();
    if (normalized != _usernameController.text) {
      _usernameController.value = _usernameController.value.copyWith(
        text: normalized,
        selection: TextSelection.collapsed(offset: normalized.length),
        composing: TextRange.empty,
      );
      return;
    }
    _refresh();
  }

  String? get _nameError =>
      ProfileInputRules.validateDisplayName(_nameController.text);
  String? get _usernameError =>
      ProfileInputRules.validateUsername(_usernameController.text);
  bool get _valid => _nameError == null && _usernameError == null;

  Future<void> _submit() async {
    if (_saving) return;
    setState(() {
      _nameTouched = true;
      _usernameTouched = true;
      _saveError = null;
    });
    if (!_valid) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    final name = _nameController.text.trim();
    final username = ProfileInputRules.normalizeUsername(
      _usernameController.text,
    );
    try {
      if (widget.saveProfile != null) {
        await widget.saveProfile!(name, username);
      } else {
        final profile =
            _profile ??
            await (widget.profileLoader ?? ProfileStorageService.open)();
        await profile.saveProfile(displayName: name, username: username);
      }
      if (mounted) widget.onContinue();
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveError = 'Profil kaydedilemedi. Lütfen tekrar dene.';
        });
      }
    }
  }

  void _skip() {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    widget.onContinue();
  }

  @override
  void dispose() {
    _nameController
      ..removeListener(_refresh)
      ..dispose();
    _usernameController
      ..removeListener(_normalizeUsername)
      ..dispose();
    _nameFocus.dispose();
    _usernameFocus.dispose();
    _formScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final keyboardOpen = keyboardInset > 0;
    if (_keyboardWasOpen && !keyboardOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_formScrollController.hasClients) {
          _formScrollController.jumpTo(0);
        }
      });
    }
    _keyboardWasOpen = keyboardOpen;
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/onboarding/profile_background_phone.png',
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
        ),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [.3, .56, 1],
                colors: [
                  Colors.transparent,
                  Color(0x50020B18),
                  Color(0xEE020B18),
                ],
              ),
            ),
          ),
        ),
        SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final height = constraints.maxHeight;
              final compact = height < 720;
              final horizontalPadding = (width * .08).clamp(24.0, 40.0);
              return Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  height * .035,
                  horizontalPadding,
                  compact ? 14 : 22,
                ),
                child: Column(
                  children: [
                    Image.asset(
                      'assets/onboarding/driveit_wordmark.png',
                      width: width * .37,
                      fit: BoxFit.contain,
                    ),
                    SizedBox(height: compact ? 16 : height * .035),
                    Text(
                      'Seni Tanıyalım',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: (width * .078).clamp(28.0, 35.0),
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.6,
                        height: 1,
                      ),
                    ),
                    SizedBox(height: compact ? 7 : 10),
                    Text(
                      'DriveIt deneyimini kişiselleştirmek için bir isim ve kullanıcı adı belirle.',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .7),
                        fontSize: compact ? 11.5 : 13,
                        height: 1.3,
                      ),
                    ),
                    SizedBox(height: compact ? 10 : 14),
                    Expanded(
                      child: AnimatedPadding(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeInOut,
                        padding: EdgeInsets.only(
                          bottom: keyboardOpen ? keyboardInset : 0,
                        ),
                        child: LayoutBuilder(
                          builder: (context, formConstraints) {
                            final keyboardPadding = keyboardOpen ? 12.0 : 0.0;
                            return SingleChildScrollView(
                              controller: _formScrollController,
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              padding: EdgeInsets.only(
                                top: keyboardOpen ? 8 : 0,
                                bottom: keyboardPadding,
                              ),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight:
                                      (formConstraints.maxHeight -
                                              keyboardPadding)
                                          .clamp(
                                            0.0,
                                            formConstraints.maxHeight,
                                          ),
                                ),
                                child: Column(
                                  mainAxisAlignment: keyboardOpen
                                      ? MainAxisAlignment.start
                                      : MainAxisAlignment.end,
                                  children: [
                                    _label('İsim'),
                                    const SizedBox(height: 7),
                                    TextField(
                                      key: const ValueKey('profile_name_input'),
                                      controller: _nameController,
                                      focusNode: _nameFocus,
                                      maxLength: 40,
                                      textCapitalization:
                                          TextCapitalization.words,
                                      textInputAction: TextInputAction.next,
                                      onSubmitted: (_) =>
                                          _usernameFocus.requestFocus(),
                                      onChanged: (_) {
                                        if (!_nameTouched) {
                                          setState(() => _nameTouched = true);
                                        }
                                      },
                                      decoration: _inputDecoration(
                                        hint: 'Adın',
                                        error: _nameTouched ? _nameError : null,
                                      ),
                                    ),
                                    SizedBox(height: compact ? 6 : 9),
                                    _label('Kullanıcı Adı'),
                                    const SizedBox(height: 7),
                                    TextField(
                                      key: const ValueKey(
                                        'profile_username_input',
                                      ),
                                      controller: _usernameController,
                                      focusNode: _usernameFocus,
                                      maxLength: 20,
                                      autocorrect: false,
                                      enableSuggestions: false,
                                      keyboardType: TextInputType.text,
                                      textInputAction: TextInputAction.done,
                                      inputFormatters: const [
                                        _LowercaseFormatter(),
                                      ],
                                      onSubmitted: (_) {
                                        FocusScope.of(context).unfocus();
                                        if (_valid) _submit();
                                      },
                                      onChanged: (_) {
                                        if (!_usernameTouched) {
                                          setState(
                                            () => _usernameTouched = true,
                                          );
                                        }
                                      },
                                      decoration: _inputDecoration(
                                        hint: 'kullanıcıadı',
                                        prefix: '@',
                                        error: _usernameTouched
                                            ? _usernameError
                                            : null,
                                      ),
                                    ),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        'Kullanıcı adını daha sonra profilinden değiştirebilirsin.',
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: .56,
                                          ),
                                          fontSize: compact ? 10 : 11,
                                        ),
                                      ),
                                    ),
                                    if (_saveError != null) ...[
                                      const SizedBox(height: 7),
                                      Text(
                                        _saveError!,
                                        style: const TextStyle(
                                          color: Color(0xFFFF8A8A),
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                    SizedBox(height: compact ? 13 : 18),
                                    FractionallySizedBox(
                                      widthFactor: .913,
                                      child: IgnorePointer(
                                        ignoring: !_valid || _saving,
                                        child: AnimatedOpacity(
                                          opacity: _valid && !_saving ? 1 : .46,
                                          duration: const Duration(
                                            milliseconds: 180,
                                          ),
                                          child: OnboardingPrimaryButton(
                                            label: _saving
                                                ? 'Kaydediliyor'
                                                : 'Profilimi Oluştur',
                                            onPressed: _submit,
                                          ),
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      key: const ValueKey('skip_profile'),
                                      onPressed: _saving ? null : _skip,
                                      child: const Text(
                                        'Şimdilik Geç',
                                        style: TextStyle(
                                          color: Color(0xFFB7C9D8),
                                        ),
                                      ),
                                    ),
                                    const OnboardingProgressIndicator(
                                      currentPage: 5,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _label(String value) => Align(
    alignment: Alignment.centerLeft,
    child: Text(
      value,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  InputDecoration _inputDecoration({
    required String hint,
    String? prefix,
    String? error,
  }) {
    const borderColor = Color(0xFF345976);
    return InputDecoration(
      hintText: hint,
      prefixText: prefix,
      errorText: error,
      counterText: '',
      filled: true,
      fillColor: const Color(0xCC071522),
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: .4)),
      prefixStyle: const TextStyle(
        color: Color(0xFF2DA9FF),
        fontWeight: FontWeight.w800,
        fontSize: 17,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF1A9BFF), width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFFF6B78)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFFF6B78), width: 1.4),
      ),
    );
  }
}

class _LowercaseFormatter extends TextInputFormatter {
  const _LowercaseFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final lowered = newValue.text.toLowerCase();
    return newValue.copyWith(
      text: lowered,
      selection: TextSelection.collapsed(offset: lowered.length),
      composing: TextRange.empty,
    );
  }
}
