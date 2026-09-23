import 'package:flutter/material.dart';

class OnboardingFeatureCard extends StatelessWidget {
  const OnboardingFeatureCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: compact ? 72 : 80),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 15 : 17,
        vertical: compact ? 11 : 13,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF061323).withValues(alpha: .72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF168EFF).withValues(alpha: .72),
          width: 1,
        ),
        boxShadow: const [BoxShadow(color: Color(0x2E118EFF), blurRadius: 12)],
      ),
      child: Row(
        children: [
          Container(
            width: compact ? 42 : 46,
            height: compact ? 42 : 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF0D79CF).withValues(alpha: .18),
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              color: const Color(0xFF23A9FF),
              size: compact ? 23 : 26,
            ),
          ),
          SizedBox(width: compact ? 13 : 15),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: compact ? 15 : 16,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .68),
                    fontSize: compact ? 11.5 : 12.5,
                    fontWeight: FontWeight.w400,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
