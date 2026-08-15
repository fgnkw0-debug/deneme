import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_profile.dart';

class AuthService extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  UserProfile? profile;
  bool isLoading = false;
  String? errorMessage;

  User? get currentUser => _client.auth.currentUser;
  bool get isLoggedIn => currentUser != null;

  Future<bool> signUp(String email, String password) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      await _client.auth.signUp(email: email, password: password);
      // profiles satırı DB trigger'ı (handle_new_user) tarafından otomatik oluşturulur
      isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      errorMessage = e.message;
      isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signIn(String email, String password) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
      await loadProfile();
      isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      errorMessage = e.message;
      isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
    profile = null;
    notifyListeners();
  }

  Future<void> loadProfile() async {
    final uid = currentUser?.id;
    if (uid == null) return;
    final data = await _client.from('profiles').select().eq('id', uid).single();
    profile = UserProfile.fromJson(data);
    notifyListeners();
  }
}
