import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'features_onboarding_page.dart';
import 'legal_safety_onboarding_page.dart';
import 'permissions_onboarding_page.dart';
import 'profile_onboarding_page.dart';
import 'ready_onboarding_page.dart';
import 'welcome_onboarding_page.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  static const previewRoute = '/onboarding-preview';

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final PageController _pageController;
  int _currentPage = 0;
  double _horizontalDragDistance = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _showNextPage() {
    return _pageController.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _showPreviousPage() {
    return _pageController.previousPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  void _handleHorizontalDragEnd(DragEndDetails details) {
    if (_horizontalDragDistance > 48 && _currentPage > 0) {
      _showPreviousPage();
    }
    _horizontalDragDistance = 0;
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Color(0xFF020B18),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: const Color(0xFF020B18),
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragStart: (_) => _horizontalDragDistance = 0,
          onHorizontalDragUpdate: (details) {
            _horizontalDragDistance += details.delta.dx;
          },
          onHorizontalDragEnd: _handleHorizontalDragEnd,
          onHorizontalDragCancel: () => _horizontalDragDistance = 0,
          child: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (page) => _currentPage = page,
            children: [
              WelcomeOnboardingPage(onContinue: _showNextPage),
              FeaturesOnboardingPage(onContinue: _showNextPage),
              PermissionsOnboardingPage(onContinue: _showNextPage),
              LegalSafetyOnboardingPage(onContinue: _showNextPage),
              ProfileOnboardingPage(onContinue: _showNextPage),
              const ReadyOnboardingPage(),
            ],
          ),
        ),
      ),
    );
  }
}
