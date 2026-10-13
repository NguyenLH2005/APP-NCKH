import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/scan_history_model.dart';
import '../../data/datasources/local/database_helper.dart';
import '../../domain/usecases/nutrition_suggestion_usecase.dart';

import '../state/scan_controller.dart';
import '../state/profile_controller.dart';

import 'result_screen.dart';
import 'profile_screen.dart';
import '../widgets/full_screen_image.dart';

class FoundObjectScreen extends ConsumerStatefulWidget {
  final ScanHistory resultData;

  const FoundObjectScreen({super.key, required this.resultData});

  @override
  ConsumerState<FoundObjectScreen> createState() => _FoundObjectScreenState();
}

class _FoundObjectScreenState extends ConsumerState<FoundObjectScreen> {
  late ScanHistory _currentData;

  @override
  void initState() {
    super.initState();
    _currentData = widget.resultData;
  }

  Future<void> _editWeight() async {
    TextEditingController controller = TextEditingController(text: _currentData.weight?.toString() ?? '100');
    final newWeightStr = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nhập khối lượng mới (g)'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'Ví dụ: 250'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Lưu')),
        ],
      ),
    );

    if (newWeightStr != null && newWeightStr.isNotEmpty) {
      double? newWeight = double.tryParse(newWeightStr);
      if (newWeight != null && newWeight > 0) {
        // Cập nhật json
        List<dynamic> jsonArr = jsonDecode(_currentData.nutritionData);
        for (var item in jsonArr) {
          if (item['per_100g'] != null) {
            item['per_label'] = double.parse(((item['per_100g'] as num) * (newWeight / 100)).toStringAsFixed(1));
          }
        }
        
        final updatedData = ScanHistory(
          id: _currentData.id,
          originalImage: _currentData.originalImage,
          croppedFoodImage: _currentData.croppedFoodImage,
          croppedLabelImage: _currentData.croppedLabelImage,
          foodName: _currentData.foodName,
          weight: newWeight,
          nutritionData: jsonEncode(jsonArr),
          mainGroup: _currentData.mainGroup,
          createdAt: _currentData.createdAt,
        );

        await DatabaseHelper.instance.updateScan(updatedData);
        ref.invalidate(historyProvider);

        setState(() {
          _currentData = updatedData;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final nutritionList = _currentData.decodedNutrition;
    
    Map<String, dynamic> energy = {'per_label': 0, 'unit': 'kcal'};
    Map<String, dynamic> protein = {'per_label': 0, 'unit': 'g'};
    Map<String, dynamic> fat = {'per_label': 0, 'unit': 'g'};
    Map<String, dynamic> carb = {'per_label': 0, 'unit': 'g'};
    Map<String, dynamic> fiber = {'per_label': 0, 'unit': 'g'};

    for (var item in nutritionList) {
      if (item['id'] == 'energy') energy = item;
      if (item['id'] == 'protein') protein = item;
      if (item['id'] == 'fat') fat = item;
      if (item['id'] == 'carb') carb = item;
      if (item['id'] == 'fiber') fiber = item;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Kết quả quét', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Ảnh hiển thị
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => FullScreenImage(imageFile: File(_currentData.croppedFoodImage))));
                      },
                      child: Hero(
                        tag: _currentData.croppedFoodImage,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(File(_currentData.croppedFoodImage), height: 120, fit: BoxFit.cover),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: _currentData.croppedLabelImage != null
                        ? GestureDetector(
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => FullScreenImage(imageFile: File(_currentData.croppedLabelImage!))));
                            },
                            child: Hero(
                              tag: _currentData.croppedLabelImage!,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(File(_currentData.croppedLabelImage!), height: 120, fit: BoxFit.cover),
                              ),
                            ),
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Container(height: 120, color: Colors.grey.shade200, child: const Center(child: Text('Không có nhãn', style: TextStyle(color: Colors.grey)))),
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 2. Tên món ăn và Khối lượng (Chỉnh sửa được)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))]),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _currentData.foodName.isNotEmpty ? '${_currentData.foodName[0].toUpperCase()}${_currentData.foodName.substring(1)}' : '',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1B233A)),
                      ),
                    ),
                    InkWell(
                      onTap: _editWeight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _currentData.weight != null 
                                ? (_currentData.weight! >= 1000 
                                    ? '${(_currentData.weight! / 1000).toStringAsFixed(2).replaceAll(RegExp(r'0*$'), '').replaceAll(RegExp(r'\.$'), '')} kg' 
                                    : '${_currentData.weight!.toStringAsFixed(2).replaceAll(RegExp(r'0*$'), '').replaceAll(RegExp(r'\.$'), '')} g')
                                : 'Giữ nguyên 100g',
                            style: TextStyle(
                              fontSize: _currentData.weight != null ? 20 : 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.edit, color: Colors.green, size: 20),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 3. Card Năng lượng
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: const Border(left: BorderSide(color: Colors.red, width: 4))),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Tổng Năng Lượng', style: TextStyle(fontSize: 14, color: Colors.black87)),
                        const SizedBox(height: 8),
                        Text('${energy['per_label']} ${energy['unit'] == 'kcal' ? 'Kcal' : energy['unit']}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFD32F2F))),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 4. Grid 4 chất
              Row(
                children: [
                  Expanded(child: _buildNutrientCard('Protein', '${protein['per_label']}${protein['unit']}', Colors.purple)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildNutrientCard('Chất béo (Fat)', '${fat['per_label']}${fat['unit']}', Colors.orange)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildNutrientCard('Carb', '${carb['per_label']}${carb['unit']}', Colors.blue)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildNutrientCard('Chất xơ', '${fiber['per_label']}${fiber['unit']}', Colors.green)),
                ],
              ),
              const SizedBox(height: 32),

              // 5. Nút xem chi tiết (Dạng chữ)
              TextButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => ResultScreen(resultData: _currentData)));
                },
                child: const Text('Xem chi tiết giá trị dinh dưỡng >', style: TextStyle(color: Colors.green, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 20),

              // 6. Gợi ý tư vấn dinh dưỡng
              const Text('TƯ VẤN DINH DƯỠNG', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
              const SizedBox(height: 10),
              Builder(
                builder: (ctx) {
                  final profileState = ref.watch(profileProvider);
                  if (profileState.tdee == null || profileState.profile == null) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.orange.shade200)),
                      child: Column(
                        children: [
                          const Text('Chưa có Hồ sơ cá nhân!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                          const SizedBox(height: 8),
                          const Text('Vui lòng thiết lập Chiều cao, Cân nặng để xem gợi ý dinh dưỡng.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black87)),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                            child: const Text('Thiết lập Hồ sơ', style: TextStyle(color: Colors.white)),
                          )
                        ],
                      ),
                    );
                  }

                  final rawFoodData = ref.read(foodRepositoryProvider).findFoodByName(_currentData.foodName);
                  if (rawFoodData == null) {
                    return const Text('Không tìm thấy dữ liệu gốc của món ăn.', style: TextStyle(color: Colors.grey));
                  }

                  final suggestionStr = NutritionSuggestionUseCase.generateSuggestion(
                    profile: profileState.profile!,
                    mainGroupStr: _currentData.mainGroup,
                    foodName: _currentData.foodName,
                    rawFoodData: rawFoodData,
                  );


                  if (suggestionStr == null) {
                    return const Text('Không đủ dữ liệu để tính toán.', style: TextStyle(color: Colors.grey));
                  }

                  final bool hasVeto = suggestionStr.contains('⛔') || suggestionStr.contains('🚨');
                  final bool hasWarning = suggestionStr.contains('⚠️');
                  final Color borderColor = hasVeto ? Colors.red : (hasWarning ? Colors.orange : Colors.green);
                  final String headerTitle = hasVeto 
                      ? '🚨 CẢNH BÁO Y TẾ ĐẶC BIỆT' 
                      : (hasWarning ? '⚠️ LƯU Ý SỨC KHỎE' : '💡 Lời khuyên cho bạn');
                  
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: hasVeto ? Colors.red.shade50 : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderColor.withValues(alpha: 0.7), width: hasVeto ? 1.5 : 1.0),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(headerTitle, style: TextStyle(fontWeight: FontWeight.bold, color: borderColor, fontSize: 16)),
                        const SizedBox(height: 12),
                        Text(suggestionStr, style: const TextStyle(fontSize: 15, height: 1.5, color: Colors.black87)),
                      ],
                    ),
                  );
                }
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNutrientCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border(left: BorderSide(color: color, width: 4))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 14, color: Colors.black87)),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}




