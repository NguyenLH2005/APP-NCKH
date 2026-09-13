import 'dart:convert';

class ScanHistory {
  final int? id;
  final String originalImage;
  final String croppedFoodImage;
  final String? croppedLabelImage;
  final String foodName;
  final double? weight;
  final String nutritionData; // Chuỗi JSON chứa toàn bộ dinh dưỡng
  final DateTime createdAt;

  ScanHistory({
    this.id,
    required this.originalImage,
    required this.croppedFoodImage,
    this.croppedLabelImage,
    required this.foodName,
    this.weight,
    required this.nutritionData,
    required this.createdAt,
  });

  // Chuyển Object thành Map để Insert vào SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'original_image': originalImage,
      'cropped_food_image': croppedFoodImage,
      'cropped_label_image': croppedLabelImage,
      'food_name': foodName,
      'weight': weight,
      'nutrition_data': nutritionData,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // Lấy data từ SQLite ra và chuyển ngược lại thành Object
  factory ScanHistory.fromMap(Map<String, dynamic> map) {
    return ScanHistory(
      id: map['id'],
      originalImage: map['original_image'],
      croppedFoodImage: map['cropped_food_image'],
      croppedLabelImage: map['cropped_label_image'],
      foodName: map['food_name'],
      weight: map['weight'],
      nutritionData: map['nutrition_data'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  // Hàm phụ trợ siêu tiện lợi: Gọi hàm này để UI vẽ bảng chi tiết dinh dưỡng luôn
  List<dynamic> get decodedNutrition => jsonDecode(nutritionData);
}
