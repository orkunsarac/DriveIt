import 'package:flutter/material.dart';

import '../services/onboarding_permission_service.dart';
import '../widgets/onboarding_permission_card.dart';
import '../widgets/onboarding_primary_button.dart';
import '../widgets/onboarding_progress_indicator.dart';

class PermissionsOnboardingPage extends StatefulWidget {
  const PermissionsOnboardingPage({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  State<PermissionsOnboardingPage> createState() =>
      _PermissionsOnboardingPageState();
}

class _PermissionsOnboardingPageState extends State<PermissionsOnboardingPage>
    with WidgetsBindingObserver {
  final _permissionService = const OnboardingPermissionService();
  OnboardingPermissionSnapshot? _permissions;
  bool _requestedOnce = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshPermissions();
    }
  }

  Future<void> _refreshPermissions() async {
    final result = await _permissionService.readStatus();
    if (!mounted) return;
    setState(() => _permissions = result);
  }

  Future<void> _handleCta() async {
    final permissions = _permissions;
    if (_busy || permissions == null) return;
    if (permissions.locationGranted) {
      widget.onContinue();
      return;
    }
    if (permissions.locationPermanentlyDenied) {
      await _permissionService.openSettings();
      return;
    }

    setState(() => _busy = true);
    final result = await _permissionService.requestSequentially();
    if (!mounted) return;
    setState(() {
      _permissions = result;
      _requestedOnce = true;
      _busy = false;
    });
  }

  String get _ctaLabel {
    final permissions = _permissions;
    if (_busy || permissions == null) return 'Kontrol Ediliyor';
    if (permissions.locationGranted) return 'Devam Et';
    if (permissions.locationPermanentlyDenied) return 'Ayarları Aç';
    return _requestedOnce ? 'Tekrar Dene' : 'İzinleri Ayarla';
  }

  @override
  Widget build(BuildContext context) {
    final permissions = _permissions;
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/onboarding/permissions_background_phone.png',
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
                stops: [.34, .58, 1],
                colors: [
                  Colors.transparent,
                  Color(0x59020B18),
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
              final compact = height < 700;
              final horizontalPadding = (width * .08).clamp(24.0, 40.0);

              return Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  height * .035,
                  horizontalPadding,
                  (height * .025).clamp(16.0, 28.0),
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
                      'Gerekli İzinler',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: (width * .082).clamp(29.0, 37.0),
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.7,
                        height: 1,
                      ),
                    ),
                    SizedBox(height: compact ? 8 : 11),
                    Text(
                      'DriveIt’ın sürüşlerini doğru şekilde kaydedebilmesi için gerekli erişimleri ayarla.',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .7),
                        fontSize: compact ? 12 : 13.5,
                        height: 1.3,
                      ),
                    ),
                    const Spacer(),
                    SizedBox(height: compact ? 13 : 18),
                    OnboardingPermissionCard(
                      compact: compact,
                      icon: Icons.location_on_rounded,
                      title: 'Konum',
                      badge: 'Gerekli',
                      description:
                          'Rota, mesafe ve hız verilerini kaydetmek için.',
                      granted: permissions?.locationGranted ?? false,
                    ),
                    SizedBox(height: compact ? 9 : 12),
                    OnboardingPermissionCard(
                      compact: compact,
                      icon: Icons.notifications_rounded,
                      title: 'Bildirimler',
                      badge: 'Önerilir',
                      description:
                          'Aktif sürüş ve kayıt durumunu göstermek için.',
                      granted: permissions?.notificationGranted ?? false,
                    ),
                    SizedBox(height: compact ? 14 : 20),
                    FractionallySizedBox(
                      widthFactor: .913,
                      child: OnboardingPrimaryButton(
                        label: _ctaLabel,
                        onPressed: _handleCta,
                      ),
                    ),
                    SizedBox(height: compact ? 14 : 22),
                    const OnboardingProgressIndicator(currentPage: 3),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
