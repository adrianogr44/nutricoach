import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nutricoach_ai/core/utils/image_utils.dart';

void main() {
  test('prepareImage resizes huge photos and returns jpeg', () async {
    final big = img.Image(width: 4000, height: 3000, numChannels: 3);
    img.fill(big, color: img.ColorRgb8(200, 60, 40));
    final rawPng = Uint8List.fromList(img.encodePng(big));

    final prepared = await prepareImage(rawPng);
    final decoded = img.decodeImage(prepared);

    expect(decoded, isNotNull);
    expect(decoded!.width, lessThanOrEqualTo(1400));
    expect(decoded.height, lessThanOrEqualTo(1400));
    expect(decoded.width, 1400);
    expect(decoded.height, 1050);
    expect(prepared.length, lessThan(rawPng.length));
    expect(prepared.length, lessThan(200000));
  });

  test('prepareImage keeps small images with maxDimension', () async {
    final small = img.Image(width: 400, height: 300, numChannels: 3);
    img.fill(small, color: img.ColorRgb8(30, 120, 90));
    final raw = Uint8List.fromList(img.encodeJpg(small, quality: 90));

    final prepared = await prepareImage(raw);
    final decoded = img.decodeImage(prepared);

    expect(decoded, isNotNull);
    expect(decoded!.width, 400);
    expect(decoded.height, 300);
  });
}