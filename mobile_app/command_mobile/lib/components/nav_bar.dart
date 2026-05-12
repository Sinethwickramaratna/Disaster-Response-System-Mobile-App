import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const BottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF020617).withValues(alpha: 0.9), // slate-950/90
        border: const Border(
          top: BorderSide(color: Colors.white10),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildNavItem(0, Icons.dashboard, 'Dashboard'),
              _buildNavItem(1, Icons.description, 'Reports'),
              _buildNavItem(2, Icons.map, 'Map'),
              _buildNavItem(3, Icons.inventory_2, 'Resources'),
              _buildNavItem(4, Icons.warning, 'Alerts'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final bool isActive = currentIndex == index;
    final Color color = isActive
        ? const Color(0xFF3B82F6) // blue-500
        : const Color(0xFF64748B); // slate-500

    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.transparent, // Ensures Container fills the Expanded space for taps
            border: isActive
                ? const Border(
                    top: BorderSide(color: Color(0xFF3B82F6), width: 2),
                  )
                : null,
          ),
          padding: EdgeInsets.only(top: isActive ? 6 : 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: color,
              ),
              const SizedBox(height: 4),
              Text(
                label.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}