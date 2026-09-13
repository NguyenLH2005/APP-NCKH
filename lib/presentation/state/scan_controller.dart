import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/usecases/analyze_food_usecase.dart';
import '../../data/models/scan_history_model.dart';
import '../../data/repositories/food_repository.dart';

// 1. THÊM DÒNG IMPORT NÀY VÀO TRÊN CÙNG
import '../../data/datasources/local/database_helper.dart';

// 1. Cung cấp Repository và UseCase
final foodRepositoryProvider = Provider((ref) => FoodRepository());
final analyzeUseCaseProvider = Provider((ref) {
  return AnalyzeFoodUseCase(ref.read(foodRepositoryProvider));
});

// Provider quản lý Lịch sử (Tự động load lại khi bị invalidate)
final historyProvider = FutureProvider<List<ScanHistory>>((ref) async {
  return await DatabaseHelper.instance.getAllScans();
});

// 2. Định nghĩa các trạng thái của màn hình
enum ScanStatus { initial, loading, success, error }

class ScanState {
  final ScanStatus status;
  final ScanHistory? result;

  ScanState({this.status = ScanStatus.initial, this.result});
}

// 3. Controller điều phối luồng chạy
class ScanController extends Notifier<ScanState> {
  @override
  ScanState build() => ScanState();

  Future<void> startAnalysis(String imagePath) async {
    // Chuyển UI sang trạng thái Loading
    state = ScanState(status: ScanStatus.loading);

    final useCase = ref.read(analyzeUseCaseProvider);
    final result = await useCase.execute(imagePath);

    if (result != null) {
      // 2. LƯU VÀO SQLITE NGAY TẠI ĐÂY TRƯỚC KHI BÁO SUCCESS CHO UI
      try {
        await DatabaseHelper.instance.insertScan(result);
        print("Đã lưu kết quả quét vào SQLite thành công!");
        
        // Cập nhật lại danh sách lịch sử trên toàn app
        ref.invalidate(historyProvider);
      } catch (e) {
        print("Lỗi khi lưu SQLite: $e");
      }

      // Đẩy kết quả sang màn hình ResultScreen
      state = ScanState(status: ScanStatus.success, result: result);
    } else {
      state = ScanState(status: ScanStatus.error);
    }
  }
}

// Biến toàn cục để UI gọi đến Controller
final scanControllerProvider = NotifierProvider<ScanController, ScanState>(
  ScanController.new,
);
