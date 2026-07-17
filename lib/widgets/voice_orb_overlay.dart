import 'dart:math' as math;

import 'package:flutter/material.dart';

/// What JARVIS is doing right now during a call, so the orb can react.
enum VoiceOrbState { listening, thinking, speaking }

/// Full-screen voice-call UI: a breathing, glowing orb in the middle plus a
/// mute and hang-up button at the bottom — the "Anruf-Modus" visual.
class VoiceOrbOverlay extends StatefulWidget {
  const VoiceOrbOverlay({
    super.key,
    required this.state,
    required this.statusText,
    required this.muted,
    required this.onToggleMute,
    required this.onEndCall,
    required this.onReset,
    required this.onOpenCamera,
  });

  final VoiceOrbState state;
  final String statusText;
  final bool muted;
  final VoidCallback onToggleMute;
  final VoidCallback onEndCall;
  final VoidCallback onReset;
  final VoidCallback onOpenCamera;

  @override
  State<VoiceOrbOverlay> createState() => _VoiceOrbOverlayState();
}

class _VoiceOrbOverlayState extends State<VoiceOrbOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: Colors.black,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'JARVIS',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2),
                    ),
                  ),
                  const Spacer(),
                  _SmallIconButton(
                    icon: Icons.refresh,
                    tooltip: 'Gespräch zurücksetzen',
                    onTap: widget.onReset,
                  ),
                  const SizedBox(width: 10),
                  _SmallIconButton(
                    icon: Icons.camera_alt_outlined,
                    tooltip: 'Kamera öffnen',
                    onTap: widget.onOpenCamera,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => _Orb(
                    t: _controller.value * 2 * math.pi,
                    state: widget.state,
                    colorScheme: colorScheme,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(
                widget.statusText,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 15),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _RoundButton(
                    icon: widget.muted ? Icons.mic_off : Icons.mic,
                    background: Colors.white.withValues(alpha: 0.12),
                    onTap: widget.onToggleMute,
                  ),
                  const SizedBox(width: 32),
                  _RoundButton(
                    icon: Icons.call_end,
                    background: Colors.red,
                    onTap: widget.onEndCall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({required this.t, required this.state, required this.colorScheme});

  final double t;
  final VoiceOrbState state;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final speed = switch (state) {
      VoiceOrbState.listening => 1.0,
      VoiceOrbState.thinking => 2.4,
      VoiceOrbState.speaking => 1.7,
    };
    final wave = math.sin(t * speed);
    final pulse = switch (state) {
      VoiceOrbState.listening => 0.035 * wave,
      VoiceOrbState.thinking => 0.05 * wave,
      VoiceOrbState.speaking => 0.09 * wave.abs(),
    };
    final colors = switch (state) {
      VoiceOrbState.listening => [colorScheme.primary, colorScheme.primaryContainer],
      VoiceOrbState.thinking => [colorScheme.tertiary, colorScheme.primary],
      VoiceOrbState.speaking => [colorScheme.secondary, colorScheme.primary],
    };
    return Transform.scale(
      scale: 1.0 + pulse,
      child: Container(
        width: 220,
        height: 220,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: colors,
            radius: 0.85 + 0.1 * math.sin(t * 0.5),
          ),
          boxShadow: [
            BoxShadow(
              color: colors.first.withValues(alpha: 0.55),
              blurRadius: 70,
              spreadRadius: 8,
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.background, required this.onTap});

  final IconData icon;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}

class _SmallIconButton extends StatelessWidget {
  const _SmallIconButton({required this.icon, required this.onTap, required this.tooltip});

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.1),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}
