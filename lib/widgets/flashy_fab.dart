import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../config/theme.dart';

class FlashyFAB extends StatefulWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String tooltip;

  const FlashyFAB({
    super.key,
    required this.onPressed,
    this.icon = Iconsax.add,
    this.tooltip = 'إضافة',
  });

  @override
  State<FlashyFAB> createState() => _FlashyFABState();
}

class _FlashyFABState extends State<FlashyFAB> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80, // Size for elements to pop out
      height: 80,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Popping Icons (Background effects)
          if (_isPressed) ...[
            _buildPopIcon(Iconsax.wallet_1, -40, -40, 100),
            _buildPopIcon(Iconsax.money_send, 40, -40, 200),
            _buildPopIcon(Iconsax.card, -40, 40, 300),
            _buildPopIcon(Iconsax.coin, 40, 40, 400),
          ],
          
          // Main Button
          GestureDetector(
            onTapDown: (_) => setState(() => _isPressed = true),
            onTapUp: (_) {
               setState(() => _isPressed = false);
               widget.onPressed();
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
              child: Icon(
                widget.icon,
                color: Colors.white,
                size: 32,
              )
              .animate(target: _isPressed ? 1 : 0)
              .rotate(duration: 400.ms, curve: Curves.easeInOutBack, begin: 0, end: 1), // Spin effect
            ),
          )
          .animate(onPlay: (controller) => controller.repeat(reverse: true))
          .scaleXY(duration: 1.5.seconds, begin: 1.0, end: 1.05, curve: Curves.easeInOut) // Breathing effect
          .animate(target: _isPressed ? 1 : 0)
          .scaleXY(duration: 100.ms, end: 0.9), // Press effect
        ],
      ),
    );
  }

  Widget _buildPopIcon(IconData icon, double x, double y, int delay) {
    return Positioned(
      child: Icon(icon, color: AppTheme.secondaryColor, size: 20)
        .animate()
        .move(begin: const Offset(0, 0), end: Offset(x, y), duration: 600.ms, curve: Curves.easeOutBack)
        .fadeOut(duration: 600.ms, delay: 200.ms),
    );
  }
}
