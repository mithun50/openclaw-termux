import 'package:flutter/foundation.dart';
import '../models/setup_state.dart';
import '../services/bootstrap_service.dart';

class SetupProvider extends ChangeNotifier {
  final BootstrapService _bootstrapService = BootstrapService();
  SetupState _state = const SetupState();
  bool _isRunning = false;

  SetupState get state => _state;
  bool get isRunning => _isRunning;

  Future<bool> checkIfSetupNeeded() async {
    _state = await _bootstrapService.checkStatus();
    notifyListeners();
    return !_state.isComplete;
  }

  Future<void> runSetup() async {
    if (_isRunning) return;
    _isRunning = true;
    notifyListeners();

    await _bootstrapService.runFullSetup(
      onProgress: (state) {
        _state = state;
        notifyListeners();
      },
    );

    _isRunning = false;
    notifyListeners();
  }

  void reset() {
    _state = const SetupState();
    _isRunning = false;
    notifyListeners();
  }
}
