import 'dart:math' as math;
import 'package:flutter/material.dart';

class InfinitySpiritCenterLoaderScreen2 extends StatefulWidget {
  const InfinitySpiritCenterLoaderScreen2({Key? key}) : super(key: key);

  @override
  State<InfinitySpiritCenterLoaderScreen2> createState() =>
      _InfinitySpiritCenterLoaderScreenState();
}

class _InfinitySpiritCenterLoaderScreenState
    extends State<InfinitySpiritCenterLoaderScreen2>
    with SingleTickerProviderStateMixin {
  late final AnimationController _infinitySpiritRotationController;

  @override
  void initState() {
    super.initState();
    _infinitySpiritRotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(); // постоянное вращение
  }

  @override
  void dispose() {
    _infinitySpiritRotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // Фон — первая картинка
          const InfinitySpiritBackground(),

          // Центр экрана: вторая картинка + крутящийся лоадер
          Center(
            child: SizedBox(
              width: 160,
              height: 160,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  // Вращающиеся лучи
                  AnimatedBuilder(
                    animation: _infinitySpiritRotationController,
                    builder: (BuildContext context, Widget? child) {
                      final double infinitySpiritAngle =
                          _infinitySpiritRotationController.value *
                              2 *
                              math.pi;
                      return Transform.rotate(
                        angle: infinitySpiritAngle,
                        child: CustomPaint(
                          size: const Size(160, 160),
                          painter: InfinitySpiritRaysPainter(),
                        ),
                      );
                    },
                  ),

                  // Вторая картинка по центру
                  ClipOval(
                    child: Image.asset(
                      'assets/center.png', // ВАШ ПУТЬ КО 2‑Й КАРТИНКЕ
                      width: 90,
                      height: 90,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Фон (первая картинка полноэкранно)
class InfinitySpiritBackground extends StatelessWidget {
  const InfinitySpiritBackground({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/bg.png', // ВАШ ПУТЬ К ФОНУ (1‑Я КАРТИНКА)
      fit: BoxFit.cover,
    );
  }
}

/// Painter, рисующий "солнышко"‑лоадер вокруг центра
class InfinitySpiritRaysPainter extends CustomPainter {
  @override
  void paint(Canvas infinitySpiritCanvas, Size infinitySpiritSize) {
    final Paint infinitySpiritPaint = Paint()
      ..color = const Color(0xFFF5D18B) // бежевый/золотой
      ..style = PaintingStyle.fill;

    final Offset infinitySpiritCenter =
    Offset(infinitySpiritSize.width / 2, infinitySpiritSize.height / 2);

    const int infinitySpiritRaysCount = 12;
    final double infinitySpiritRadius = infinitySpiritSize.width * 0.42;
    final double infinitySpiritRayWidth = 10;
    final double infinitySpiritRayLength = 26;

    for (int infinitySpiritIndex = 0;
    infinitySpiritIndex < infinitySpiritRaysCount;
    infinitySpiritIndex++) {
      final double infinitySpiritAngle =
          (2 * math.pi / infinitySpiritRaysCount) * infinitySpiritIndex;

      final double infinitySpiritDx =
          infinitySpiritCenter.dx + infinitySpiritRadius * math.cos(infinitySpiritAngle);
      final double infinitySpiritDy =
          infinitySpiritCenter.dy + infinitySpiritRadius * math.sin(infinitySpiritAngle);

      infinitySpiritCanvas.save();

      infinitySpiritCanvas.translate(infinitySpiritDx, infinitySpiritDy);
      infinitySpiritCanvas.rotate(infinitySpiritAngle);

      final Rect infinitySpiritRayRect = Rect.fromCenter(
        center: Offset(0, 0),
        width: infinitySpiritRayWidth,
        height: infinitySpiritRayLength,
      );
      final RRect infinitySpiritRayRRect = RRect.fromRectAndRadius(
        infinitySpiritRayRect,
        const Radius.circular(20),
      );

      infinitySpiritCanvas.drawRRect(infinitySpiritRayRRect, infinitySpiritPaint);
      infinitySpiritCanvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter infinitySpiritOldDelegate) => false;
}