import 'package:flutter/material.dart';

import '../widgets/onboarding_progress_indicator.dart';

class OnboardingPlaceholderPage extends StatelessWidget {
  const OnboardingPlaceholderPage({super.key, required this.pageNumber});

  final int pageNumber;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF020B18),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                constraints.maxWidth * .08,
                24,
                constraints.maxWidth * .08,
                24,
              ),
              child: Column(
                children: [
                  const Spacer(),
                  Text(
                    'Sayfa $pageNumber',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  OnboardingProgressIndicator(currentPage: pageNumber),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
