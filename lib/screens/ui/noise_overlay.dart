import 'package:flutter/material.dart';

class GrainBackground extends StatelessWidget {
  const GrainBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: const <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  Color(0xFF102018),
                  Color(0xFF1B1D1A),
                  Color(0xFF111411),
                  Color(0xFF213429),
                ],
                stops: <double>[0.0, 0.34, 0.68, 1.0],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.82, -0.74),
                radius: 1.05,
                colors: <Color>[Color(0x5536B56E), Color(0x001A1D1A)],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.86, 0.78),
                radius: 1.2,
                colors: <Color>[Color(0x4031A866), Color(0x00111311)],
              ),
            ),
          ),
          NoiseOverlay(opacity: 0.16),
        ],
      ),
    );
  }
}

class NoiseOverlay extends StatelessWidget {
  const NoiseOverlay({super.key, this.opacity = 0.08});

  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _NoisePainter(opacity: opacity),
        size: Size.infinite,
      ),
    );
  }
}

class _NoisePainter extends CustomPainter {
  const _NoisePainter({required this.opacity});

  final double opacity;

  static const List<Offset> _points = <Offset>[
    Offset(2, 5),
    Offset(11, 19),
    Offset(23, 7),
    Offset(37, 29),
    Offset(51, 13),
    Offset(61, 43),
    Offset(6, 47),
    Offset(18, 35),
    Offset(30, 55),
    Offset(45, 49),
    Offset(58, 24),
    Offset(14, 60),
    Offset(41, 4),
    Offset(54, 57),
    Offset(27, 25),
    Offset(49, 36),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final Paint lightPaint = Paint()
      ..color = Colors.white.withValues(alpha: opacity * 0.16);
    final Paint darkPaint = Paint()
      ..color = Colors.black.withValues(alpha: opacity * 0.18);

    for (double y = 0; y < size.height; y += 64) {
      for (double x = 0; x < size.width; x += 64) {
        for (int i = 0; i < _points.length; i++) {
          final Offset point = _points[i] + Offset(x, y);
          canvas.drawCircle(point, 0.55, i.isEven ? lightPaint : darkPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_NoisePainter oldDelegate) {
    return oldDelegate.opacity != opacity;
  }
}
