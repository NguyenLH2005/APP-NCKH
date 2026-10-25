import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'https://nutricare-backend-spmq.onrender.com/api';
  static final ApiService instance = ApiService._internal();

  ApiService._internal();

  // Kiểm tra thiết bị có kết nối mạng không
  Future<bool> isNetworkConnected() async {
    try {
      final List<ConnectivityResult> results = await Connectivity().checkConnectivity();
      if (results.contains(ConnectivityResult.mobile) || 
          results.contains(ConnectivityResult.wifi) || 
          results.contains(ConnectivityResult.ethernet)) {
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // Quản lý Token JWT
  Future<void> saveAuthToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_access_token', token);
  }

  Future<String?> getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_access_token');
  }

  Future<void> clearAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_access_token');
  }

  // 1. Gọi Google Gemini sinh gợi ý dinh dưỡng
  Future<String?> getNutritionSuggestion({
    required Map<String, dynamic> payload,
  }) async {
    final isOnline = await isNetworkConnected();
    if (!isOnline) {
      return null; // Không có mạng
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/nutrition/suggest'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 35));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['success'] == true && data['data'] != null) {
          return data['data']['suggestion']?.toString();
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // 2. Xác thực đăng nhập Google
  Future<Map<String, dynamic>?> loginWithGoogle(String idToken) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/google'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({'idToken': idToken}),
      ).timeout(const Duration(seconds: 35));

      final resBody = utf8.decode(response.bodyBytes);
      debugPrint('loginWithGoogle response [${response.statusCode}]: $resBody');

      if (response.statusCode == 200) {
        final data = jsonDecode(resBody);
        if (data['success'] == true && data['data'] != null) {
          final accessToken = data['data']['accessToken']?.toString();
          if (accessToken != null) {
            await saveAuthToken(accessToken);
          }
          return data['data']['user'];
        }
      }
      return null;
    } catch (e) {
      debugPrint('Lỗi loginWithGoogle: $e');
      return null;
    }
  }

  // 3. Đồng bộ sao lưu (Backup) lên Cloud
  Future<Map<String, dynamic>> backupData({
    Map<String, dynamic>? profile,
    List<Map<String, dynamic>>? scans,
  }) async {
    final token = await getAuthToken();
    if (token == null) {
      return {'success': false, 'message': 'Chưa đăng nhập (thiếu Access Token).'};
    }

    try {
      final Map<String, dynamic> payload = {};
      if (profile != null) payload['profile'] = profile;
      if (scans != null) payload['scans'] = scans;

      debugPrint('Bắt đầu gửi backupData... (scans: ${scans?.length ?? 0})');

      final response = await http.post(
        Uri.parse('$baseUrl/sync/backup'),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 45));

      final resBody = utf8.decode(response.bodyBytes);
      debugPrint('backupData response [${response.statusCode}]: $resBody');

      if (response.statusCode == 200) {
        final data = jsonDecode(resBody);
        return {
          'success': data['success'] == true,
          'message': data['message'] ?? 'Đồng bộ đám mây thành công!',
        };
      } else if (response.statusCode == 413) {
        return {
          'success': false,
          'message': 'Lỗi 413: Dữ liệu ảnh quá lớn vượt quá giới hạn nhận của máy chủ.',
        };
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'message': 'Lỗi 401: Phiên đăng nhập hết hạn. Vui lòng đăng xuất và đăng nhập lại.',
        };
      } else {
        return {
          'success': false,
          'message': 'Lỗi máy chủ (${response.statusCode}): $resBody',
        };
      }
    } catch (e) {
      debugPrint('Lỗi ngoại lệ backupData: $e');
      return {
        'success': false,
        'message': 'Lỗi kết nối sao lưu: $e',
      };
    }
  }

  // 4. Phục hồi dữ liệu từ Cloud (Restore)
  Future<Map<String, dynamic>?> restoreData() async {
    final token = await getAuthToken();
    if (token == null) return null;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/sync/restore'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 35));

      final resBody = utf8.decode(response.bodyBytes);
      debugPrint('restoreData response [${response.statusCode}]');

      if (response.statusCode == 200) {
        final data = jsonDecode(resBody);
        if (data['success'] == true && data['data'] != null) {
          return data['data'];
        }
      }
      return null;
    } catch (e) {
      debugPrint('Lỗi ngoại lệ restoreData: $e');
      return null;
    }
  }
}
