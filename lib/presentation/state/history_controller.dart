import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/local/database_helper.dart';
import '../../data/models/scan_history_model.dart';
import 'scan_controller.dart'; // To invalidate historyProvider

class HistoryController extends Notifier<void> {
  @override
  void build() {}

  Future<void> deleteRecords(List<ScanHistory> items) async {
    final ids = items.map((e) => e.id).whereType<int>().toList();
    if (ids.isEmpty) return;

    // Delete from local SQLite Database
    await DatabaseHelper.instance.deleteScans(ids);

    // Delete physical files
    for (var item in items) {
      _deleteFile(item.originalImage);
      _deleteFile(item.croppedFoodImage);
      if (item.croppedLabelImage != null && item.croppedLabelImage!.isNotEmpty) {
        _deleteFile(item.croppedLabelImage!);
      }
    }

    // Invalidate history to reload the list
    ref.invalidate(historyProvider);
  }

  void _deleteFile(String path) {
    try {
      final file = File(path);
      if (file.existsSync()) {
        file.deleteSync();
      }
    } catch (e) {
      print("Lỗi xóa file: $e");
    }
  }
}

final historyControllerProvider = NotifierProvider<HistoryController, void>(
  HistoryController.new,
);
