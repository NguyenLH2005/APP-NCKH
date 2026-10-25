import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class ImageCompressHelper {
  /// Nén ảnh về kích thước tối đa [maxDimension] px (mặc định 550px),
  /// chất lượng [quality]% (mặc định 75%) và trả về chuỗi Base64.
  static Future<String?> compressAndEncodeBase64(
    String? imagePath, {
    int maxDimension = 550,
    int quality = 75,
  }) async {
    if (imagePath == null || imagePath.isEmpty) return null;
    try {
      final file = File(imagePath);
      if (!await file.exists()) return null;

      final bytes = await file.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;

      img.Image processed = decoded;
      // Thu nhỏ nếu cạnh dài vượt quá maxDimension (giữ nguyên tỉ lệ)
      if (decoded.width > maxDimension || decoded.height > maxDimension) {
        if (decoded.width >= decoded.height) {
          processed = img.copyResize(decoded, width: maxDimension, interpolation: img.Interpolation.linear);
        } else {
          processed = img.copyResize(decoded, height: maxDimension, interpolation: img.Interpolation.linear);
        }
      }

      // Nén sang JPG với chất lượng được thiết lập
      final jpgBytes = img.encodeJpg(processed, quality: quality);
      return base64Encode(jpgBytes);
    } catch (e) {
      debugPrint('Lỗi nén ảnh sang Base64: $e');
      return null;
    }
  }

  /// Khôi phục file ảnh từ chuỗi Base64 và ghi vào ổ đĩa nội bộ của máy
  static Future<String?> saveBase64ToFile(String? base64Str, String targetPath) async {
    if (base64Str == null || base64Str.isEmpty) return null;
    try {
      final bytes = base64Decode(base64Str);
      final file = File(targetPath);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (e) {
      debugPrint('Lỗi ghi file từ Base64: $e');
      return null;
    }
  }
}
