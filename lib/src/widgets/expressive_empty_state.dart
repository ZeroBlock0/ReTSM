import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui';

class ExpressiveEmptyState extends StatefulWidget {
  final String message;
  final IconData icon;

  const ExpressiveEmptyState({
    super.key,
    required this.message,
    this.icon = Icons.auto_awesome_mosaic_rounded,
  });

  @override
  State<ExpressiveEmptyState> createState() => _ExpressiveEmptyStateState();
}

class _ExpressiveEmptyStateState extends State<ExpressiveEmptyState>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 15))
          ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return ClipRect(
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final t = _controller.value * 2 * math.pi;
              return Stack(
                alignment: Alignment.center,
                children: [
                  // Blob 1 (Primary)
                  Transform.translate(
                    offset: Offset(math.cos(t) * 40, math.sin(t) * 25),
                    child: Transform.rotate(
                      angle: t * 1.5,
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.4),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(100),
                            topRight: Radius.circular(150),
                            bottomLeft: Radius.circular(120),
                            bottomRight: Radius.circular(100),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Blob 2 (Tertiary)
                  Transform.translate(
                    offset: Offset(
                        math.cos(t + math.pi) * 50, math.sin(t + math.pi) * 40),
                    child: Transform.rotate(
                      angle: -t * 0.8,
                      child: Container(
                        width: 180,
                        height: 120,
                        decoration: BoxDecoration(
                          color: colors.tertiary.withValues(alpha: 0.4),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(120),
                            topRight: Radius.circular(80),
                            bottomLeft: Radius.circular(100),
                            bottomRight: Radius.circular(150),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Blob 3 (Secondary)
                  Transform.translate(
                    offset: Offset(math.cos(t + math.pi / 2) * 30,
                        math.sin(t + math.pi / 2) * 45),
                    child: Transform.rotate(
                      angle: t * 1.2,
                      child: Container(
                        width: 130,
                        height: 170,
                        decoration: BoxDecoration(
                          color: colors.secondary.withValues(alpha: 0.3),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(150),
                            topRight: Radius.circular(100),
                            bottomLeft: Radius.circular(130),
                            bottomRight: Radius.circular(90),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          // Glassmorphism Blur
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
            child: Container(
              color:
                  Theme.of(context).colorScheme.surface.withValues(alpha: 0.1),
            ),
          ),
          // Content
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 64, color: colors.primary),
              const SizedBox(height: 16),
              Text(
                widget.message,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colors.onSurface,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
