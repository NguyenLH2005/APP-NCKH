import 'dart:convert';

import '../../data/models/scan_history_model.dart';
import '../../data/repositories/food_repository.dart';
import '../../data/datasources/local/ai_helper.dart';

class AnalyzeFoodUseCase {
  final FoodRepository repository;

  AnalyzeFoodUseCase(this.repository);

  // Hàm phân tích chính
  Future<ScanHistory?> execute(String imagePath) async {
    try {
      // 1. CHẠY AI THẬT
      // Bước 1: Dò và cắt ảnh
      final croppedImages = await AIHelper.instance.detectAndCrop(imagePath);
      final String croppedFoodImage = croppedImages['foodImagePath']!;
      final String? croppedLabelImage = croppedImages['labelImagePath'];

      // Bước 2: Phân loại món ăn từ ảnh thịt đã cắt
      final String detectedName = await AIHelper.instance.classifyFood(croppedFoodImage);

      // BẢN ĐỒ ÁNH XẠ: Chuyển tên từ AI sang tên chuẩn của File CSV
      final Map<String, String> csvNameMapper = {
        'Bạch tuộc': 'mực, tươi', 
        'Cà chua': 'cà chua, tươi',
        'Cá hồi': 'cá hồi, tươi',
        'Cà rốt': 'củ cà rốt, tươi',
        'Chuối': 'chuối tiêu, tươi', 
        'Dưa leo': 'dưa chuột, tươi', 
        'Mực': 'mực, tươi',
        'Táo': 'táo tây, tươi', 
        'Thịt bò': 'thịt bò, bắp, sống', 
        'Thịt gà': 'thịt gà ta, tươi',
        'Thịt heo': 'thịt lợn, nạc vai, tươi', 
        'Tôm': 'tôm biển, tươi',
      };
      
      final String searchString = csvNameMapper[detectedName] ?? detectedName;

      // Bước 3: Đọc khối lượng từ tem (OCR)
      double? rawWeightValue;
      String rawWeightUnit = "g"; // Đơn vị mặc định

      if (croppedLabelImage != null) {
        final String? weightString = await AIHelper.instance.readLabelWeight(croppedLabelImage);
        if (weightString != null) {
          // weightString có dạng "250G" hoặc "1.5KG"
          final match = RegExp(r'([\d\.]+)(KG|G)').firstMatch(weightString);
          if (match != null) {
            rawWeightValue = double.tryParse(match.group(1)!);
            rawWeightUnit = match.group(2)!.toLowerCase(); // 'g' hoặc 'kg'
          }
        }
      }
      
      // Chuẩn hóa khối lượng về gram (Nếu có khối lượng)
      double? detectedWeightInGrams;
      if (rawWeightValue != null) {
        detectedWeightInGrams = _normalizeToGrams(rawWeightValue, rawWeightUnit);
      }

      // 2. TRA CỨU TỪ ĐIỂN CSV
      final foodData = repository.findFoodByName(searchString);
      if (foodData == null) {
        throw Exception("Không tìm thấy '$detectedName' trong cơ sở dữ liệu!");
      }

      // Lấy các chỉ số gốc trên 100g (Lưu ý: đã đổi tên energy thành Năng lượng)
      final double energy100g = double.tryParse(foodData['Năng lượng']?.toString() ?? '0') ?? 0;
      final double protein100g = double.tryParse(foodData['Chất đạm']?.toString() ?? '0') ?? 0;
      final double fat100g = double.tryParse(foodData['Chất béo (Fat)']?.toString() ?? '0') ?? 0;
      final double carb100g = double.tryParse(foodData['Chất bột đường']?.toString() ?? '0') ?? 0;
      final double fiber100g = double.tryParse(foodData['Chất xơ']?.toString() ?? '0') ?? 0;

      // Lấy linh động Đơn vị (Unit) từ CSV. Nếu cột trống thì mặc định là 'g'
      final String proteinUnit = foodData['Chất đạm_unit']?.toString().trim() ?? 'g';
      final String fatUnit = foodData['Chất béo (Fat)_unit']?.toString().trim() ?? 'g';
      final String carbUnit = foodData['Chất bột đường_unit']?.toString().trim() ?? 'g';
      final String fiberUnit = foodData['Chất xơ_unit']?.toString().trim() ?? 'g';

      // 3. TÍNH TOÁN & ĐÓNG GÓI JSON
      // Nếu không có khối lượng, tỷ lệ tính toán (ratio) mặc định là 1 (tương đương 100g)
      final ratio = detectedWeightInGrams != null ? (detectedWeightInGrams / 100) : 1.0;

      // BẮT BUỘC: Năng lượng và 4 chất chính luôn được hiển thị (kể cả = 0)
      final List<Map<String, dynamic>> nutritionArray = [
        {
          "id": "energy", // ID giữ nguyên để UI map đúng
          "name": "Năng lượng",
          "per_100g": energy100g,
          "per_label": double.parse((energy100g * ratio).toStringAsFixed(1)),
          "unit": "kcal",
        },
        {
          "id": "protein",
          "name": "Protein",
          "per_100g": protein100g,
          "per_label": double.parse((protein100g * ratio).toStringAsFixed(1)),
          "unit": proteinUnit.isNotEmpty ? proteinUnit : 'g',
        },
        {
          "id": "total_fat",
          "name": "Chất béo (Fat)",
          "per_100g": fat100g,
          "per_label": double.parse((fat100g * ratio).toStringAsFixed(1)),
          "unit": fatUnit.isNotEmpty ? fatUnit : 'g',
        },
        {
          "id": "carb",
          "name": "Carb",
          "per_100g": carb100g,
          "per_label": double.parse((carb100g * ratio).toStringAsFixed(1)),
          "unit": carbUnit.isNotEmpty ? carbUnit : 'g',
        },
        {
          "id": "fiber",
          "name": "Chất xơ",
          "per_100g": fiber100g,
          "per_label": double.parse((fiber100g * ratio).toStringAsFixed(1)),
          "unit": fiberUnit.isNotEmpty ? fiberUnit : 'g',
        },
      ];

      // ĐỘNG: Duyệt qua toàn bộ các chất phụ còn lại (Vitamin, Tro, Nước...)
      // Tạo danh sách các cột không được quét (vì đã có ở trên rồi)
      final coreKeys = [
        'code', 'name_vi', 'category', 
        'Năng lượng', 'Chất đạm', 'Chất béo (Fat)', 'Chất bột đường', 'Chất xơ'
      ];
      
      for (var entry in foodData.entries) {
        final key = entry.key;
        final value = entry.value;
        
        // Bỏ qua các cột core hoặc cột mang tính chất _unit
        if (coreKeys.contains(key) || key.endsWith('_unit')) {
          continue;
        }

        // Cố gắng parse số. Trường hợp value rỗng "" hoặc null sẽ ra 0
        final numValue = double.tryParse(value?.toString() ?? '') ?? 0.0;
        
        // YÊU CẦU: CHỈ THÊM VÀO nếu lớn hơn 0
        if (numValue > 0) {
          // Lấy unit tương ứng (ví dụ: key là "Vitamin C" thì tìm key "Vitamin C_unit")
          final unitKey = '${key}_unit';
          final unitStr = foodData[unitKey]?.toString().trim() ?? '';
          
          nutritionArray.add({
            "id": key, // Lấy tên cột làm id
            "name": key,
            "per_100g": numValue,
            "per_label": double.parse((numValue * ratio).toStringAsFixed(2)),
            "unit": unitStr,
          });
        }
      }

      // Đóng gói thành chuỗi TEXT
      final String jsonNutritionData = jsonEncode(nutritionArray);

      // 4. TRẢ VỀ ĐỐI TƯỢNG LỊCH SỬ HOÀN CHỈNH
      return ScanHistory(
        originalImage: imagePath,
        croppedFoodImage: croppedFoodImage,
        croppedLabelImage: croppedLabelImage,
        foodName: detectedName,
        weight: detectedWeightInGrams,
        nutritionData: jsonNutritionData,
        createdAt: DateTime.now(),
      );
    } catch (e) {
      print("Lỗi luồng phân tích: $e");
      return null;
    }
  }

  // Hàm chuẩn hóa mọi đơn vị khối lượng về Gram (g)
  double _normalizeToGrams(double value, String unit) {
    switch (unit.toLowerCase()) {
      case 'kg':
      case 'kilogram':
        return value * 1000;
      case 'mg':
      case 'milligram':
        return value / 1000;
      case 'g':
      case 'gram':
      default:
        // Mặc định coi như là gram nếu không xác định được
        return value;
    }
  }
}
