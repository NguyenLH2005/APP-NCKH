import '../../data/models/user_profile_model.dart';
import '../../data/datasources/remote/api_service.dart';

class NutritionSuggestionUseCase {
  static const String offlineMessage = '📶 Cần kết nối Internet để nhận lời khuyên dinh dưỡng từ chuyên gia AI.';

  static bool _matchesAllergen(String foodNameLower, String allergen) {
    if (allergen.contains('Đậu phộng') || allergen.contains('Lạc')) {
      return foodNameLower.contains('lạc') ||
          foodNameLower.contains('đậu phộng') ||
          foodNameLower.contains('bơ đậu phộng') ||
          foodNameLower.contains('peanut');
    }
    if (allergen.contains('Hải sản có vỏ')) {
      return foodNameLower.contains('tôm') ||
          foodNameLower.contains('cua') ||
          foodNameLower.contains('sò') ||
          foodNameLower.contains('ốc') ||
          foodNameLower.contains('nghêu') ||
          foodNameLower.contains('ngao') ||
          foodNameLower.contains('hàu') ||
          foodNameLower.contains('ghẹ') ||
          foodNameLower.contains('hến') ||
          foodNameLower.contains('tôm khô') ||
          foodNameLower.contains('mắm tôm') ||
          foodNameLower.contains('shrimp') ||
          foodNameLower.contains('crab') ||
          foodNameLower.contains('shellfish');
    }
    if (allergen.contains('Hạt cây')) {
      return foodNameLower.contains('hạnh nhân') ||
          foodNameLower.contains('óc chó') ||
          foodNameLower.contains('hạt điều') ||
          foodNameLower.contains('hạt dẻ') ||
          foodNameLower.contains('macca') ||
          foodNameLower.contains('mắc ca') ||
          foodNameLower.contains('hạt phỉ') ||
          foodNameLower.contains('almond') ||
          foodNameLower.contains('walnut') ||
          foodNameLower.contains('cashew');
    }
    if (allergen.contains('Trứng')) {
      return foodNameLower.contains('trứng') ||
          foodNameLower.contains('egg') ||
          foodNameLower.contains('lòng đỏ') ||
          foodNameLower.contains('lòng trắng');
    }
    if (allergen.contains('Cá')) {
      return foodNameLower.contains('cá ') ||
          foodNameLower.startsWith('cá') ||
          foodNameLower.contains('chả cá') ||
          foodNameLower.contains('cá lóc') ||
          foodNameLower.contains('cá hồi') ||
          foodNameLower.contains('cá ngừ') ||
          foodNameLower.contains('cá thu') ||
          foodNameLower.contains('cá ba sa') ||
          foodNameLower.contains('cá nục') ||
          foodNameLower.contains('cá diêu hồng') ||
          foodNameLower.contains('cá chép') ||
          foodNameLower.contains('fish');
    }
    if (allergen.contains('sữa')) {
      return foodNameLower.contains('sữa bò') ||
          foodNameLower.contains('sữa tươi') ||
          foodNameLower.contains('phô mai') ||
          foodNameLower.contains('pho mát') ||
          foodNameLower.contains('bơ sữa') ||
          foodNameLower.contains('váng sữa') ||
          foodNameLower.contains('sữa chua') ||
          foodNameLower.contains('milk') ||
          foodNameLower.contains('cheese') ||
          foodNameLower.contains('dairy');
    }
    return false;
  }

  static Future<String?> generateSuggestion({
    required UserProfile profile,
    required String mainGroupStr, // VD: "Protein, Chất béo"
    required String foodName,
    required Map<String, dynamic> rawFoodData,
    double? weight,
  }) async {
    final double calo100g = double.tryParse(rawFoodData['Năng lượng']?.toString() ?? '0') ?? 0;
    if (calo100g <= 0) return null;

    final double sugars = double.tryParse(rawFoodData['Sugars, total']?.toString() ?? '0') ?? 0;
    final double sodium = double.tryParse(rawFoodData['Natri']?.toString() ?? '0') ?? 0;
    final double satFat = double.tryParse(rawFoodData['Axit béo bão hòa tổng số']?.toString() ?? '0') ?? 0;
    final double transFat = double.tryParse(rawFoodData['Fatty acids, total trans']?.toString() ?? '0') ?? 0;
    final double protein = double.tryParse(rawFoodData['Chất đạm']?.toString() ?? '0') ?? 0;
    final double carb = double.tryParse(rawFoodData['Chất bột đường']?.toString() ?? '0') ?? 0;
    final double fat = double.tryParse(rawFoodData['Chất béo (Fat)']?.toString() ?? '0') ?? 0;
    final double fiber = double.tryParse(rawFoodData['Chất xơ']?.toString() ?? '0') ?? 0;
    final double potassium = double.tryParse(rawFoodData['Kali']?.toString() ?? '0') ?? 0;
    final double phosphorus = double.tryParse(rawFoodData['Photpho']?.toString() ?? '0') ?? 0;

    final flags = profile.medicalFlags; // Chuỗi 6-bit
    final bool hasDiabetes = flags.isNotEmpty && flags[0] == '1';
    final bool hasHypertension = flags.length > 1 && flags[1] == '1';
    final bool hasLipid = flags.length > 2 && flags[2] == '1';
    final bool hasGout = flags.length > 3 && flags[3] == '1';
    final bool hasKidney = flags.length > 4 && flags[4] == '1';
    final bool hasCardio = flags.length > 5 && flags[5] == '1';

    final String foodNameLower = foodName.toLowerCase();

    // 1. Kiểm tra Lệnh cấm tuyệt đối (Medical Hard Veto & Absolute Allergies)
    String? vetoReason;

    // A. Dị ứng thực phẩm tuyệt đối (0% Tolerance / Veto 100%)
    if (profile.allergies.isNotEmpty) {
      for (final allergen in profile.allergies) {
        if (_matchesAllergen(foodNameLower, allergen)) {
          vetoReason = "Bạn có tiền sử DỊ ỨNG TUYỆT ĐỐI với nhóm \"$allergen\". Thực phẩm \"$foodName\" có chứa thành phần này, có nguy cơ gây sốc phản vệ hoặc biến chứng dị ứng nghiêm trọng đe dọa tính mạng.";
          break;
        }
      }
    }

    // B. Veto bệnh lý mạn tính nghiêm trọng đe dọa cấp cứu
    if (vetoReason == null) {
      if (hasKidney && (potassium >= 600.0 || phosphorus >= 500.0)) {
        vetoReason = "Bạn đang mắc bệnh Thận mạn. Thực phẩm \"$foodName\" có hàm lượng Kali (${potassium.toStringAsFixed(0)}mg/100g) hoặc Photpho (${phosphorus.toStringAsFixed(0)}mg/100g) vượt ngưỡng an toàn nghiêm trọng, vượt quá khả năng bài tiết của thận và có thể dẫn đến tăng Kali máu làm loạn nhịp tim nguy hiểm.";
      } else if (hasDiabetes && sugars >= (profile.ceilingSugar * 0.5)) {
        vetoReason = "Bạn đang mắc bệnh Tiểu đường. Thực phẩm \"$foodName\" có hàm lượng Đường tự do quá cao (${sugars.toStringAsFixed(1)}g/100g, chiếm >= 50% trần an toàn cả ngày), có nguy cơ làm tăng đột ngột đường huyết cấp tính.";
      } else if (hasHypertension && (sodium >= (profile.ceilingSodium * 0.5) || sodium >= 1000.0)) {
        vetoReason = "Bạn đang mắc bệnh Tăng huyết áp. Thực phẩm \"$foodName\" có lượng Natri quá cao (${sodium.toStringAsFixed(0)}mg/100g, chiếm >= 50% trần muối an toàn cả ngày), dễ dẫn đến tăng huyết áp đột ngột.";
      } else if (hasCardio && (sodium >= (profile.ceilingSodium * 0.5) || sodium >= 1000.0)) {
        vetoReason = "Bạn đang mắc bệnh Tim mạch. Thực phẩm \"$foodName\" có lượng Natri quá cao (${sodium.toStringAsFixed(0)}mg/100g), có nguy cơ gây giữ nước và tăng gánh nặng tuần hoàn cấp tính cho tim.";
      } else if (hasLipid && (transFat >= 0.5 || satFat >= (profile.ceilingSatFat * 0.5))) {
        vetoReason = "Bạn đang mắc bệnh Rối loạn lipid máu (Mỡ máu). Thực phẩm \"$foodName\" chứa Trans fat (${transFat.toStringAsFixed(1)}g) hoặc Axit béo bão hòa quá cao (${satFat.toStringAsFixed(1)}g/100g), gây tổn thương thành mạch và làm tăng mạnh cholesterol xấu.";
      } else if (hasGout) {
        if ((foodNameLower.contains('bò') || foodNameLower.contains('heo') || foodNameLower.contains('cừu') || 
             foodNameLower.contains('tôm') || foodNameLower.contains('cua') || foodNameLower.contains('mực') || 
             foodNameLower.contains('tuộc') || foodNameLower.contains('hải sản')) && protein >= 20.0) {
          vetoReason = "Bạn đang mắc bệnh Gout. Thực phẩm \"$foodName\" giàu Purine/Đạm động vật đậm đặc (${protein.toStringAsFixed(1)}g/100g), có nguy cơ kích hoạt cơn đau Gout cấp tính dữ dội.";
        }
      }
    }

    if (vetoReason != null) {
      return "🚨 CẢNH BÁO Y KHOA ĐẶC BIỆT:\n$vetoReason\n\n⛔ KHUYẾN NGHỊ: Bạn TUYỆT ĐỐI KHÔNG ĐƯỢC DÙNG thực phẩm này để bảo vệ sức khỏe an toàn.";
    }

    // 2. Tính toán các chỉ số cho JSON gửi AI Gemini
    final double userWeight = (weight != null && weight > 0) ? weight : 100.0;

    // A. % Calo
    double caloPercentRaw = (profile.targetCalories > 0) ? (calo100g / profile.targetCalories) * 100 : 0.0;
    if (caloPercentRaw.isNaN || caloPercentRaw.isInfinite) caloPercentRaw = 0.0;
    final double caloriesPercent = double.parse(caloPercentRaw.toStringAsFixed(1));

    // B. Chuẩn hóa nhóm dinh dưỡng chính và tính % nhóm chất
    List<String> rawGroups = mainGroupStr
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (rawGroups.isEmpty) rawGroups = ['Chất đạm'];

    final List<Map<String, dynamic>> mainGroupsPercent = [];
    for (String g in rawGroups) {
      final gLower = g.toLowerCase();
      if (gLower.contains('protein') || gLower.contains('đạm')) {
        final double p = (profile.budgetProtein > 0) ? (protein / profile.budgetProtein) * 100 : 0.0;
        mainGroupsPercent.add({'group': 'Chất đạm', 'percent': double.parse(p.toStringAsFixed(1))});
      } else if (gLower.contains('tinh bột') || gLower.contains('carb')) {
        final double p = (profile.budgetCarb > 0) ? (carb / profile.budgetCarb) * 100 : 0.0;
        mainGroupsPercent.add({'group': 'Tinh bột', 'percent': double.parse(p.toStringAsFixed(1))});
      } else if (gLower.contains('chất béo') || gLower.contains('fat')) {
        final double p = (profile.budgetFat > 0) ? (fat / profile.budgetFat) * 100 : 0.0;
        mainGroupsPercent.add({'group': 'Chất béo', 'percent': double.parse(p.toStringAsFixed(1))});
      } else if (gLower.contains('chất xơ') || gLower.contains('fiber')) {
        final double p = (profile.budgetFiber > 0) ? (fiber / profile.budgetFiber) * 100 : 0.0;
        mainGroupsPercent.add({'group': 'Chất xơ', 'percent': double.parse(p.toStringAsFixed(1))});
      }
      // Lưu ý: Nếu là "Vitamin và khoáng chất" thì không thêm vào mainGroupsPercent theo quy ước
    }

    // C. Tính diseaseImpact (CHỈ GỬI CÁC BỆNH CÓ CHỈ SỐ LIÊN QUAN > 0)
    final List<Map<String, dynamic>> diseaseImpact = [];
    if (hasDiabetes && sugars > 0 && profile.ceilingSugar > 0) {
      final double pct = (sugars / profile.ceilingSugar) * 100;
      diseaseImpact.add({
        'disease': 'Tiểu đường',
        'nutrient': 'Đường tự do',
        'percentCeiling': double.parse(pct.toStringAsFixed(1)),
      });
    }
    if (hasHypertension && sodium > 0 && profile.ceilingSodium > 0) {
      final double pct = (sodium / profile.ceilingSodium) * 100;
      diseaseImpact.add({
        'disease': 'Huyết áp cao',
        'nutrient': 'Natri',
        'percentCeiling': double.parse(pct.toStringAsFixed(1)),
      });
    }
    if (hasCardio && sodium > 0 && profile.ceilingSodium > 0 && !hasHypertension) {
      final double pct = (sodium / profile.ceilingSodium) * 100;
      diseaseImpact.add({
        'disease': 'Tim mạch',
        'nutrient': 'Natri',
        'percentCeiling': double.parse(pct.toStringAsFixed(1)),
      });
    }
    if (hasLipid && satFat > 0 && profile.ceilingSatFat > 0) {
      final double pct = (satFat / profile.ceilingSatFat) * 100;
      diseaseImpact.add({
        'disease': 'Mỡ máu',
        'nutrient': 'Chất béo bão hòa',
        'percentCeiling': double.parse(pct.toStringAsFixed(1)),
      });
    }
    if (hasKidney) {
      if (potassium > 0) {
        final double pct = (potassium / 2000.0) * 100;
        diseaseImpact.add({
          'disease': 'Bệnh Thận',
          'nutrient': 'Kali',
          'percentCeiling': double.parse(pct.toStringAsFixed(1)),
        });
      }
      if (phosphorus > 0) {
        final double pct = (phosphorus / 800.0) * 100;
        diseaseImpact.add({
          'disease': 'Bệnh Thận',
          'nutrient': 'Photpho',
          'percentCeiling': double.parse(pct.toStringAsFixed(1)),
        });
      }
      if (protein > 0 && profile.ceilingProteinKidney > 0) {
        final double pct = (protein / profile.ceilingProteinKidney) * 100;
        diseaseImpact.add({
          'disease': 'Bệnh Thận',
          'nutrient': 'Chất đạm',
          'percentCeiling': double.parse(pct.toStringAsFixed(1)),
        });
      }
    }
    if (hasGout && protein > 0) {
      if (foodNameLower.contains('bò') || foodNameLower.contains('heo') || foodNameLower.contains('cừu') || 
          foodNameLower.contains('tôm') || foodNameLower.contains('cua') || foodNameLower.contains('mực') || 
          foodNameLower.contains('tuộc') || foodNameLower.contains('hải sản')) {
        final double pct = (profile.budgetProtein > 0) ? (protein / profile.budgetProtein) * 100 : 0.0;
        diseaseImpact.add({
          'disease': 'Gout',
          'nutrient': 'Purine / Đạm động vật',
          'percentCeiling': double.parse(pct.toStringAsFixed(1)),
        });
      }
    }
    if (profile.isObesityMode && sugars > 0 && profile.ceilingSugar > 0 && !hasDiabetes) {
      final double pct = (sugars / profile.ceilingSugar) * 100;
      diseaseImpact.add({
        'disease': 'Kiểm soát béo phì',
        'nutrient': 'Đường tự do',
        'percentCeiling': double.parse(pct.toStringAsFixed(1)),
      });
    }

    // D. Tìm các nhóm nguyên liệu còn thiếu từ 5 nhóm nguyên liệu cơ bản
    const fundamentalGroups = ['Chất đạm', 'Tinh bột', 'Chất béo', 'Chất xơ', 'Vitamin và khoáng chất'];
    final List<String> missingGroups = [];
    for (String fg in fundamentalGroups) {
      final fgLower = fg.toLowerCase();
      final bool hasGroup = rawGroups.any((g) {
        final gLower = g.toLowerCase();
        if (gLower.contains(fgLower)) return true;
        if (fg == 'Chất đạm' && gLower.contains('protein')) return true;
        if (fg == 'Tinh bột' && gLower.contains('carb')) return true;
        if (fg == 'Chất béo' && gLower.contains('fat')) return true;
        if (fg == 'Chất xơ' && gLower.contains('fiber')) return true;
        if (fg == 'Vitamin và khoáng chất' && (gLower.contains('vitamin') || gLower.contains('khoáng'))) return true;
        return false;
      });
      if (!hasGroup) {
        missingGroups.add(fg);
      }
    }

    // E. Đóng gói JSON Payload chuẩn
    final Map<String, dynamic> payload = {
      'user': {
        'medicalConditions': profile.medicalConditions,
        'allergies': profile.allergies,
      },
      'food': {
        'name': foodName,
        'holdingWeight_g': userWeight,
        'mainGroups': rawGroups,
        'missingGroups': missingGroups,
        'metrics100g': {
          'caloriesPercent': caloriesPercent,
          'mainGroupsPercent': mainGroupsPercent,
          'diseaseImpact': diseaseImpact,
        },
      },
    };

    // 3. Gửi lên Máy chủ Backend gọi Google Gemini AI
    final aiSuggestion = await ApiService.instance.getNutritionSuggestion(
      payload: payload,
    );

    if (aiSuggestion == null) {
      return offlineMessage;
    }

    return aiSuggestion;
  }
}
