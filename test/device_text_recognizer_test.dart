import 'package:flutter_test/flutter_test.dart';
import 'package:nutricoach_ai/services/device_text_recognizer.dart';

void main() {
  test('bloqueia OCR quando a plataforma não é suportada', () async {
    const recognizer = DeviceTextRecognizer(isSupportedOverride: false);

    expect(recognizer.isSupported, isFalse);
    expect(
      () => recognizer.recognizeFile('foto.jpg'),
      throwsA(isA<UnsupportedError>()),
    );
  });
}
