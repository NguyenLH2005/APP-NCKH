import 'dart:convert';

class ScanHistory {
  final int? id;
  final String originalImage;
  final String croppedFoodImage;
  final String? croppedLabelImage;
  final String? originalImageBase64;
  final String? foodImageBase64;
  final String? labelImageBase64;
  final String foodName;
  final double? weight;
  final String nutritionData;
  final String mainGroup; // Nhóm dinh dưỡng chính (từ CSV)
  final DateTime createdAt;
  final int isSynced; // 0: chưa sync, 1: đã sync
  final DateTime? updatedAt;

  ScanHistory({
    this.id,
    required this.originalImage,
    required this.croppedFoodImage,
    this.croppedLabelImage,
    this.originalImageBase64,
    this.foodImageBase64,
    this.labelImageBase64,
    required this.foodName,
    this.weight,
    required this.nutritionData,
    required this.mainGroup,
    required this.createdAt,
    this.isSynced = 0,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'original_image': originalImage,
      'cropped_food_image': croppedFoodImage,
      'cropped_label_image': croppedLabelImage,
      'original_image_base64': originalImageBase64,
      'food_image_base64': foodImageBase64,
      'label_image_base64': labelImageBase64,
      'food_name': foodName,
      'weight': weight,
      'nutrition_data': nutritionData,
      'main_group': mainGroup,
      'created_at': createdAt.toIso8601String(),
      'is_synced': isSynced,
      'updated_at': (updatedAt ?? createdAt).toIso8601String(),
    };
  }

  factory ScanHistory.fromMap(Map<String, dynamic> map) {
    return ScanHistory(
      id: map['id'],
      originalImage: map['original_image'] ?? '',
      croppedFoodImage: map['cropped_food_image'] ?? '',
      croppedLabelImage: map['cropped_label_image'],
      originalImageBase64: map['original_image_base64'],
      foodImageBase64: map['food_image_base64'],
      labelImageBase64: map['label_image_base64'],
      foodName: map['food_name'] ?? 'Món ăn',
      weight: map['weight'],
      nutritionData: map['nutrition_data'] ?? '[]',
      mainGroup: map['main_group'] ?? 'Chưa phân loại',
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : DateTime.now(),
      isSynced: map['is_synced'] ?? 0,
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
    );
  }

  ScanHistory copyWith({
    int? id,
    String? originalImage,
    String? croppedFoodImage,
    String? croppedLabelImage,
    String? originalImageBase64,
    String? foodImageBase64,
    String? labelImageBase64,
    String? foodName,
    double? weight,
    String? nutritionData,
    String? mainGroup,
    DateTime? createdAt,
    int? isSynced,
    DateTime? updatedAt,
  }) {
    return ScanHistory(
      id: id ?? this.id,
      originalImage: originalImage ?? this.originalImage,
      croppedFoodImage: croppedFoodImage ?? this.croppedFoodImage,
      croppedLabelImage: croppedLabelImage ?? this.croppedLabelImage,
      originalImageBase64: originalImageBase64 ?? this.originalImageBase64,
      foodImageBase64: foodImageBase64 ?? this.foodImageBase64,
      labelImageBase64: labelImageBase64 ?? this.labelImageBase64,
      foodName: foodName ?? this.foodName,
      weight: weight ?? this.weight,
      nutritionData: nutritionData ?? this.nutritionData,
      mainGroup: mainGroup ?? this.mainGroup,
      createdAt: createdAt ?? this.createdAt,
      isSynced: isSynced ?? this.isSynced,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  List<dynamic> get decodedNutrition => jsonDecode(nutritionData);

  static String formatWeightValue(double weight, {bool spaceBeforeUnit = true}) {
    final sep = spaceBeforeUnit ? ' ' : '';
    if (weight >= 1000) {
      final val = (weight / 1000)
          .toStringAsFixed(2)
          .replaceAll(RegExp(r'0*$'), '')
          .replaceAll(RegExp(r'\.$'), '');
      return '$val${sep}kg';
    }
    final val = weight
        .toStringAsFixed(2)
        .replaceAll(RegExp(r'0*$'), '')
        .replaceAll(RegExp(r'\.$'), '');
    return '$val${sep}g';
  }

  String formatWeight({String fallback = '100 g', bool spaceBeforeUnit = true}) {
    if (weight == null) return fallback;
    return formatWeightValue(weight!, spaceBeforeUnit: spaceBeforeUnit);
  }
}
