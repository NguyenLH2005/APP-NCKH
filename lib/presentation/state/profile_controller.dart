import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/local/database_helper.dart';
import '../../data/models/user_profile_model.dart';

class ProfileState {
  final UserProfile? profile;
  final int? age;
  final double? tdee;
  final bool isLoading;

  ProfileState({this.profile, this.age, this.tdee, this.isLoading = true});

  ProfileState copyWith({UserProfile? profile, int? age, double? tdee, bool? isLoading}) {
    return ProfileState(
      profile: profile ?? this.profile,
      age: age ?? this.age,
      tdee: tdee ?? this.tdee,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class ProfileController extends Notifier<ProfileState> {
  @override
  ProfileState build() {
    loadProfile();
    return ProfileState();
  }

  Future<void> loadProfile() async {
    final profile = await DatabaseHelper.instance.getUserProfile();
    if (profile != null) {
      _calculateAndSetState(profile);
    } else {
      state = ProfileState(isLoading: false);
    }
  }

    Future<void> saveProfile(UserProfile profile) async {
    state = state.copyWith(isLoading: true);
    try {
      await DatabaseHelper.instance.saveUserProfile(profile);
      _calculateAndSetState(profile);
    } catch (e) {
      debugPrint("Error saving profile: $e");
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> toggleObesityMode(bool isObesityMode) async {
    if (state.profile == null) return;
    final current = state.profile!;
    final updated = UserProfile.create(
      id: current.id,
      dob: current.dob,
      weight: current.weight,
      height: current.height,
      gender: current.gender,
      activityFactor: current.activityFactor,
      goal: isObesityMode ? 'Giảm cân' : current.goal,
      medicalConditions: current.medicalConditions,
      allergies: current.allergies,
      isObesityMode: isObesityMode,
      isSynced: 0,
    );
    await saveProfile(updated);
  }

  void _calculateAndSetState(UserProfile profile) {
    // Tính tuổi động
    final dobParts = profile.dob.split('-');
    if (dobParts.length == 3) {
      final dobDate = DateTime(int.parse(dobParts[0]), int.parse(dobParts[1]), int.parse(dobParts[2]));
      final today = DateTime.now();
      int age = today.year - dobDate.year;
      if (today.month < dobDate.month || (today.month == dobDate.month && today.day < dobDate.day)) {
        age--;
      }

      state = ProfileState(
        profile: profile,
        age: age,
        tdee: profile.tdee,
        isLoading: false,
      );
    } else {
      state = ProfileState(profile: profile, tdee: profile.tdee, isLoading: false);
    }
  }
}

final profileProvider = NotifierProvider<ProfileController, ProfileState>(() {
  return ProfileController();
});

