import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nckh_app/presentation/screens/main_screen.dart';

// import 'presentation/screens/scan_screen.dart';
import 'presentation/state/scan_controller.dart';

void main() async {
  // Đảm bảo Flutter sẵn sàng trước khi load file
  WidgetsFlutterBinding.ensureInitialized();

  // Khởi tạo Riverpod Container để gọi hàm load CSV chạy ngầm
  final container = ProviderContainer();
  await container.read(foodRepositoryProvider).loadCsvData();

  runApp(
    // Bọc toàn bộ app bằng ProviderScope
    UncontrolledProviderScope(container: container, child: const MyApp()),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quét Dinh Dưỡng',
      theme: ThemeData(primarySwatch: Colors.green, useMaterial3: true),
      debugShowCheckedModeBanner: false,
      home: const MainScreen(),
    );
  }
}
