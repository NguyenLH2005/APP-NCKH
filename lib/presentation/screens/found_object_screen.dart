import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/history_controller.dart';

import '../../data/models/scan_history_model.dart';
import 'result_screen.dart';
import '../widgets/full_screen_image.dart';

class FoundObjectScreen extends ConsumerWidget {
  final ScanHistory resultData;

  const FoundObjectScreen({super.key, required this.resultData});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Trích xuất 5 chất chính từ JSON
    final nutritionList = resultData.decodedNutrition;
    
    Map<String, dynamic> energy = {'per_label': 0, 'unit': 'kcal'};
    Map<String, dynamic> protein = {'per_label': 0, 'unit': 'g'};
    Map<String, dynamic> fat = {'per_label': 0, 'unit': 'g'};
    Map<String, dynamic> carb = {'per_label': 0, 'unit': 'g'};
    Map<String, dynamic> fiber = {'per_label': 0, 'unit': 'g'};

    for (var item in nutritionList) {
      if (item['id'] == 'energy') energy = item;
      if (item['id'] == 'protein') protein = item;
      if (item['id'] == 'total_fat') fat = item;
      if (item['id'] == 'carb') carb = item;
      if (item['id'] == 'fiber') fiber = item;
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Kết quả tra cứu',
          style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.grey.shade50,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.green),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'delete') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Xác nhận xóa'),
                    content: const Text('Bạn có chắc chắn muốn xóa kết quả tra cứu này không?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Không', style: TextStyle(color: Colors.grey)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Có', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  await ref.read(historyControllerProvider.notifier).deleteRecords([resultData]);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Xóa thành công!')),
                    );
                    Navigator.pop(context);
                  }
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Text('Xóa kết quả tra cứu', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 1. Ảnh món ăn và Nhãn (Đã cắt)
            Row(
              children: [
                // Ô bên trái: Ảnh món ăn đã cắt
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FullScreenImage(
                            imageFile: File(resultData.croppedFoodImage),
                          ),
                        ),
                      );
                    },
                    child: Hero(
                      tag: resultData.croppedFoodImage,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(resultData.croppedFoodImage),
                          height: 120,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            height: 120,
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.fastfood, color: Colors.grey),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                
                // Ô bên phải: Ảnh nhãn khối lượng đã cắt (Nếu có)
                Expanded(
                  child: resultData.croppedLabelImage != null && resultData.croppedLabelImage!.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FullScreenImage(
                                imageFile: File(resultData.croppedLabelImage!),
                              ),
                            ),
                          );
                        },
                        child: Hero(
                          tag: resultData.croppedLabelImage!,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              File(resultData.croppedLabelImage!),
                              height: 120,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                height: 120,
                                color: Colors.grey.shade200,
                                child: const Center(
                                  child: Text('Lỗi tải ảnh', style: TextStyle(color: Colors.grey)),
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          height: 120,
                          color: Colors.grey.shade200,
                          child: const Center(
                            child: Text(
                              'Không có nhãn',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        ),
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 2. Tên món ăn và Khối lượng
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      resultData.foodName.isNotEmpty 
                          ? '${resultData.foodName[0].toUpperCase()}${resultData.foodName.substring(1)}'
                          : '',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B233A),
                      ),
                    ),
                  ),
                  Text(
                    resultData.weight != null 
                        ? (resultData.weight! >= 1000 
                            ? '${(resultData.weight! / 1000).toStringAsFixed(2).replaceAll(RegExp(r'0*$'), '').replaceAll(RegExp(r'\.$'), '')} kg' 
                            : '${resultData.weight!.toStringAsFixed(2).replaceAll(RegExp(r'0*$'), '').replaceAll(RegExp(r'\.$'), '')} g')
                        : 'Giá trị dinh dưỡng trên 100g',
                    style: TextStyle(
                      fontSize: resultData.weight != null ? 20 : 14,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1B233A),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 3. Card Năng lượng
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: const Border(left: BorderSide(color: Colors.red, width: 4)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tổng Năng Lượng',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${energy['per_label']} ${energy['unit'] == 'kcal' ? 'Kcal' : energy['unit']}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFD32F2F),
                        ),
                      ),
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
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ResultScreen(resultData: resultData),
                  ),
                );
              },
              child: const Text(
                'Xem chi tiết giá trị dinh dưỡng >',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildNutrientCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}


