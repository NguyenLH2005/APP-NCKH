import 'package:flutter/services.dart';
import 'package:csv/csv.dart';

class FoodRepository {
  // Biến lưu trữ dữ liệu CSV trên RAM dạng Map để tra cứu
  // Key: tên món ăn đã chuẩn hóa, Value: dữ liệu 1 dòng của món đó
  final Map<String, List<dynamic>> _foodData = {};
  List<String> _headers = [];

  // Hàm đọc file CSV (chỉ gọi 1 lần khi khởi động app)
  Future<void> loadCsvData() async {
    try {
      final rawData = await rootBundle.loadString(
        'assets/db/gia_tri_dinh_duong_thuc_pham.csv',
      );
      
      List<List<dynamic>> rowsAsListOfValues = Csv().decode(rawData);

      if (rowsAsListOfValues.isNotEmpty) {
        _headers = rowsAsListOfValues.first.map((e) => e.toString()).toList(); // Lấy dòng đầu làm tiêu đề

        for (int i = 1; i < rowsAsListOfValues.length; i++) {
          final row = rowsAsListOfValues[i];
          if (row.length > 1) {
            // Giả sử cột index 1 là Tên món ăn (name_vi)
            final String rawName = row[1].toString();
            final String normalizedName = _normalizeString(rawName);
            _foodData[normalizedName] = row;
          }
        }
      }
      print("Đã load thành công ${_foodData.length} món ăn vào RAM!");
    } catch (e) {
      print("Lỗi khi đọc file CSV: $e");
    }
  }

  // Hàm chuẩn hóa chuỗi (chữ thường, bỏ khoảng trắng thừa)
  String _normalizeString(String input) {
    return input.trim().toLowerCase();
  }

  // Hàm tra cứu gần đúng (Substring matching), ưu tiên tên ngắn nhất
  Map<String, dynamic>? findFoodByName(String name) {
    final searchName = _normalizeString(name);
    
    String? bestMatchKey;
    
    for (String key in _foodData.keys) {
      if (key.contains(searchName)) {
        if (bestMatchKey == null || key.length < bestMatchKey.length) {
          bestMatchKey = key;
        }
      }
    }

    if (bestMatchKey != null) {
      final rowData = _foodData[bestMatchKey]!;
      // Ghép Header với Dữ liệu thành một Map cho dễ lấy
      return Map.fromIterables(_headers, rowData);
    }
    
    return null;
  }
}
