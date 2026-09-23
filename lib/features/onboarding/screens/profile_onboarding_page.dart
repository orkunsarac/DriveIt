import 'package:flutter/material.dart';

import '../../../services/profile_storage_service.dart';
import '../../account/screens/driveit_account_screen.dart';
import '../widgets/onboarding_primary_button.dart';
import '../widgets/onboarding_progress_indicator.dart';

class ProfileOnboardingPage extends StatefulWidget {
  const ProfileOnboardingPage({
    super.key,
    required this.onContinue,
    this.profileLoader,
    // Retained as a source-compatible test seam. Cloud account creation does
    // not write into the local profile store.
    this.saveProfile,
  });

  final VoidCallback onContinue;
  final Future<ProfileStorageService> Function()? profileLoader;
  final Future<void> Function(String displayName, String username)? saveProfile;

  @override
  State<ProfileOnboardingPage> createState() => _ProfileOnboardingPageState();
}

class _ProfileOnboardingPageState extends State<ProfileOnboardingPage> {
  String? _localName;
  String? _localUsername;
  bool _loadingProfile = true;
  bool _openingAccount = false;

  @override
  void initState() {
    super.initState();
    _loadLocalProfile();
  }

  Future<void> _loadLocalProfile() async {
    try {
      final profile =
          await (widget.profileLoader ?? ProfileStorageService.open)();
      if (!mounted) return;
      setState(() {
        _localName = profile.name;
        _localUsername = profile.username;
        _loadingProfile = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  Future<void> _openAccount(DriveItAccountMode mode) async {
    if (_openingAccount) return;
    setState(() => _openingAccount = true);
    try {
      final authenticated = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => DriveItAccountScreen(
            initialMode: mode,
            initialDisplayName: _localName,
            initialUsername: _localUsername,
          ),
        ),
      );
      if (authenticated == true && mounted) widget.onContinue();
    } finally {
      if (mounted) setState(() => _openingAccount = false);
    }
  }

  @override
  Widget build(BuildContext context) => Stack(
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
                    'DriveIt deneyimini kişiselleştirmek için bir hesap oluştur veya giriş yap.',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .72),
                      fontSize: compact ? 11.5 : 13,
                      height: 1.3,
                    ),
                  ),
                  const Spacer(),
                  if (_loadingProfile)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  FractionallySizedBox(
                    widthFactor: .913,
                    child: OnboardingPrimaryButton(
                      label: _openingAccount ? 'Açılıyor…' : 'Hesap Oluştur',
                      onPressed: () {
                        if (!_openingAccount) {
                          _openAccount(DriveItAccountMode.create);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  FractionallySizedBox(
                    widthFactor: .913,
                    child: OutlinedButton(
                      key: const ValueKey('onboarding_account_login'),
                      onPressed: _openingAccount
                          ? null
                          : () => _openAccount(DriveItAccountMode.login),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0x9935A8FF)),
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Text('Giriş Yap'),
                    ),
                  ),
                  TextButton(
                    key: const ValueKey('skip_profile'),
                    onPressed: _openingAccount ? null : widget.onContinue,
                    child: const Text(
                      'Şimdilik Geç',
                      style: TextStyle(color: Color(0xFFB7C9D8)),
                    ),
                  ),
                  const OnboardingProgressIndicator(currentPage: 5),
                ],
              ),
            );
          },
        ),
      ),
    ],
  );
}
