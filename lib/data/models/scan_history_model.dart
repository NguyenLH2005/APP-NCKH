import 'dart:convert';

class ScanHistory {
  final int? id;
  final String originalImage;
  final String croppedFoodImage;
  final String? croppedLabelImage;
  final String foodName;
  final double? weight;
  final String nutritionData;
  final String mainGroup; // Nhóm dinh dưỡng chính (từ CSV)
  final DateTime createdAt;

  ScanHistory({
    this.id,
    required this.originalImage,
    required this.croppedFoodImage,
    this.croppedLabelImage,
    required this.foodName,
    this.weight,
    required this.nutritionData,
    required this.mainGroup,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'original_image': originalImage,
      'cropped_food_image': croppedFoodImage,
      'cropped_label_image': croppedLabelImage,
      'food_name': foodName,
      'weight': weight,
      'nutrition_data': nutritionData,
      'main_group': mainGroup,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory ScanHistory.fromMap(Map<String, dynamic> map) {
    return ScanHistory(
      id: map['id'],
      originalImage: map['original_image'],
      croppedFoodImage: map['cropped_food_image'],
      croppedLabelImage: map['cropped_label_image'],
      foodName: map['food_name'],
      weight: map['weight'],
      nutritionData: map['nutrition_data'],
      mainGroup: map['main_group'] ?? 'Chưa phân loại',
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  List<dynamic> get decodedNutrition => jsonDecode(nutritionData);
}
