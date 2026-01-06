import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax/iconsax.dart';
import '../../config/theme.dart';

/// Expandable Floating Action Button with animated mini-FABs
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
  bool _isOpen = false;

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
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  void _close() {
    setState(() {
      _isOpen = false;
      _controller.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      height: 220,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          // Backdrop - closes FAB when tapped
          if (_isOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: _close,
                behavior: HitTestBehavior.translucent,
              ),
            ),
          
          // Mini FAB - Add Expense (Top)
          _buildExpandingAction(
            index: 1,
            icon: Iconsax.receipt_add,
            label: 'إضافة مصروف',
            color: AppTheme.secondaryColor,
            onPressed: () {
              _close();
              widget.onExpensePressed();
            },
          ),
          
          // Mini FAB - Debt Manager (Middle)
          _buildExpandingAction(
            index: 0,
            icon: Iconsax.personalcard,
            label: 'مدير الديون',
            color: AppTheme.accentBlue,
            onPressed: () {
              _close();
              widget.onDebtPressed();
            },
          ),
          
          // Main FAB
          Positioned(
            bottom: 0,
            child: _buildMainFab(),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandingAction({
    required int index,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    final double distance = 70.0 + (index * 70.0);
    
    return AnimatedBuilder(
      animation: _expandAnimation,
      builder: (context, child) {
        return Positioned(
          bottom: _expandAnimation.value * distance + 8,
          child: Opacity(
            opacity: _expandAnimation.value,
            child: Transform.scale(
              scale: _expandAnimation.value,
              child: child,
            ),
          ),
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.cardBackground,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Mini FAB
          FloatingActionButton.small(
            heroTag: 'fab_$label',
            onPressed: onPressed,
            backgroundColor: color,
            elevation: 4,
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ],
      ).animate(target: _isOpen ? 1 : 0)
        .slideX(begin: 0.3, end: 0, duration: 200.ms, delay: (index * 50).ms)
        .fadeIn(duration: 200.ms, delay: (index * 50).ms),
    );
  }

  Widget _buildMainFab() {
    return AnimatedBuilder(
      animation: _expandAnimation,
      builder: (context, child) {
        return FloatingActionButton(
          heroTag: 'main_fab',
          onPressed: _toggle,
          backgroundColor: _isOpen 
              ? AppTheme.accentRed 
              : AppTheme.primaryColor,
          elevation: 8,
          child: AnimatedRotation(
            duration: const Duration(milliseconds: 300),
            turns: _isOpen ? 0.125 : 0, // 45 degrees
            child: Icon(
              _isOpen ? Icons.close : Icons.add,
              color: Colors.white,
              size: 28,
            ),
          ),
        );
      },
    ).animate(
      onPlay: (controller) => controller.repeat(reverse: true),
    ).shimmer(
      duration: 2.seconds,
      delay: 3.seconds,
      color: Colors.white.withOpacity(0.3),
    );
  }
}

/// Custom AnimatedBuilder that works with Animation<double>
class AnimatedBuilder extends AnimatedWidget {
  final Widget Function(BuildContext context, Widget? child) builder;
  final Widget? child;

  const AnimatedBuilder({
    super.key,
    required Animation<double> animation,
    required this.builder,
    this.child,
  }) : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    return builder(context, child);
  }
}
