import 'dart:io';
import 'dart:math';

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class AIHelper {
  static final AIHelper instance = AIHelper._init();
  AIHelper._init();

  Interpreter? _cropInterpreter;
  Interpreter? _classifyInterpreter;

  static const List<String> labels = [
    'Bạch tuộc', 'Cà chua', 'Cá hồi', 'Cà rốt', 
    'Chuối', 'Dưa leo', 'Mực', 'Táo', 
    'Thịt bò', 'Thịt gà', 'Thịt heo', 'Tôm'
  ];

  Future<void> init() async {
    _cropInterpreter ??= await Interpreter.fromAsset('assets/models/crop_model.tflite');
    _classifyInterpreter ??= await Interpreter.fromAsset('assets/models/classify_model.tflite');
  }

  /// 1. CHẠY MODEL NHẬN DIỆN VÀ CẮT ẢNH
  Future<Map<String, String?>> detectAndCrop(String imagePath) async {
    await init();
    
    // Đọc ảnh gốc
    final File imageFile = File(imagePath);
    final img.Image? originalImage = img.decodeImage(imageFile.readAsBytesSync());
    if (originalImage == null) throw Exception("Không thể đọc ảnh gốc");

    // Lấy kích thước ảnh gốc
        final int origW = originalImage.width;
    final int origH = originalImage.height;

    final int inputSize = 512;
    img.Image resizedImage = img.copyResize(
      originalImage,
      width: inputSize,
      height: inputSize,
    );

    var input = List.generate(
      1,
      (i) => List.generate(
        3, 
        (c) => List.generate(
          inputSize,
          (y) => List.filled(inputSize, 0.0),
        ),
      ),
    );

    for (int y = 0; y < inputSize; y++) {
      for (int x = 0; x < inputSize; x++) {
        final pixel = resizedImage.getPixel(x, y);
        input[0][0][y][x] = pixel.r / 255.0; 
        input[0][1][y][x] = pixel.g / 255.0; 
        input[0][2][y][x] = pixel.b / 255.0; 
      }
    }

    // Lấy output tensor shape để tạo mảng chứa kết quả
    final outputShape = _cropInterpreter!.getOutputTensor(0).shape;
    // Thường YOLOv8 tflite sẽ nhả ra [1, 6, 8400] hoặc [1, 8400, 6]
    var output = List.filled(outputShape.reduce((a, b) => a * b), 0.0).reshape(outputShape);

    // Chạy model
    _cropInterpreter!.run(input, output);

    // Xử lý output để tìm bounding box tốt nhất cho Food (class 0) và Label (class 1)
    double maxFoodProb = 0.0;
    int maxFoodIndex = -1;
    double maxLabelProb = 0.0;
    int maxLabelIndex = -1;

    // Kiểm tra xem tensor bị xoay theo chiều nào
    bool isTransposed = outputShape[1] > outputShape[2]; // e.g. [1, 8400, 6]
    int numBoxes = isTransposed ? outputShape[1] : outputShape[2];

    for (int i = 0; i < numBoxes; i++) {
      double foodProb = isTransposed ? output[0][i][4] : output[0][4][i];
      double labelProb = isTransposed ? output[0][i][5] : output[0][5][i];
      
      // BỎ HOÀN TOÀN TIÊU CHUẨN, LẤY ĐIỂM CAO NHẤT KHÔNG CẦN BIẾT LÀ BAO NHIÊU
      if (foodProb > maxFoodProb) {
        maxFoodProb = foodProb;
        maxFoodIndex = i;
      }
      if (labelProb > maxLabelProb) {
        maxLabelProb = labelProb;
        maxLabelIndex = i;
      }
    }

    if (maxFoodIndex == -1) {
      throw Exception("Không tìm thấy món ăn nào trong ảnh!");
    }

    // Hàm phụ trợ để giải mã tọa độ và cắt ảnh
    Future<String> cropAndSave(int index) async {
      double xc = isTransposed ? output[0][index][0] : output[0][0][index];
      double yc = isTransposed ? output[0][index][1] : output[0][1][index];
      double w = isTransposed ? output[0][index][2] : output[0][2][index];
      double h = isTransposed ? output[0][index][3] : output[0][3][index];

      // TỰ ĐỘNG NHẬN DIỆN TỌA ĐỘ LÀ TƯƠNG ĐỐI (0..1) HAY TUYỆT ĐỐI (0..512)
      if (w <= 1.0 && h <= 1.0) {
        // Nếu w, h <= 1.0 => Tọa độ đã chuẩn hóa (0..1), cần nhân ngược lên 512
        xc *= inputSize;
        yc *= inputSize;
        w *= inputSize;
        h *= inputSize;
      }

                        // Tọa độ trên ảnh 512x512
      double x1 = xc - w / 2;
      double y1 = yc - h / 2;

      // Quy chiếu về ảnh gốc
      int cropX = (x1 / inputSize * origW).toInt();
      int cropY = (y1 / inputSize * origH).toInt();
      int cropW = (w / inputSize * origW).toInt();
      int cropH = (h / inputSize * origH).toInt();

      // Ràng buộc giới hạn
      cropX = max(0, cropX);
      cropY = max(0, cropY);
      cropW = min(origW - cropX, max(1, cropW));
      cropH = min(origH - cropY, max(1, cropH));

      img.Image cropped = img.copyCrop(originalImage, x: cropX, y: cropY, width: cropW, height: cropH);
      
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/crop_${DateTime.now().millisecondsSinceEpoch}_$index.jpg';
      File(path).writeAsBytesSync(img.encodeJpg(cropped));
      return path;
    }

    String croppedFoodPath = await cropAndSave(maxFoodIndex);
    String? croppedLabelPath;
    if (maxLabelIndex != -1) {
      croppedLabelPath = await cropAndSave(maxLabelIndex);
    }

    return {
      'foodImagePath': croppedFoodPath,
      'labelImagePath': croppedLabelPath,
    };
  }

  /// 2. CHẠY MODEL PHÂN LOẠI MÓN ĂN
  Future<String> classifyFood(String croppedImagePath) async {
    await init();

    final File imageFile = File(croppedImagePath);
    final img.Image? originalImage = img.decodeImage(imageFile.readAsBytesSync());
    if (originalImage == null) throw Exception("Không thể đọc ảnh để phân loại");

    // Thường model Classification như EfficientNet dùng size 224x224
        final int inputSize = 224;
    img.Image resizedImage = img.copyResize(originalImage, width: inputSize, height: inputSize);

    var input = List.generate(
      1,
      (i) => List.generate(
        inputSize,
        (y) => List.generate(
          inputSize,
          (x) {
            final pixel = resizedImage.getPixel(x, y);
            return [
              pixel.r.toDouble(),
              pixel.g.toDouble(),
              pixel.b.toDouble(),
            ];
          },
        ),
      ),
    );

    // Output là 1 mảng 1x12 (12 classes)
    var output = List.filled(1 * 12, 0.0).reshape([1, 12]);

    _classifyInterpreter!.run(input, output);

    // Tìm giá trị cao nhất (Argmax)
    double maxProb = 0.0;
    int maxIndex = 0;
    for (int i = 0; i < 12; i++) {
      if (output[0][i] > maxProb) {
        maxProb = output[0][i];
        maxIndex = i;
      }
    }

    return labels[maxIndex]; // Trả về chữ "Thịt bò"
  }

  /// 3. CHẠY MODEL ML KIT ĐỂ ĐỌC CHỮ VÀ BÓC TÁCH KHỐI LƯỢNG (Bản chuẩn Python model2.py)
  Future<String?> readLabelWeight(String labelImagePath) async {
    final inputImage = InputImage.fromFilePath(labelImagePath);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      
      List<String> lines = [];
      for (TextBlock block in recognizedText.blocks) {
        for (TextLine line in block.lines) {
          lines.add(line.text);
        }
      }
      
      if (lines.isEmpty) return null;
      String fullText = lines.join(" ");
      
      int klIndex = -1;
      int donGiaIndex = -1;
      
      for (int i = 0; i < lines.length; i++) {
        final word = lines[i].toLowerCase();
        if (RegExp(r'kl|khối|trọng').hasMatch(word)) {
          klIndex = i;
        }
        if (RegExp(r'don\s*gia|giá').hasMatch(word)) {
          donGiaIndex = i;
        }
      }

      String? weightCandidate;
      String context = "";

      // Logic 1: Tìm từ vị trí KL
      if (klIndex != -1) {
        int end = min(lines.length, klIndex + 5);
        context = lines.sublist(max(0, klIndex), end).join(" ");
        
        final match = RegExp(r'(\d+[\.,]?\d*)\s*(g|kg|gram)', caseSensitive: false).firstMatch(context);
        if (match != null) {
          String numStr = match.group(1)!.replaceAll(',', '.');
          try {
            double val = double.parse(numStr);
            if ('.'.allMatches(numStr).length <= 1) {
               if (!numStr.contains('.') && !numStr.contains(',') && numStr.length >= 4 && numStr.startsWith('0')) {
                   val = val / 1000;
               }
               if (val >= 0.001 && val <= 5000) {
                 String valStr = (val == val.toInt()) ? val.toInt().toString() : val.toString().replaceAll(RegExp(r'0*$'), '').replaceAll(RegExp(r'\.$'), '');
                 weightCandidate = '$valStr${match.group(2)!.toUpperCase()}';
               }
            }
          } catch (e) {}
        }
      }

      // Logic 2: Tìm từ vị trí Đơn giá
      if (weightCandidate == null && donGiaIndex != -1) {
        int end = min(lines.length, donGiaIndex + 5);
        String dgContext = lines.sublist(max(0, donGiaIndex), end).join(" ");
        final match = RegExp(r'(\d+[\.,]?\d*)\s*(g|kg|gram)', caseSensitive: false).firstMatch(dgContext);
        if (match != null) {
          String numStr = match.group(1)!.replaceAll(',', '.');
          try {
            double val = double.parse(numStr);
            if ('.'.allMatches(numStr).length <= 1 && val >= 0.001 && val <= 5000) {
              String valStr = (val == val.toInt()) ? val.toInt().toString() : val.toString().replaceAll(RegExp(r'0*$'), '').replaceAll(RegExp(r'\.$'), '');
              weightCandidate = '$valStr${match.group(2)!.toUpperCase()}';
            }
          } catch (e) {}
        }
      }

      // Logic 3: Chạy Regex vét máng (Tương đương _extract_by_regex)
      weightCandidate ??= _extractByRegex(fullText);

      // Logic 4: Fallback số đơn lẻ quanh khu vực KL
      if (weightCandidate == null && klIndex != -1) {
        final matches = RegExp(r'(\d+[\.,]?\d*)').allMatches(context);
        for (final m in matches) {
           String numStr = m.group(1)!.replaceAll(',', '.');
           try {
              double val = double.parse(numStr);
              if ('.'.allMatches(numStr).length <= 1 && val > 0 && val <= 5000) {
                 if (val > 1000 && numStr.endsWith('9') && numStr.length <= 4) {
                    val = (val - 9) / 10; // OCR sửa sai 5009 -> 500
                 }
                 String dv = (val < 15) ? 'KG' : 'G';
                 String valStr = (val == val.toInt()) ? val.toInt().toString() : val.toString().replaceAll(RegExp(r'0*$'), '').replaceAll(RegExp(r'\.$'), '');
                 weightCandidate = '$valStr$dv';
                 break;
              }
           } catch (e) {}
        }
      }

      // Sửa lỗi chính tả 9G -> G (VD 5009G -> 500G)
      if (weightCandidate != null) {
          weightCandidate = weightCandidate.replaceAll(RegExp(r'9G$', caseSensitive: false), 'G');
      }

      return weightCandidate;
    } catch (e) {
      return null;
    } finally {
      textRecognizer.close();
    }
  }

  String? _extractByRegex(String vanBanTho) {
    if (vanBanTho.isEmpty) return null;

    String vanBanSach = vanBanTho.replaceAll(RegExp(r'\b\d+[.,]\d+[.,]\d+\b'), '');
    vanBanSach = vanBanSach.replaceAll(RegExp(r'\b\d{6,}\b'), '');

    final patternKw = RegExp(r'(?:khối lượng|khoi luong|trọng lượng|trong luong|kl|tl|khối lượng tịnh)\s*(?:tịnh|tinh)?[^\d]{0,15}?(\d+(?:[.,]\d+)?)\s*(g|kg|gr|k)?', caseSensitive: false);
    for (final m in patternKw.allMatches(vanBanSach)) {
      try {
        double so = double.parse(m.group(1)!.replaceAll(',', '.'));
        if (so > 0 && so <= 50000) {
           String dv = (so < 15) ? 'KG' : 'G';
           if (m.groupCount >= 2 && m.group(2) != null) {
              dv = (m.group(2)!.toUpperCase() == 'K') ? 'KG' : m.group(2)!.toUpperCase();
           }
           String soStr = (so == so.toInt()) ? so.toInt().toString() : so.toString().replaceAll(RegExp(r'0*$'), '').replaceAll(RegExp(r'\.$'), '');
           return '$soStr$dv';
        }
      } catch (e) {}
    }

    final patternUnit = RegExp(r'(?<![a-zA-Z])(\d+(?:[.,]\d+)?)\s*(g|kg|gr|k)(?![a-zA-Z])', caseSensitive: false);
    for (final m in patternUnit.allMatches(vanBanSach)) {
      try {
        double so = double.parse(m.group(1)!.replaceAll(',', '.'));
        if (so >= 0.01 && so <= 50000) {
           String dv = (so < 15) ? 'KG' : 'G';
           if (m.groupCount >= 2 && m.group(2) != null) {
              dv = (m.group(2)!.toUpperCase() == 'K') ? 'KG' : m.group(2)!.toUpperCase();
           }
           String soStr = (so == so.toInt()) ? so.toInt().toString() : so.toString().replaceAll(RegExp(r'0*$'), '').replaceAll(RegExp(r'\.$'), '');
           return '$soStr$dv';
        }
      } catch (e) {}
    }

    final numbers = RegExp(r'(?<![a-zA-Z])(\d+(?:[.,]\d+)?)(?![a-zA-Z])').allMatches(vanBanSach);
    for (final m in numbers) {
      try {
        double val = double.parse(m.group(1)!.replaceAll(',', '.'));
        if (val > 1000 && m.group(1)!.endsWith('9') && m.group(1)!.length <= 4) {
           val = (val - 9) / 10;
        }

        if (val > 0 && val <= 5000) {
           if (m.group(1)!.length == 3 && m.group(1)!.startsWith('0') && val < 100) {
              val = val / 100.0;
           }
           String dv = (val < 15) ? 'KG' : 'G';
           String valStr = (val == val.toInt()) ? val.toInt().toString() : val.toString().replaceAll(RegExp(r'0*$'), '').replaceAll(RegExp(r'\.$'), '');
           return '$valStr$dv';
        }
      } catch (e) {}
    }

    return null;
  }
}
















