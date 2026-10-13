import '../../data/models/user_profile_model.dart';

class NutritionSuggestionUseCase {
  // Bộ thực phẩm tươi sống tiêu biểu, thân thiện và giàu dinh dưỡng theo từng nhóm
  static const Map<String, List<String>> _curatedPairings = {
    'Protein': [
      'Đậu phụ hấp', 'Ức gà ta luộc', 'Trứng gà luộc', 'Cá quả (cá lóc) hấp', 
      'Cá hồi áp chảo', 'Thịt lợn nạc luộc', 'Sữa chua không đường'
    ],
    'Tinh bột': [
      'Cơm gạo lứt', 'Khoai lang luộc', 'Bắp ngô tươi luộc', 'Khoai tây hấp', 
      'Yến mạch nguyên cám', 'Cơm trắng'
    ],
    'Chất béo': [
      'Quả bơ tươi', 'Hạt óc chó rang mộc', 'Hạt hạnh nhân', 'Dầu ô liu nguyên chất'
    ],
    'Chất xơ': [
      'Rau muống luộc', 'Súp lơ xanh hấp', 'Bắp cải luộc', 'Rau cải xanh', 
      'Đậu cô ve luộc', 'Mướp đắng (khổ qua)'
    ],
    'Vitamin và chất khoáng': [
      'Táo tây tươi', 'Ổi chín tươi', 'Cam tươi', 'Thanh long', 
      'Dâu tây tươi', 'Đu đủ chín', 'Dưa hấu tươi'
    ],
  };

  static String? generateSuggestion({
    required UserProfile profile,
    required String mainGroupStr, // VD: "Protein, Chất béo"
    required String foodName,
    required Map<String, dynamic> rawFoodData,
  }) {
    double calo100g = double.tryParse(rawFoodData['Năng lượng']?.toString() ?? '0') ?? 0;
    if (calo100g <= 0) return null;

    double sugars = double.tryParse(rawFoodData['Sugars, total']?.toString() ?? '0') ?? 0;
    double sodium = double.tryParse(rawFoodData['Natri']?.toString() ?? '0') ?? 0;
    double satFat = double.tryParse(rawFoodData['Axit béo bão hòa tổng số']?.toString() ?? '0') ?? 0;
    double transFat = double.tryParse(rawFoodData['Fatty acids, total trans']?.toString() ?? '0') ?? 0;
    double protein = double.tryParse(rawFoodData['Chất đạm']?.toString() ?? '0') ?? 0;
    double carb = double.tryParse(rawFoodData['Chất bột đường']?.toString() ?? '0') ?? 0;
    double fat = double.tryParse(rawFoodData['Chất béo (Fat)']?.toString() ?? '0') ?? 0;
    double fiber = double.tryParse(rawFoodData['Chất xơ']?.toString() ?? '0') ?? 0;
    double potassium = double.tryParse(rawFoodData['Kali']?.toString() ?? '0') ?? 0;
    double phosphorus = double.tryParse(rawFoodData['Photpho']?.toString() ?? '0') ?? 0;

    final flags = profile.medicalFlags; // Chuỗi 5-bit: Bit 0: Tiểu đường, 1: Huyết áp, 2: Mỡ máu, 3: Gout, 4: Thận
    final bool hasDiabetes = flags.isNotEmpty && flags[0] == '1';
    final bool hasHypertension = flags.length > 1 && flags[1] == '1';
    final bool hasLipidHeart = flags.length > 2 && flags[2] == '1';
    final bool hasGout = flags.length > 3 && flags[3] == '1';
    final bool hasKidney = flags.length > 4 && flags[4] == '1';

    // =========================================================================
    // 1. PHÂN ĐOẠN 2 - BƯỚC 1: LỆNH CẤM TUYỆT ĐỐI (MEDICAL VETO - VƯỢT 50% %DV)
    // =========================================================================
    String? vetoReason;

    if (hasDiabetes && sugars >= (profile.ceilingSugar * 0.5)) {
      vetoReason = "Món này có hàm lượng Đường quá cao (${sugars}g/100g, chiếm >= 50% trần an toàn cả ngày), có nguy cơ làm tăng đột ngột đường huyết cấp tính.";
    } else if (hasHypertension && (sodium >= (profile.ceilingSodium * 0.5) || sodium >= 1000.0)) {
      vetoReason = "Món này có hàm lượng Natri quá cao (${sodium}mg/100g, chiếm >= 50% trần an toàn cả ngày), dễ dẫn đến tăng huyết áp đột ngột.";
    } else if (hasLipidHeart && (transFat >= 0.5 || satFat >= (profile.ceilingSatFat * 0.5))) {
      vetoReason = "Món này chứa Trans fat (${transFat}g) hoặc Axit béo bão hòa quá cao (${satFat}g/100g), gây tổn thương nghiêm trọng đến thành mạch và tim mạch.";
    } else if (hasKidney && (potassium >= 600.0 || phosphorus >= 500.0)) {
      vetoReason = "Hàm lượng Kali (${potassium}mg) hoặc Photpho (${phosphorus}mg) trong 100g vượt quá khả năng đào thải của thận bị suy.";
    } else if (hasGout) {
      String nameLower = foodName.toLowerCase();
      if ((nameLower.contains('bò') || nameLower.contains('heo') || nameLower.contains('cừu') || 
           nameLower.contains('tôm') || nameLower.contains('cua') || nameLower.contains('mực') || 
           nameLower.contains('tuộc') || nameLower.contains('hải sản')) && protein >= 20.0) {
        vetoReason = "Món này giàu Purine/Đạm động vật đậm đặc (${protein}g/100g), có nguy cơ kích hoạt cơn đau Gout cấp tính dữ dội.";
      }
    }

    if (vetoReason != null) {
      return "🚨 CẢNH BÁO Y KHOA ĐẶC BIỆT:\n$vetoReason\n\n⛔ KHUYẾN NGHỊ: Bạn TUYỆT ĐỐI KHÔNG NÊN ĂN món này để bảo vệ sức khỏe an toàn.";
    }

    // =========================================================================
    // 2. PHÂN ĐOẠN 2 - BƯỚC 2: CẢNH BÁO VÀNG (25% <= %DV < 50%)
    // =========================================================================
    List<String> warnings = [];

    if (hasDiabetes && sugars >= (profile.ceilingSugar * 0.25)) {
      warnings.add("⚠️ TIỂU ĐƯỜNG: Món này có lượng đường đáng kể (${sugars}g/100g, chiếm >= 25% ngân sách ngày). Cần kiểm soát chặt chẽ khẩu phần.");
    }
    if (hasHypertension && sodium >= (profile.ceilingSodium * 0.25)) {
      warnings.add("⚠️ HUYẾT ÁP CAO: Hàm lượng Natri khá cao (${sodium}mg/100g). Cần lưu ý khi nêm nếm gia vị các món khác trong bữa ăn.");
    }
    if (hasLipidHeart && satFat >= (profile.ceilingSatFat * 0.25)) {
      warnings.add("⚠️ MỠ MÁU / TIM MẠCH: Lượng Axit béo bão hòa chiếm >= 25% ngân sách ngày (${satFat}g/100g).");
    }
    if (hasKidney && (potassium >= 300.0 || phosphorus >= 200.0)) {
      warnings.add("⚠️ BỆNH THẬN: Hàm lượng Kali (${potassium}mg) hoặc Photpho (${phosphorus}mg) ở mức cần lưu ý đối với người suy thận.");
    }
    if (hasGout) {
      String nameLower = foodName.toLowerCase();
      if (nameLower.contains('bò') || nameLower.contains('heo') || nameLower.contains('cừu') || 
          nameLower.contains('tôm') || nameLower.contains('cua') || nameLower.contains('mực') || 
          nameLower.contains('tuộc') || nameLower.contains('hải sản')) {
        warnings.add("⚠️ GOUT: Thuộc nhóm Thịt đỏ / Hải sản có chứa Purine. Nên ăn lượng vừa phải để phòng ngừa tái phát viêm khớp.");
      }
    }

    // =========================================================================
    // 3. PHÂN ĐOẠN 3: TÍNH TOÁN ĐỊNH LƯỢNG KHỐI LƯỢNG KHUYÊN DÙNG (MEAL-BASED)
    // =========================================================================
    List<String> groups = mainGroupStr.split(',').map((e) => e.trim()).toList();
    if (groups.isEmpty || groups[0].isEmpty) groups = ['Chưa phân loại'];

    int roundToTens(double val) {
      if (val <= 0) return 10;
      if (val < 10) return val.round();
      return (val / 10).round() * 10;
    }

    String portionAdvice = "";

    bool isPureFiber = groups.contains('Chất xơ') && !groups.contains('Protein') && !groups.contains('Tinh bột') && !groups.contains('Chất béo');
    bool isPureVitamin = groups.contains('Vitamin và chất khoáng') && !groups.contains('Protein') && !groups.contains('Tinh bột') && !groups.contains('Chất béo');

    if (isPureFiber) {
      // Nhóm Chất xơ: Đưa ra lời khuyên theo TỔNG LƯỢNG CẢ NGÀY (Quỹ xơ 25g - 30g)
      double safeFiberPer100 = fiber > 0 ? fiber : 3.0;
      int fiberMin = roundToTens((25.0 / safeFiberPer100) * 100);
      int fiberMax = roundToTens((30.0 / safeFiberPer100) * 100);
      if (fiberMin >= fiberMax) fiberMin = fiberMax > 10 ? fiberMax - 10 : fiberMax;

      portionAdvice = "• Khẩu phần khuyến nghị cả ngày (đáp ứng 25g - 30g chất xơ tiêu chuẩn): Khoảng ${fiberMin}g - ${fiberMax}g (chia đều cho các bữa ăn)";
    } else if (isPureVitamin) {
      // Nhóm Vitamin & Khoáng chất: Đưa ra lời khuyên theo BỮA PHỤ (Snack: 10% - 15% calo ngày)
      double snackCalMin = profile.targetCalories * 0.10;
      double snackCalMax = profile.targetCalories * 0.15;
      int snackMin = roundToTens((snackCalMin / calo100g) * 100);
      int snackMax = roundToTens((snackCalMax / calo100g) * 100);

      // Áp dụng trần tĩnh an toàn cho trái cây tươi (không quá 250g/bữa phụ)
      if (snackMax > 250) snackMax = 250;
      if (snackMin >= snackMax) snackMin = snackMax > 20 ? snackMax - 20 : snackMax;

      portionAdvice = "• Khẩu phần Bữa ăn phụ (Snack lành mạnh - 10% đến 15% năng lượng ngày): Khoảng ${snackMin}g - ${snackMax}g";
    } else {
      // Nhóm Đạm, Tinh bột, Béo: Đưa ra 2 mốc BỮA CHÍNH (35% - 40%) và BỮA SÁNG (20% - 25%)
      double mainMinG = 99999;
      double mainMaxG = 99999;
      double bfMinG = 99999;
      double bfMaxG = 99999;

      for (String g in groups) {
        double curMainMin = 99999;
        double curMainMax = 99999;
        double curBfMin = 99999;
        double curBfMax = 99999;

        if (g == 'Protein' && protein > 0) {
          curMainMin = ((profile.budgetProtein * 0.35) / protein) * 100;
          curMainMax = ((profile.budgetProtein * 0.40) / protein) * 100;
          curBfMin = ((profile.budgetProtein * 0.20) / protein) * 100;
          curBfMax = ((profile.budgetProtein * 0.25) / protein) * 100;
        } else if (g == 'Tinh bột' && carb > 0) {
          curMainMin = ((profile.budgetCarb * 0.35) / carb) * 100;
          curMainMax = ((profile.budgetCarb * 0.40) / carb) * 100;
          curBfMin = ((profile.budgetCarb * 0.20) / carb) * 100;
          curBfMax = ((profile.budgetCarb * 0.25) / carb) * 100;
        } else if (g == 'Chất béo' && fat > 0) {
          curMainMin = ((profile.budgetFat * 0.35) / fat) * 100;
          curMainMax = ((profile.budgetFat * 0.40) / fat) * 100;
          curBfMin = ((profile.budgetFat * 0.20) / fat) * 100;
          curBfMax = ((profile.budgetFat * 0.25) / fat) * 100;
        } else {
          // Fallback theo calo
          curMainMin = ((profile.targetCalories * 0.35) / calo100g) * 100;
          curMainMax = ((profile.targetCalories * 0.40) / calo100g) * 100;
          curBfMin = ((profile.targetCalories * 0.20) / calo100g) * 100;
          curBfMax = ((profile.targetCalories * 0.25) / calo100g) * 100;
        }

        // Lấy giá trị MIN đối với món nhóm kép
        if (curMainMin < mainMinG) mainMinG = curMainMin;
        if (curMainMax < mainMaxG) mainMaxG = curMainMax;
        if (curBfMin < bfMinG) bfMinG = curBfMin;
        if (curBfMax < bfMaxG) bfMaxG = curBfMax;
      }

      int mainMin = roundToTens(mainMinG);
      int mainMax = roundToTens(mainMaxG);
      int bfMin = roundToTens(bfMinG);
      int bfMax = roundToTens(bfMaxG);

      if (mainMin >= mainMax) mainMin = mainMax > 10 ? mainMax - 10 : mainMax;
      if (bfMin >= bfMax) bfMin = bfMax > 10 ? bfMax - 10 : bfMax;

      portionAdvice = "• Khẩu phần Bữa chính (35% - 40% nhu cầu ngày): Khoảng ${mainMin}g - ${mainMax}g\n• Khẩu phần Bữa sáng (20% - 25% nhu cầu ngày): Khoảng ${bfMin}g - ${bfMax}g";
    }

    // =========================================================================
    // 4. PHÂN ĐOẠN 4: THUẬT TOÁN GỢI Ý MÓN ĂN KÈM NÉ BỆNH (DYNAMIC SAFE PAIRINGS)
    // =========================================================================
    const fundamentalGroups = ['Protein', 'Tinh bột', 'Chất béo', 'Chất xơ', 'Vitamin và chất khoáng'];
    
    // Tìm các nhóm còn thiếu
    List<String> missingGroups = [];
    for (String fg in fundamentalGroups) {
      bool hasGroup = groups.any((g) => g.toLowerCase().contains(fg.toLowerCase()));
      if (!hasGroup) {
        missingGroups.add(fg);
      }
    }

    // Sàng lọc món an toàn đại diện cho từng nhóm còn thiếu
    List<String> suggestedPairings = [];
    for (String mg in missingGroups) {
      final candidates = _curatedPairings[mg] ?? [];
      String? safeFood;

      for (String c in candidates) {
        String cLower = c.toLowerCase();
        
        // Không trùng món đang quét
        if (cLower.contains(foodName.toLowerCase())) continue;

        // Bệnh Gout: không chọn thịt đỏ, heo, bò, hải sản, tôm, mực, cá hồi
        if (hasGout) {
          if (cLower.contains('bò') || cLower.contains('heo') || cLower.contains('cừu') || 
              cLower.contains('tôm') || cLower.contains('cua') || cLower.contains('mực') || 
              cLower.contains('tuộc') || cLower.contains('hải sản') || cLower.contains('cá hồi')) {
            continue;
          }
        }

        // Tiểu đường: không chọn dưa hấu, cơm trắng, đu đủ ngọt
        if (hasDiabetes) {
          if (cLower.contains('dưa hấu') || cLower.contains('cơm trắng') || cLower.contains('đu đủ')) {
            continue;
          }
        }

        // Mỡ máu / Tim mạch: không chọn thịt đỏ mỡ, trứng
        if (hasLipidHeart) {
          if (cLower.contains('thịt bò') || cLower.contains('thịt lợn') || cLower.contains('trứng gà')) {
            continue;
          }
        }

        // Bệnh Thận: không chọn hoa quả giàu kali (chuối, bơ, cam)
        if (hasKidney) {
          if (cLower.contains('chuối') || cLower.contains('bơ') || cLower.contains('cam')) {
            continue;
          }
        }

        safeFood = c;
        break; // Lấy món đầu tiên an toàn nhất
      }

      if (safeFood != null) {
        suggestedPairings.add("$safeFood ($mg)");
      }
    }

    String pairingText = suggestedPairings.isNotEmpty 
        ? suggestedPairings.join(', ')
        : 'Rau xanh luộc, Cơm gạo lứt';

    // =========================================================================
    // 5. LẮP RÁP CÂU CHỮ HOÀN CHỈNH
    // =========================================================================
    String groupText = groups.join(' và ');
    String intro = "Đây là loại thực phẩm cung cấp chủ yếu $groupText.";
    String mainText = "$intro\n\n$portionAdvice\n\n🥗 Món ăn kèm đề xuất để bữa ăn cân đối dưỡng chất:\nBạn nên kết hợp thêm: $pairingText.";

    // Đưa cảnh báo vàng lên đầu nếu có
    if (warnings.isNotEmpty) {
      return "${warnings.join('\n\n')}\n\n---\n\n$mainText";
    }

    return mainText;
  }
}
