import 'package:flutter/foundation.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/password_store.dart';

class AppSession extends ChangeNotifier {
  final ApiClient api;
  final AuthService auth;

  String? token;
  bool isLoading = false;
  bool needsPassword = false;
  String? error;

  AppSession({required this.api, required this.auth});

  Future<void> init() async {
    print("SESSION INIT: start");

    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final password = await PasswordStore.read();
      final trimmed = password.trim();

      if (trimmed.isEmpty) {
        needsPassword = true;
        return;
      }

      final t = await auth.loginAdmin(password: trimmed);

      print("SESSION INIT: token received = ${t.substring(0, 10)}...");

      token = t;
      api.setToken(t);
      needsPassword = false;
    } catch (e) {
      error = e.toString();
      needsPassword = true;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setPasswordAndLogin(String newPassword) async {
    await PasswordStore.write(newPassword);
    await init();
  }

  Future<void> resetPassword() async {
    await PasswordStore.clear();

    token = null;
    api.setToken(null);
    needsPassword = true;
    error = null;
    isLoading = false;

    notifyListeners();
  }

  void logout() {
    token = null;
    api.setToken(null);
    notifyListeners();
  }
}
