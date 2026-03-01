import 'package:flutter/material.dart';
import 'package:familysphere_app/core/theme/app_theme.dart';

class ProcessingIndicator extends StatefulWidget {
  final int count;

  const ProcessingIndicator({
    super.key,
    required this.count,
  });

  @override
  State<ProcessingIndicator> createState() => _ProcessingIndicatorState();
}

class _ProcessingIndicatorState extends State<ProcessingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark 
            ? AppTheme.primaryColor.withOpacity(0.1) 
            : const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          RotationTransition(
            turns: _controller,
            child: Icon(
              Icons.auto_awesome_rounded,
              color: AppTheme.primaryColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'AI Analysis in Progress',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0369A1),
                  ),
                ),
                Text(
                  '${widget.count} document${widget.count > 1 ? 's' : ''} being analyzed...',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark 
                        ? Colors.white.withOpacity(0.7) 
                        : const Color(0xFF0369A1).withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 40,
            child: LinearProgressIndicator(
              backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
              color: AppTheme.primaryColor,
              minHeight: 3,
            ),
          ),
        ],
      ),
    );
  }
}
