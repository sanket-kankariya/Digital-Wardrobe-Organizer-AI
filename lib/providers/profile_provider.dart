import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileState {
  final String name;
  final String? avatarPath;

  const ProfileState({this.name = 'My Style', this.avatarPath});

  ProfileState copyWith({String? name, String? avatarPath}) {
    return ProfileState(
      name: name ?? this.name,
      avatarPath: avatarPath ?? this.avatarPath,
    );
  }
}

final profileProvider = StateNotifierProvider<ProfileNotifier, ProfileState>((ref) {
  return ProfileNotifier();
});

class ProfileNotifier extends StateNotifier<ProfileState> {
  ProfileNotifier() : super(const ProfileState()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = ProfileState(
      name: prefs.getString('profile_name') ?? 'My Style',
      avatarPath: prefs.getString('profile_avatar'),
    );
  }

  Future<void> updateName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_name', name);
    state = state.copyWith(name: name);
  }

  Future<void> updateAvatar(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_avatar', path);
    state = state.copyWith(avatarPath: path);
  }
}
