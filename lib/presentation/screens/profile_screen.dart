import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/user_profile_model.dart';
import '../state/profile_controller.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _dobController;
  late TextEditingController _weightController;
  late TextEditingController _heightController;
  
  String _gender = 'Nam';
  String _goal = 'Giữ dáng';
  List<String> _selectedDiseases = [];
  double _activityFactor = 1.2;
  
  @override
  void initState() {
    super.initState();
    _dobController = TextEditingController();
    _weightController = TextEditingController();
    _heightController = TextEditingController();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profileState = ref.read(profileProvider);
      if (profileState.profile != null) {
        _dobController.text = profileState.profile!.dob;
        _weightController.text = profileState.profile!.weight.toString();
        _heightController.text = profileState.profile!.height.toString();
        setState(() {
          _gender = profileState.profile!.gender;
          _activityFactor = profileState.profile!.activityFactor;
          _goal = profileState.profile!.goal;
          _selectedDiseases = List.from(profileState.profile!.medicalConditions);
        });
      }
    });
  }

  @override
  void dispose() {
    _dobController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    DateTime initial = DateTime.now();
    if (_dobController.text.isNotEmpty) {
      try {
        initial = DateTime.parse(_dobController.text);
      } catch (e) {}
    }
    
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _dobController.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  void _saveProfile() {
    if (_formKey.currentState!.validate()) {
      final profile = UserProfile.create(
        id: ref.read(profileProvider).profile?.id,
        dob: _dobController.text,
        weight: double.parse(_weightController.text),
        height: double.parse(_heightController.text),
        gender: _gender,
        activityFactor: _activityFactor,
        goal: _goal,
        medicalConditions: _selectedDiseases,
      );
      ref.read(profileProvider.notifier).saveProfile(profile);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lưu thông tin thành công!')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileProvider);
    
    return Scaffold(
      appBar: AppBar(title: const Text('Hồ Sơ Cá Nhân', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), backgroundColor: Colors.green),
      body: profileState.isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (profileState.tdee != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.green.shade200)),
                    child: Column(
                      children: [
                        Text('TDEE của bạn: ${profileState.tdee!.toStringAsFixed(0)} kcal/ngày', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
                        const SizedBox(height: 5),
                        Text('Tuổi: ${profileState.age}', style: TextStyle(color: Colors.grey.shade700)),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _dobController,
                  decoration: const InputDecoration(labelText: 'Ngày sinh (YYYY-MM-DD)', border: OutlineInputBorder(), suffixIcon: Icon(Icons.calendar_today)),
                  readOnly: true,
                  onTap: () => _selectDate(context),
                  validator: (val) => val == null || val.isEmpty ? 'Vui lòng chọn ngày sinh' : null,
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _weightController,
                  decoration: const InputDecoration(labelText: 'Cân nặng (kg)', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                  validator: (val) => val == null || val.isEmpty ? 'Vui lòng nhập cân nặng' : null,
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _heightController,
                  decoration: const InputDecoration(labelText: 'Chiều cao (cm)', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                  validator: (val) => val == null || val.isEmpty ? 'Vui lòng nhập chiều cao' : null,
                ),
                const SizedBox(height: 15),
                DropdownButtonFormField<String>(
                  initialValue: _gender,
                  decoration: const InputDecoration(labelText: 'Giới tính', border: OutlineInputBorder()),
                  items: ['Nam', 'Nữ'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                  onChanged: (val) => setState(() => _gender = val!),
                ),
                const SizedBox(height: 15),
                DropdownButtonFormField<double>(
                  initialValue: _activityFactor,
                  decoration: const InputDecoration(labelText: 'Mức độ vận động', border: OutlineInputBorder()),
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 1.2, child: Text('Ít vận động (Chỉ làm việc văn phòng)')),
                    DropdownMenuItem(value: 1.375, child: Text('Vận động nhẹ (Tập thể dục 1-3 ngày/tuần)')),
                    DropdownMenuItem(value: 1.55, child: Text('Vận động vừa (Tập thể dục 3-5 ngày/tuần)')),
                    DropdownMenuItem(value: 1.725, child: Text('Vận động nhiều (Tập thể dục 6-7 ngày/tuần)')),
                    DropdownMenuItem(value: 1.9, child: Text('Vận động rất nhiều (Tập nặng 2 lần/ngày)')),
                  ],
                  onChanged: (val) => setState(() => _activityFactor = val!),
                ),
                
                const SizedBox(height: 15),
                DropdownButtonFormField<String>(
                  value: _goal,
                  decoration: const InputDecoration(labelText: 'Mục tiêu cá nhân', border: OutlineInputBorder()),
                  items: ['Giảm cân', 'Giữ dáng', 'Tăng cân'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                  onChanged: (val) => setState(() => _goal = val!),
                ),
                
                const SizedBox(height: 15),
                const Text('Tiền sử bệnh lý (Nếu có):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Wrap(
                  spacing: 8.0,
                  children: ['Tiểu đường', 'Huyết áp cao', 'Mỡ máu / Tim mạch', 'Gout', 'Bệnh Thận'].map((disease) {
                    return FilterChip(
                      label: Text(disease),
                      selected: _selectedDiseases.contains(disease),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedDiseases.add(disease);
                          } else {
                            _selectedDiseases.remove(disease);
                          }
                        });
                      },
                      selectedColor: Colors.green.shade200,
                      checkmarkColor: Colors.green.shade900,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _saveProfile,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    child: const Text('LƯU HỒ SƠ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
    );
  }
}

