import 'package:flutter/material.dart';

class OnboardingProgressIndicator extends StatelessWidget {
  const OnboardingProgressIndicator({
    super.key,
    required this.currentPage,
    this.pageCount = 6,
  });

  final int currentPage;
  final int pageCount;

  static const Color _activeColor = Color(0xFF129CFF);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 54,
          child: Text(
            '$currentPage / $pageCount',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: .2,
            ),
          ),
        ),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(pageCount, (index) {
              final active = index == currentPage - 1;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: active ? 10 : 7,
                height: active ? 10 : 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active
                      ? _activeColor
                      : const Color(0xFF8EA3B8).withValues(alpha: .45),
                  boxShadow: active
                      ? const [
                          BoxShadow(
                            color: Color(0x99129CFF),
                            blurRadius: 9,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
              );
            }),
          ),
        ),
        const SizedBox(width: 54),
      ],
    );
  }
}
