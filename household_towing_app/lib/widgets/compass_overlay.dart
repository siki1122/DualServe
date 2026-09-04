import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:household_towing_app/utils/app_theme.dart';


class CompassOverlay extends StatelessWidget {
  final VoidCallback? onTap;

  const CompassOverlay({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<CompassEvent>(
      stream: FlutterCompass.events,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const SizedBox.shrink();
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink(); // Wait for data
        }

        double? direction = snapshot.data?.heading;

        // if direction is null, device doesn't have a sensor
        if (direction == null) {
          return const SizedBox.shrink();
        }

        return GestureDetector(
          onTap: onTap,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.textSlateDark.withOpacity(0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Transform.rotate(
                angle: (direction * (math.pi / 180) * -1),
                child: const Icon(
                  Icons.explore,
                  color: Colors.redAccent,
                  size: 32,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
