import 'package:flutter/material.dart';

import '../../../screens/home_screen.dart';
import '../../../services/profile_storage_service.dart';
import '../widgets/onboarding_primary_button.dart';
import '../widgets/onboarding_progress_indicator.dart';

class ReadyOnboardingPage extends StatefulWidget {
  const ReadyOnboardingPage({
    super.key,
    this.profileLoader,
    this.profileReadyLoader,
    this.completionWriter,
    this.onEnterApp,
  });

  final Future<ProfileStorageService> Function()? profileLoader;
  final Future<bool> Function()? profileReadyLoader;
  final Future<void> Function()? completionWriter;
  final VoidCallback? onEnterApp;

  @override
  State<ReadyOnboardingPage> createState() => _ReadyOnboardingPageState();
}

class _ReadyOnboardingPageState extends State<ReadyOnboardingPage> {
  ProfileStorageService? _profile;
  bool? _profileReady;
  bool _finishing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfileStatus();
  }

  Future<ProfileStorageService> _loadProfile() async {
    return _profile ??=
        await (widget.profileLoader ?? ProfileStorageService.open)();
  }

  Future<void> _loadProfileStatus() async {
    try {
      final ready = widget.profileReadyLoader != null
          ? await widget.profileReadyLoader!()
          : (await _loadProfile()).hasCompleteProfile;
      if (mounted) setState(() => _profileReady = ready);
    } catch (_) {
      if (mounted) setState(() => _profileReady = false);
    }
  }

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() {
      _finishing = true;
      _error = null;
    });
    try {
      if (widget.completionWriter != null) {
        await widget.completionWriter!();
      } else {
        final profile = await _loadProfile();
        await profile.markOnboardingCompleted();
      }
      if (!mounted) return;
      if (widget.onEnterApp != null) {
        widget.onEnterApp!();
        return;
      }
      await Navigator.of(context).pushAndRemoveUntil<void>(
        MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
        (_) => false,
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _finishing = false;
          _error = 'Kurulum tamamlanamadı. Lütfen tekrar dene.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/onboarding/ready_background_phone.png',
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
                stops: [.38, .62, 1],
                colors: [
                  Colors.transparent,
                  Color(0x42020B18),
                  Color(0xE8020B18),
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
                  (height * .02).clamp(14.0, 24.0),
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
                      'Hazırsın!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: (width * .086).clamp(31.0, 39.0),
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.7,
                        height: 1,
                        shadows: const [
                          Shadow(color: Color(0x88129CFF), blurRadius: 16),
                        ],
                      ),
                    ),
                    SizedBox(height: compact ? 8 : 12),
                    Text(
                      'Artık DriveIt ile yollarını kaydetmeye, performansını keşfetmeye ve gezegende iz bırakmaya hazırsın.',
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .75),
                        fontSize: compact ? 11.5 : 13,
                        height: 1.35,
                      ),
                    ),
                    SizedBox(height: compact ? 5 : 8),
                    const Text(
                      'İlk yolculuğun seni bekliyor.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF65BEFF),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    SizedBox(height: compact ? 13 : 18),
                    _statusRow('Sürüş izinleri hazır'),
                    SizedBox(height: compact ? 6 : 8),
                    _statusRow('Yasal adımlar tamamlandı'),
                    SizedBox(height: compact ? 6 : 8),
                    _statusRow(
                      _profileReady == true
                          ? 'Profil hazır'
                          : 'Profilini daha sonra tamamlayabilirsin',
                      loading: _profileReady == null,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: const TextStyle(
                          color: Color(0xFFFF8A8A),
                          fontSize: 11,
                        ),
                      ),
                    ],
                    SizedBox(height: compact ? 14 : 20),
                    FractionallySizedBox(
                      widthFactor: .913,
                      child: IgnorePointer(
                        ignoring: _finishing,
                        child: AnimatedOpacity(
                          opacity: _finishing ? .55 : 1,
                          duration: const Duration(milliseconds: 150),
                          child: OnboardingPrimaryButton(
                            label: _finishing
                                ? 'Tamamlanıyor'
                                : "DriveIt'a Gir",
                            onPressed: _finish,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: compact ? 11 : 16),
                    const OnboardingProgressIndicator(currentPage: 6),
                    const SizedBox(height: 5),
                    Text(
                      'Kurulum tamamlandı',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .45),
                        fontSize: 9.5,
                        letterSpacing: .2,
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

  Widget _statusRow(String text, {bool loading = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (loading)
          const SizedBox(
            width: 17,
            height: 17,
            child: CircularProgressIndicator(
              strokeWidth: 1.7,
              color: Color(0xFF29A9FF),
            ),
          )
        else
          const Icon(
            Icons.check_circle_rounded,
            color: Color(0xFF29A9FF),
            size: 18,
          ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .82),
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
