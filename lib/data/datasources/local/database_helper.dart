import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../../models/scan_history_model.dart';

class DatabaseHelper {
  // Khởi tạo Singleton để đảm bảo app chỉ có 1 kết nối database
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('food_scanner.db');
    return _database!;
  }

  // Hàm khởi tạo và mở Database
  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path, 
      version: 2, // Đổi sang version 2 để DB tự Update
      onCreate: _createDB,
      onUpgrade: (db, oldVersion, newVersion) async {
        // Xóa bảng cũ và tạo lại nếu có phiên bản mới
        await db.execute('DROP TABLE IF EXISTS scan_history');
        await _createDB(db, newVersion);
      }
    );
  }

  // Lệnh SQL tạo bảng Lịch sử
  Future _createDB(Database db, int version) async {
    await db.execute('''
    CREATE TABLE scan_history (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      original_image TEXT NOT NULL,
      cropped_food_image TEXT NOT NULL,
      cropped_label_image TEXT,
      food_name TEXT NOT NULL,
      weight REAL,
      nutrition_data TEXT NOT NULL,
      created_at TEXT NOT NULL
    )
    ''');
  }

  // --- CÁC HÀM THAO TÁC DỮ LIỆU ---

  // 1. Thêm một lượt quét mới vào lịch sử
  Future<int> insertScan(ScanHistory scan) async {
    final db = await instance.database;
    return await db.insert('scan_history', scan.toMap());
  }

  // 2. Lấy toàn bộ lịch sử quét (Sắp xếp thời gian mới nhất lên đầu)
  Future<List<ScanHistory>> getAllScans() async {
    final db = await instance.database;
    final result = await db.query('scan_history', orderBy: 'created_at DESC');

    return result.map((map) => ScanHistory.fromMap(map)).toList();
  }
  // 3. Xóa các lịch sử quét dựa trên danh sách ID
  Future<void> deleteScans(List<int> ids) async {
    final db = await instance.database;
    if (ids.isEmpty) return;
    
    final placeholders = List.filled(ids.length, '?').join(',');
    await db.delete(
      'scan_history',
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );
  }
}
