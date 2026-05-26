import 'dart:io';
import 'dart:math';
import 'package:image/image.dart';

void main() {
  final width = 128;
  final height = 128;
  final image = Image(width: width, height: height);
  final rand = Random();

  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final intensity = rand.nextInt(256);
      image.setPixelRgba(x, y, intensity, intensity, intensity, 15);
    }
  }

  final dir = Directory('assets');
  if (!dir.existsSync()) {
    dir.createSync();
  }
  
  File('assets/grain.png').writeAsBytesSync(encodePng(image));
  print('Grain generated.');
}