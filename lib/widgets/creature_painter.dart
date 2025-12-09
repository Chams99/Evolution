import 'package:flutter/material.dart';
import '../models/creature.dart';

class CreaturePainter extends CustomPainter {
  final List<Creature> creatures;
  final List<Food> foods;

  CreaturePainter({
    required this.creatures,
    required this.foods,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Validate canvas size
    if (size.width <= 0 || size.height <= 0 || !size.isFinite) {
      return;
    }

    // Draw food
    final foodPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.fill;

    for (final food in foods) {
      // Validate food position
      if (food.x.isFinite && food.y.isFinite &&
          food.x >= 0 && food.x <= size.width &&
          food.y >= 0 && food.y <= size.height) {
        canvas.drawCircle(
          Offset(food.x, food.y),
          4,
          foodPaint,
        );
      }
    }

    // Draw creatures
    for (final creature in creatures) {
      // Validate creature position
      if (!creature.x.isFinite || !creature.y.isFinite ||
          creature.x < 0 || creature.x > size.width ||
          creature.y < 0 || creature.y > size.height) {
        continue;
      }

      // Draw trail
      if (creature.trail.length > 1) {
        final trailPaint = Paint()
          ..color = Colors.blue.withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;

        final path = Path();
        bool isValidPath = false;
        for (final point in creature.trail) {
          if (point.dx.isFinite && point.dy.isFinite &&
              point.dx >= 0 && point.dx <= size.width &&
              point.dy >= 0 && point.dy <= size.height) {
            if (!isValidPath) {
              path.moveTo(point.dx, point.dy);
              isValidPath = true;
            } else {
              path.lineTo(point.dx, point.dy);
            }
          }
        }
        if (isValidPath && path.computeMetrics().isNotEmpty) {
          canvas.drawPath(path, trailPaint);
        }
      }

      // Draw sense radius
      final senseRadius = creature.dna.sense.clamp(0.0, size.width);
      if (senseRadius > 0) {
        final sensePaint = Paint()
          ..color = Colors.blue.withValues(alpha: 0.1)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(
          Offset(creature.x, creature.y),
          senseRadius,
          sensePaint,
        );
      }

      // Draw creature body
      final creatureSize = (creature.dna.size * 5).clamp(1.0, size.width / 2);
      final health = creature.health.clamp(0.0, 1.0);
      
      final creaturePaint = Paint()
        ..color = Color.lerp(
          Colors.red,
          Colors.blue,
          health,
        )!
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(creature.x, creature.y),
        creatureSize,
        creaturePaint,
      );

      // Draw energy bar
      final barWidth = (creatureSize * 2).clamp(10.0, size.width);
      final barHeight = 3.0;
      final barX = (creature.x - barWidth / 2).clamp(0.0, size.width - barWidth);
      final barY = (creature.y - creatureSize - 8).clamp(0.0, size.height - barHeight);
      
      final barPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.3)
        ..style = PaintingStyle.fill;
      
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(barX, barY, barWidth, barHeight),
          const Radius.circular(1.5),
        ),
        barPaint,
      );

      final energyPaint = Paint()
        ..color = Color.lerp(Colors.red, Colors.green, health)!
        ..style = PaintingStyle.fill;

      final energyWidth = (barWidth * health).clamp(0.0, barWidth);
      if (energyWidth > 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(barX, barY, energyWidth, barHeight),
            const Radius.circular(1.5),
          ),
          energyPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(CreaturePainter oldDelegate) {
    return true;
  }
}

