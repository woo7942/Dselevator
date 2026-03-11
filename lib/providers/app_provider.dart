import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../models/check.dart';

class AppProvider extends ChangeNotifier {
  DashboardData? _dashboard;
  bool _isLoading = false;
  String? _error;

  DashboardData? get dashboard => _dashboard;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadDashboard() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _dashboard = await ApiService.getDashboard();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
