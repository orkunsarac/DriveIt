import 'package:flutter/material.dart';

import '../widgets/onboarding_primary_button.dart';
import '../widgets/onboarding_progress_indicator.dart';

class WelcomeOnboardingPage extends StatelessWidget {
  const WelcomeOnboardingPage({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/onboarding/welcome_background_phone.png',
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [.38, .72, 1],
              colors: [
                Colors.transparent,
                Color(0x55000713),
                Color(0xD9000713),
              ],
            ),
          ),
        ),
        SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final height = constraints.maxHeight;
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
                    const Spacer(flex: 7),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text.rich(
                        const TextSpan(
                          children: [
                            TextSpan(text: 'Hoş '),
                            TextSpan(
                              text: 'Geldin',
                              style: TextStyle(color: Color(0xFF20A7FF)),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: (width * .105).clamp(34.0, 46.0),
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.9,
                          height: 1,
                        ),
                      ),
                    ),
                    SizedBox(height: (height * .025).clamp(14.0, 22.0)),
                    const Text(
                      'Sürüşün sadece bir yolculuk değil.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Kaydet. Analiz et. Dünyanı oluştur.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .68),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        height: 1.35,
                      ),
                    ),
                    SizedBox(height: (height * .045).clamp(24.0, 38.0)),
                    FractionallySizedBox(
                      widthFactor: .913,
                      child: OnboardingPrimaryButton(
                        label: 'Başlayalım',
                        onPressed: onContinue,
                      ),
                    ),
                    SizedBox(height: (height * .035).clamp(22.0, 34.0)),
                    const OnboardingProgressIndicator(currentPage: 1),
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
