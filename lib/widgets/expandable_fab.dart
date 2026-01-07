import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax/iconsax.dart';
import '../../config/theme.dart';

/// Expandable Floating Action Button with animated mini-FABs using Overlay
class ExpandableFab extends StatefulWidget {
  final VoidCallback onDebtPressed;
  final VoidCallback onExpensePressed;
  
  const ExpandableFab({
    super.key,
    required this.onDebtPressed,
    required this.onExpensePressed,
  });

  @override
  State<ExpandableFab> createState() => _ExpandableFabState();
}

class _ExpandableFabState extends State<ExpandableFab> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _expandAnimation;
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void dispose() {
    _removeOverlay();
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_isOpen) {
      _close();
    } else {
      _open();
    }
  }

  void _open() {
    setState(() {
      _isOpen = true;
    });
    _insertOverlay();
    _controller.forward();
  }

  void _close() {
    setState(() {
      _isOpen = false;
    });
    _controller.reverse().then((_) {
      if (!_isOpen) {
        _removeOverlay();
      }
    });
  }

  void _insertOverlay() {
    _removeOverlay(); // Safety check
    
    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            // Modal barrier to close on tap outside
            Positioned.fill(
              child: GestureDetector(
                onTap: _close,
                behavior: HitTestBehavior.translucent,
                child: Container(color: Colors.transparent),
              ),
            ),
            // Menu Items anchored to FAB
            Positioned(
              width: 250,
              height: 250,
              child: CompositedTransformFollower(
                link: _layerLink,
                showWhenUnlinked: false,
                offset: const Offset(-85, -85), // Center (125) - Center (40) = 85. So -85 to align centers.
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                     // Action 1: Expense (Right)
                    _buildRadialAction(
                      angle: 45, // Top Right
                      distance: 80,
                      icon: Iconsax.receipt_add,
                      color: AppTheme.secondaryColor,
                      onPressed: () {
                        _close();
                        widget.onExpensePressed();
                      },
                    ),
                    
                    // Action 2: Debt (Left)
                    _buildRadialAction(
                      angle: 135, // Top Left
                      distance: 80,
                      icon: Iconsax.personalcard,
                      color: AppTheme.accentBlue,
                      onPressed: () {
                        _close();
                        widget.onDebtPressed();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: SizedBox(
        width: 80, // Matches FlashyFAB
        height: 80,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            _buildMainFab(),
          ],
        ),
      ),
    );
  }

  Widget _buildRadialAction({
    required double angle,
    required double distance,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    final double rad = angle * (math.pi / 180);
    
    return AnimatedBuilder(
      animation: _expandAnimation,
      builder: (context, child) {
        final double progress = _expandAnimation.value;
        final double offset = distance * progress;
        final double dx = offset * math.cos(rad);
        final double dy = -offset * math.sin(rad); // Up is negative
        
        return Transform.translate(
          offset: Offset(dx, dy),
          child: Opacity(
            opacity: progress,
            child: Transform.scale(
              scale: progress,
              child: child,
            ),
          ),
        );
      },
      child: FloatingActionButton.small(
        heroTag: 'fab_${angle}_${icon.codePoint}', // Unique tag
        onPressed: onPressed,
        backgroundColor: color,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }

  Widget _buildMainFab() {
    return Hero(
      tag: 'fab_hero',
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
           setState(() => _isPressed = false);
           _toggle();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: Container(
          width: 65,
          height: 65,
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.5),
                blurRadius: 20,
                spreadRadius: 2,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: AnimatedRotation(
            duration: const Duration(milliseconds: 300),
            turns: _isOpen ? 0.125 : 0, // 45 degrees
            child: Icon(
              Icons.add,
              color: Colors.white,
              size: 32,
            ),
          ),
        )
        .animate(target: _isPressed ? 1 : 0)
        .scaleXY(duration: 100.ms, end: 0.9), // Press effect
      )
      .animate(onPlay: (controller) => controller.repeat(reverse: true))
      .scaleXY(duration: 1.5.seconds, begin: 1.0, end: 1.05, curve: Curves.easeInOut), // Breathing effect
    );
  }
}
