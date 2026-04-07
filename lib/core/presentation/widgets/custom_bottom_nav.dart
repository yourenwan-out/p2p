import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const _surfaceContainerLow = Color(0xFF001D36);
const _surfaceContainerHighest = Color(0xFF183655);
const _primary = Color(0xFFFFB77A);
const _outlineVariant = Color(0xFF554336);

class CustomBottomNav extends StatelessWidget {
  final int currentIndex;
  
  const CustomBottomNav({
    super.key,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _surfaceContainerLow.withValues(alpha: 0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: _outlineVariant.withValues(alpha: 0.12))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3), 
            blurRadius: 24, 
            offset: const Offset(0, -8),
          )
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(
                icon: Icons.login, 
                label: 'الإنضمام', 
                active: currentIndex == 0,
              ),
              _navItem(
                icon: Icons.groups, 
                label: 'الفريق', 
                active: currentIndex == 1,
              ),
              _navItem(
                icon: Icons.grid_view, 
                label: 'المهمة', 
                active: currentIndex == 2,
              ),
              _navItem(
                icon: Icons.terminal, 
                label: 'LOGS', 
                active: currentIndex == 3,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem({required IconData icon, required String label, required bool active}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: active ? BoxDecoration(
        color: _surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ) : null,
      child: Column(
        mainAxisSize: MainAxisSize.min, 
        children: [
          Icon(icon, color: active ? _primary : _outlineVariant, size: 22),
          const SizedBox(height: 2),
          Text(
            label, 
            style: GoogleFonts.spaceGrotesk(
              color: active ? _primary : _outlineVariant.withValues(alpha: 0.7),
              fontSize: 10, 
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
