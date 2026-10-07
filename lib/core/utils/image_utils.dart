import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Prepara uma imagem (foto de laudo/r240tulo) para processamento local:
/// - corrige rotacao EXIF,
/// - redimensiona para no maximo [maxDimension]px (mantendo proporcao),
/// - converte para JPEG comprimido.
/// Fotos de celular (12 MP) viram ~200-400 KB, melhorando performance do OCR.
Future<Uint8List> prepareImage(
  Uint8List bytes, {
  int maxDimension = 1400,
  int quality = 82,
}) async {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return bytes;

  final w = decoded.width;
  final h = decoded.height;
  img.Image image = decoded;
  if (w > maxDimension || h > maxDimension) {
    if (w >= h) {
      image = img.copyResize(image, width: maxDimension);
    } else {
      image = img.copyResize(image, height: maxDimension);
    }
  }

  return Uint8List.fromList(img.encodeJpg(image, quality: quality));
}


