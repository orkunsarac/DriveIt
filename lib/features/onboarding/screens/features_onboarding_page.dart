import 'package:flutter/material.dart';

import '../widgets/onboarding_feature_card.dart';
import '../widgets/onboarding_primary_button.dart';
import '../widgets/onboarding_progress_indicator.dart';

class FeaturesOnboardingPage extends StatelessWidget {
  const FeaturesOnboardingPage({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/onboarding/features_background_phone.png',
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
                stops: [.34, .6, 1],
                colors: [
                  Colors.transparent,
                  Color(0x4D020B18),
                  Color(0xE3020B18),
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
              final sectionGap = compact ? 12.0 : 17.0;
              final cardGap = compact ? 8.0 : 11.0;

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
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text.rich(
                        const TextSpan(
                          children: [
                            TextSpan(text: 'DriveIt Neler '),
                            TextSpan(
                              text: 'Sunar?',
                              style: TextStyle(color: Color(0xFF20A7FF)),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: (width * .078).clamp(28.0, 36.0),
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.7,
                          height: 1,
                        ),
                      ),
                    ),
                    SizedBox(height: compact ? 8 : 11),
                    Text(
                      'Sürüşünü kaydet, analiz et ve kendi dünyanı oluştur.',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .7),
                        fontSize: compact ? 12.5 : 14,
                        height: 1.3,
                      ),
                    ),
                    const Spacer(),
                    SizedBox(height: sectionGap),
                    OnboardingFeatureCard(
                      compact: compact,
                      icon: Icons.route_rounded,
                      title: 'Sürüşünü Kaydet',
                      description:
                          'Mesafe, süre, hız ve rotanı otomatik kaydet.',
                    ),
                    SizedBox(height: cardGap),
                    OnboardingFeatureCard(
                      compact: compact,
                      icon: Icons.speed_rounded,
                      title: 'Drive Score',
                      description:
                          'Sürüşünü analiz et, performans puanını gör.',
                    ),
                    SizedBox(height: cardGap),
                    OnboardingFeatureCard(
                      compact: compact,
                      icon: Icons.public_rounded,
                      title: 'Benim Dünyam',
                      description:
                          'Geçtiğin yollarla gezegende iz bırakmaya hazır ol.',
                    ),
                    SizedBox(height: sectionGap),
                    FractionallySizedBox(
                      widthFactor: .913,
                      child: OnboardingPrimaryButton(
                        label: 'Devam Et',
                        onPressed: onContinue,
                      ),
                    ),
                    SizedBox(height: compact ? 14 : 22),
                    const OnboardingProgressIndicator(currentPage: 2),
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
