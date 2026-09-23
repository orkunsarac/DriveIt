import 'package:flutter/material.dart';

class OnboardingPermissionCard extends StatelessWidget {
  const OnboardingPermissionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.badge,
    required this.description,
    required this.granted,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String badge;
  final String description;
  final bool granted;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: compact ? 112 : 124),
      padding: EdgeInsets.all(compact ? 15 : 17),
      decoration: BoxDecoration(
        color: const Color(0xFF061323).withValues(alpha: .74),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: const Color(0xFF168EFF).withValues(alpha: .72),
        ),
        boxShadow: const [BoxShadow(color: Color(0x2E118EFF), blurRadius: 13)],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: compact ? 44 : 48,
            height: compact ? 44 : 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF0D79CF).withValues(alpha: .2),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF23A9FF),
              size: compact ? 24 : 27,
            ),
          ),
          SizedBox(width: compact ? 13 : 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: compact ? 16 : 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF168EFF).withValues(alpha: .16),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        badge,
                        style: const TextStyle(
                          color: Color(0xFF78C8FF),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .66),
                    fontSize: compact ? 11.5 : 12.5,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      granted
                          ? Icons.check_circle_rounded
                          : Icons.cancel_outlined,
                      color: granted
                          ? const Color(0xFF4DE2BD)
                          : const Color(0xFFE48793),
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      granted ? 'İzin verildi ✓' : 'İzin verilmedi',
                      style: TextStyle(
                        color: granted
                            ? const Color(0xFF7DEBD0)
                            : const Color(0xFFF0A0A9),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
