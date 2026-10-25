# Kế Hoạch Rà Soát, Dọn Dẹp Mã Nguồn & Tối Ưu Hóa Toàn Diện (`backend-nutricare` & `nckh_app`) - [ĐÃ THỰC THI HOÀN TẤT 100%]

Tài liệu này lưu trữ toàn bộ báo cáo phân tích chuyên sâu (Bước 1) và kết quả thực thi (Bước 2) cho cả 2 kho lưu trữ:
1. **Phần 1: Backend NestJS & PostgreSQL (`backend-nutricare`)** — ✅ Đã thực thi & kiểm thử `npm run build` (Exit code 0)
2. **Phần 2: Ứng dụng Flutter & Riverpod (`nckh_app`)** — ✅ Đã thực thi & kiểm thử `flutter analyze lib` (`No issues found!`)

---

## PHẦN 1: KẾ HOẠCH DỌN DẸP & TỐI ƯU BACKEND (`backend-nutricare`)

### 1. Vùng cấm & Logic bảo toàn
- **Không đụng chạm:** `node_modules/`, `dist/`, `.env`, `package-lock.json`.
- **Bảo toàn 100%:** Cấu trúc DTO tinh gọn mới (`src/modules/nutrition/dto/suggest-nutrition.dto.ts`) và logic Prompt 4 vế nguyên liệu thô trong `src/modules/nutrition/nutrition.service.ts`.

### 2. Chi tiết các hạng mục chuẩn bị thực hiện (Backend)

#### (a) Các tệp tin, hàm và biến dư thừa dự kiến xóa / làm sạch
- **Tệp tin cần xóa:** **0 tệp** (Toàn bộ 16 file trong `src/` đều đúng chuẩn kiến trúc Module của NestJS).
- **Endpoint thừa trong [`src/modules/auth/auth.controller.ts`](file:///d:/code/nghien%20cuu%20khoa%20hoc/nckh_app/backend-nutricare/src/modules/auth/auth.controller.ts#L15-L21):**
  - Endpoint `@UseGuards(JwtAuthGuard) @Get('me') getProfile(@Request() req)` không được gọi ở bất kỳ đâu trong ứng dụng Flutter (`ApiService` chỉ gọi `POST /auth/google`, `POST /sync/backup`, `GET /sync/restore`, `POST /nutrition/suggest`). Dự kiến xóa `@Get('me')` cùng các import thừa (`Get`, `UseGuards`, `Request`, `JwtAuthGuard`).
- **`exports` dư thừa trong các Module con:**
  - [`src/modules/auth/auth.module.ts`](file:///d:/code/nghien%20cuu%20khoa%20hoc/nckh_app/backend-nutricare/src/modules/auth/auth.module.ts#L27): Xóa `exports: [AuthService, JwtModule]` vì không có module nào khác inject `AuthService` hay `JwtModule`.
  - [`src/modules/sync/sync.module.ts`](file:///d:/code/nghien%20cuu%20khoa%20hoc/nckh_app/backend-nutricare/src/modules/sync/sync.module.ts#L9): Xóa `exports: [SyncService]`.
  - [`src/modules/nutrition/nutrition.module.ts`](file:///d:/code/nghien%20cuu%20khoa%20hoc/nckh_app/backend-nutricare/src/modules/nutrition/nutrition.module.ts#L9): Xóa `exports: [NutritionService]`.
- **Chuẩn hóa Logger & TypeScript typing:**
  - [`src/main.ts`](file:///d:/code/nghien%20cuu%20khoa%20hoc/nckh_app/backend-nutricare/src/main.ts#L24-L25): Thay `console.log(...)` bằng `Logger` chuẩn của `@nestjs/common`.
  - [`src/database/database.service.ts`](file:///d:/code/nghien%20cuu%20khoa%20hoc/nckh_app/backend-nutricare/src/database/database.service.ts#L102), [`src/modules/auth/auth.service.ts`](file:///d:/code/nghien%20cuu%20khoa%20hoc/nckh_app/backend-nutricare/src/modules/auth/auth.service.ts#L67), [`src/modules/sync/sync.service.ts`](file:///d:/code/nghien%20cuu%20khoa%20hoc/nckh_app/backend-nutricare/src/modules/sync/sync.service.ts#L145): Định kiểu rõ `catch (error: any)` để tránh cảnh báo `unknown` của TypeScript.

#### (b) Các điểm lệch giữa DTO / Service và `schema.sql` sẽ được đồng bộ
- **Đồng bộ Auto-Migration trong [`src/database/database.service.ts`](file:///d:/code/nghien%20cuu%20khoa%20hoc/nckh_app/backend-nutricare/src/database/database.service.ts#L29-L68):**
  - Bổ sung lệnh `ALTER TABLE scan_history ADD COLUMN IF NOT EXISTS` cho 3 cột ảnh Base64 (`original_image_base64`, `food_image_base64`, `label_image_base64`) trong `onModuleInit()` để đồng bộ 100% với [`schema.sql`](file:///d:/code/nghien%20cuu%20khoa%20hoc/nckh_app/backend-nutricare/schema.sql#L51-L65).
- **Bổ sung Decorator Validation trong [`src/modules/sync/dto/sync-backup.dto.ts`](file:///d:/code/nghien%20cuu%20khoa%20hoc/nckh_app/backend-nutricare/src/modules/sync/dto/sync-backup.dto.ts#L45-L46):**
  - Thêm `@IsBoolean()` (cùng `@IsOptional()`) cho trường `isObesityMode?: boolean` trong `ProfileSyncDto` để khớp với cột `is_obesity_mode BOOLEAN DEFAULT FALSE` trong `schema.sql`.
  - Giữ nguyên đúng 4 cột ngưỡng trần trong `user_profiles`: `ceiling_sugar`, `ceiling_sodium`, `ceiling_sat_fat`, `ceiling_protein_kidney`.

#### (c) Các câu lệnh SQL và logic trùng lặp sẽ được tối ưu hóa
- **[`src/modules/sync/sync.service.ts`](file:///d:/code/nghien%20cuu%20khoa%20hoc/nckh_app/backend-nutricare/src/modules/sync/sync.service.ts#L31-L97):**
  - Gộp bước chuẩn hóa mảng tham số của `user_profiles` (`medicalConditionsJson`, `allergiesJson`, `isObesityMode`, các chỉ số cơ thể và 4 cột trần) dùng chung cho cả nhánh `UPDATE` và `INSERT` bên trong Transaction `BEGIN ... COMMIT`, giảm ~25 dòng code lặp.
- **[`src/modules/auth/auth.service.ts`](file:///d:/code/nghien%20cuu%20khoa%20hoc/nckh_app/backend-nutricare/src/modules/auth/auth.service.ts#L13-L28):**
  - Lưu `googleClientId` thành thuộc tính `private readonly googleClientId: string` trong `constructor` thay vì gọi `this.configService.get<string>('GOOGLE_CLIENT_ID')` lặp lại ở cả `constructor` và `loginWithGoogle`.
- **[`src/database/database.service.ts`](file:///d:/code/nghien%20cuu%20khoa%20hoc/nckh_app/backend-nutricare/src/database/database.service.ts#L98):**
  - Chuẩn hóa log truy vấn `text.replace(/\s+/g, ' ').trim()` để log SQL gọn trên 1 dòng.

---

## PHẦN 2: KẾ HOẠCH DỌN DẸP & TỐI ƯU FLUTTER (`nckh_app`)

### 1. Vùng cấm & Logic nghiệp vụ bảo toàn
- **Không đụng chạm:** `backend-nutricare/`, `build/`, `.dart_tool/`, `.gradle/`, `android/.gradle/`, `android/app/build/`, `.pub-cache/`, `.flutter-plugins-dependencies`, `pubspec.yaml`, `pubspec.lock`, `*.g.dart`, `*.freezed.dart`, `assets/models/`, `assets/csv/`.
- **Bảo toàn 100%:**
  1. **Cơ chế lưu ảnh 2 tầng ở Local (`sqflite`) và Model (`ScanHistory`):** Giữ nguyên song song cả đường dẫn vật lý (`originalImage`, `croppedFoodImage`, `croppedLabelImage`) VÀ chuỗi mã hóa Base64 (`originalImageBase64`, `foodImageBase64`, `labelImageBase64`).
  2. **Giao diện `ProfileScreen`:** Giữ nguyên thiết kế không tô chữ đỏ các dòng ngưỡng trần, chỉ **in đậm** khi bị ảnh hưởng bởi bệnh lý và ghi rõ nguyên nhân bệnh lý bên dưới (bao gồm cả Kali và Photpho).
  3. **Logic AI & Hard-Veto (`NutritionSuggestionUseCase`):** Chỉ giữ Hard-Veto (dị ứng 100% & nguy cơ cấp tính) ở Client; giữ nguyên payload JSON tinh gọn (`{ user: ..., food: ... }`) gửi lên Backend.

### 2. Chi tiết các hạng mục chuẩn bị thực hiện (Flutter `nckh_app`)

#### (a) Các file / widget / hàm / comment dư thừa dự kiến xóa
1. **File mồ côi cần xóa (1 file):**
   - [`lib/domain/entities/nutrition_result.dart`](file:///d:/code/nghien%20cuu%20khoa%20hoc/nckh_app/lib/domain/entities/nutrition_result.dart): File rỗng hoàn toàn (chỉ có 2 bytes ký tự xuống dòng), không được import ở bất kỳ đâu trong dự án. *(Lưu ý: `ResultScreen` tại `lib/presentation/screens/result_screen.dart` vẫn đang được sử dụng bởi nút `"Xem chi tiết giá trị dinh dưỡng >"` trong `FoundObjectScreen`, nên giữ lại và làm sạch bên trong).*
2. **Hàm không bao giờ được gọi (Dead Methods):**
   - [`FoodRepository.getAllFoods()`](file:///d:/code/nghien%20cuu%20khoa%20hoc/nckh_app/lib/data/repositories/food_repository.dart#L139-L144) trong `lib/data/repositories/food_repository.dart`: Hàm cũ dùng để lọc món phụ offline, hiện không còn nơi nào gọi.
   - [`DatabaseHelper.close()`](file:///d:/code/nghien%20cuu%20khoa%20hoc/nckh_app/lib/data/datasources/local/database_helper.dart#L202-L205) trong `lib/data/datasources/local/database_helper.dart`: Không được gọi ở bất kỳ đâu.
3. **Code bị comment cũ, biến thừa & `debugPrint` / `print` dư thừa:**
   - [`lib/presentation/screens/result_screen.dart`](file:///d:/code/nghien%20cuu%20khoa%20hoc/nckh_app/lib/presentation/screens/result_screen.dart#L1-L59): Xóa dòng comment cũ `// import 'dart:io';`, comment cũ `// KHAI BÁO BIẾN THỜI GIAN Ở ĐÂY (Hết báo lỗi đỏ nhé)`, và khoảng trống thừa `// ĐÃ XÓA ẢNH THEO YÊU CẦU` + `SizedBox(height: 16)` trùng lặp.
   - [`lib/presentation/screens/found_object_screen.dart`](file:///d:/code/nghien%20cuu%20khoa%20hoc/nckh_app/lib/presentation/screens/found_object_screen.dart#L78): Biến trạng thái `_suggestionError` và nhánh hiển thị lỗi (dòng 963–986) thực tế không bao giờ kích hoạt vì `NutritionSuggestionUseCase.generateSuggestion` đã bắt mọi ngoại lệ và trả về chuỗi `offlineMessage`. Tuy nhiên có thể giữ gọn hoặc đồng bộ cùng luồng trạng thái. Ngoài ra tham số `{bool isAutoPrompt = false}` trong `_showEggSelectionModal({bool isAutoPrompt = false})` (dòng 232) không được sử dụng trong thân hàm -> xóa tham số thừa `isAutoPrompt`.
   - [`lib/data/datasources/local/ai_helper.dart`](file:///d:/code/nghien%20cuu%20khoa%20hoc/nckh_app/lib/data/datasources/local/ai_helper.dart#L19-L26) và [`lib/data/repositories/food_repository.dart`](file:///d:/code/nghien%20cuu%20khoa%20hoc/nckh_app/lib/data/repositories/food_repository.dart#L29-L36): Thay thế các lệnh `print(...)` thô bằng `debugPrint(...)` (hoặc lược bỏ log spam trong vòng lặp frame/OCR) để tuân thủ chuẩn `flutter_lints` (`avoid_print`) và tránh nghẽn luồng UI.

#### (b) Các thuộc tính trong Model / SQLite bị thừa hoặc lệch chuẩn
1. **Kiểm tra đối chiếu `UserProfile` (`lib/data/models/user_profile_model.dart`) & bảng `user_profile` (`database_helper.dart`):**
   - Bảng `user_profile` trong SQLite và `UserProfile` model đã **đồng bộ chuẩn xác 100%**:
     - Chỉ số cơ thể & mục tiêu: `id`, `dob`, `weight`, `height`, `gender`, `activity_factor`, `goal`, `is_obesity_mode`.
     - Chỉ số năng lượng & ngân sách: `bmr`, `tdee`, `target_calories`, `budget_carb`, `budget_protein`, `budget_fat`, `budget_fiber`.
     - Bệnh lý & dị ứng: `medical_conditions` (JSON), `medical_flags` (chuỗi 6-bit cho 6 bệnh: Tiểu đường, Huyết áp cao, Mỡ máu, Gout, Bệnh Thận, Tim mạch), `allergies` (JSON).
     - Đúng 4 cột ngưỡng trần lưu DB: `ceiling_sugar`, `ceiling_sodium`, `ceiling_sat_fat`, `ceiling_protein_kidney` (Kali & Photpho được suy diễn trực tiếp từ cờ Bệnh Thận trên UI).
     - Đồng bộ đám mây: `is_synced`, `updated_at`.
2. **Kiểm tra đối chiếu `ScanHistory` (`lib/data/models/scan_history_model.dart`) & bảng `scan_history` (`database_helper.dart`):**
   - Giữ nguyên tuyệt đối cơ chế lưu ảnh 2 tầng:
     - Tầng 1 (Local Path): `originalImage`, `croppedFoodImage`, `croppedLabelImage`.
     - Tầng 2 (Cloud Base64): `originalImageBase64`, `foodImageBase64`, `labelImageBase64`.
   - **Điểm lệch cần khắc phục khi cập nhật món ăn (`FoundObjectScreen`):**
     - Trong [`FoundObjectScreen._applyEggSelection`](file:///d:/code/nghien%20cuu%20khoa%20hoc/nckh_app/lib/presentation/screens/found_object_screen.dart#L204-L216) và [`FoundObjectScreen._editWeight`](file:///d:/code/nghien%20cuu%20khoa%20hoc/nckh_app/lib/presentation/screens/found_object_screen.dart#L526-L536), khi khởi tạo lại đối tượng `ScanHistory` để lưu khối lượng mới xuống SQLite, code hiện tại **quên truyền lại 3 trường Base64** (`originalImageBase64`, `foodImageBase64`, `labelImageBase64`), khiến 3 trường này bị ghi đè thành `null` trong bộ nhớ (`_currentData`) và trong SQLite sau khi người dùng sửa khối lượng hoặc chọn loại trứng!
     - **Giải pháp:** Bổ sung hàm `copyWith(...)` vào `ScanHistory` (`scan_history_model.dart`) để bảo toàn toàn bộ thuộc tính (bao gồm cả 3 trường ảnh vật lý và 3 trường ảnh Base64) khi cập nhật khối lượng hoặc loại trứng.

#### (c) Các đoạn logic / UI trùng lặp sẽ được gộp lại & Chuẩn hóa Riverpod
1. **Gộp công thức tính tuổi (`dob` -> `age`) đang bị lặp ở 2 nơi:**
   - Hiện tại logic parse chuỗi `YYYY-MM-DD` và tính số tuổi theo ngày/tháng/năm sinh đang bị viết lặp tại:
     - [`UserProfile.create()`](file:///d:/code/nghien%20cuu%20khoa%20hoc/nckh_app/lib/data/models/user_profile_model.dart#L109-L118)
     - [`ProfileController._calculateAndSetState()`](file:///d:/code/nghien%20cuu%20khoa%20hoc/nckh_app/lib/presentation/state/profile_controller.dart#L72-L80)
   - **Giải pháp:** Tách thành hàm tĩnh `static int calculateAge(String dob)` (và getter `int get age`) ngay trong `UserProfile`, sau đó tái sử dụng ở cả `UserProfile.create()` và `ProfileController`.
2. **Gộp logic tính BMI & phân loại BMI đang bị lặp giữa `EditProfileScreen` và `ProfileScreen`:**
   - Bổ sung getter `double get bmi` vào `UserProfile` (`weight / ((height / 100) * (height / 100))`) để dùng chung.
3. **Gộp logic đóng gói / giải nén JSON Cloud của `UserProfile` trong `SyncController`:**
   - Trong [`SyncController.syncNow()`](file:///d:/code/nghien%20cuu%20khoa%20hoc/nckh_app/lib/presentation/state/sync_controller.dart#L216-L238), code đang viết tay một Map 22 trường camelCase để gửi lên Backend.
   - Trong [`SyncController.restoreFromCloud()`](file:///d:/code/nghien%20cuu%20khoa%20hoc/nckh_app/lib/presentation/state/sync_controller.dart#L331-L363), code lại viết tay 30 dòng giải nén dữ liệu từ Cloud thành `UserProfile` kèm hàm `_parseNum` trùng lặp với `parseDouble` trong `UserProfile.fromMap`.
   - **Giải pháp:** Đưa hàm `toCloudMap()` vào `UserProfile` và tái sử dụng trực tiếp `UserProfile.fromMap(p)` (với `isSynced: 1`) trong `SyncController`, giúp rút gọn ~55 dòng code trùng lặp trong `sync_controller.dart`.
4. **Gộp hàm định dạng hiển thị khối lượng (`g` / `kg`) bị lặp ở 3 màn hình:**
   - Biểu thức `weight >= 1000 ? '${(weight / 1000).toStringAsFixed(2).replaceAll(RegExp(r'0*$'), '').replaceAll(RegExp(r'\.$'), '')} kg' : '${weight.toStringAsFixed(2)...} g'` đang bị copy-paste ở 4 vị trí thuộc 3 file:
     - [`lib/presentation/screens/history_screen.dart`](file:///d:/code/nghien%20cuu%20khoa%20hoc/nckh_app/lib/presentation/screens/history_screen.dart#L117-L119)
     - [`lib/presentation/screens/found_object_screen.dart`](file:///d:/code/nghien%20cuu%20khoa%20hoc/nckh_app/lib/presentation/screens/found_object_screen.dart#L745-L748)
     - [`lib/presentation/screens/result_screen.dart`](file:///d:/code/nghien%20cuu%20khoa%20hoc/nckh_app/lib/presentation/screens/result_screen.dart#L81-L83) (và dòng 135–137)
   - **Giải pháp:** Thêm hàm tiện ích `String formatWeight({String fallback = '100 g'})` (hoặc `static String formatWeightValue(double weight, {bool spaceBeforeUnit = true})`) ngay trong `ScanHistory` (`scan_history_model.dart`) để cả 3 màn hình gọi thống nhất.
5. **Tách biệt trách nhiệm UI - State (Riverpod Clean Architecture):**
   - Trong [`FoundObjectScreen`](file:///d:/code/nghien%20cuu%20khoa%20hoc/nckh_app/lib/presentation/screens/found_object_screen.dart#L219) (dòng 219 & 538), tầng UI đang import và gọi trực tiếp `DatabaseHelper.instance.updateScan(updatedData)` rồi mới gọi `ref.invalidate(historyProvider)`.
   - **Giải pháp:** Bổ sung hàm `Future<void> updateScanItem(ScanHistory item)` vào `HistoryController` (`history_controller.dart`) để xử lý cập nhật SQLite và làm mới state ngay trong tầng Controller, đồng thời xóa import `database_helper.dart` khỏi `found_object_screen.dart`.
