import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class DeviceTextRecognizer {
  const DeviceTextRecognizer({bool? isSupportedOverride})
      : _isSupportedOverride = isSupportedOverride;

  final bool? _isSupportedOverride;

  bool get isSupported =>
      _isSupportedOverride ??
      (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS));

  Future<String> recognizeFile(String path) async {
    if (!isSupported) {
      throw UnsupportedError(
        'OCR local está disponível somente nos aplicativos Android e iOS.',
      );
    }
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result = await recognizer.processImage(InputImage.fromFilePath(path));
      return result.text.trim();
    } finally {
      await recognizer.close();
    }
  }
}
