import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const _keyAutoStart = 'auto_start_gateway';
  static const _keySetupComplete = 'setup_complete';
  static const _keyFirstRun = 'first_run';
  static const _keyDashboardUrl = 'dashboard_url';
  static const _keyNodeEnabled = 'node_enabled';
  static const _keyNodeDeviceToken = 'node_device_token';
  static const _keyNodeGatewayHost = 'node_gateway_host';
  static const _keyNodeGatewayPort = 'node_gateway_port';
  static const _keyNodePublicKey = 'node_ed25519_public';
  static const _keyNodeGatewayToken = 'node_gateway_token';

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  bool get autoStartGateway => _prefs.getBool(_keyAutoStart) ?? false;
  set autoStartGateway(bool value) => _prefs.setBool(_keyAutoStart, value);

  bool get setupComplete => _prefs.getBool(_keySetupComplete) ?? false;
  set setupComplete(bool value) => _prefs.setBool(_keySetupComplete, value);

  bool get isFirstRun => _prefs.getBool(_keyFirstRun) ?? true;
  set isFirstRun(bool value) => _prefs.setBool(_keyFirstRun, value);

  String? get dashboardUrl => _prefs.getString(_keyDashboardUrl);
  set dashboardUrl(String? value) {
    if (value != null) {
      _prefs.setString(_keyDashboardUrl, value);
    } else {
      _prefs.remove(_keyDashboardUrl);
    }
  }

  bool get nodeEnabled => _prefs.getBool(_keyNodeEnabled) ?? false;
  set nodeEnabled(bool value) => _prefs.setBool(_keyNodeEnabled, value);

  String? get nodeDeviceToken => _prefs.getString(_keyNodeDeviceToken);
  set nodeDeviceToken(String? value) {
    if (value != null) {
      _prefs.setString(_keyNodeDeviceToken, value);
    } else {
      _prefs.remove(_keyNodeDeviceToken);
    }
  }

  String? get nodeGatewayHost => _prefs.getString(_keyNodeGatewayHost);
  set nodeGatewayHost(String? value) {
    if (value != null) {
      _prefs.setString(_keyNodeGatewayHost, value);
    } else {
      _prefs.remove(_keyNodeGatewayHost);
    }
  }

  String? get nodePublicKey => _prefs.getString(_keyNodePublicKey);

  String? get nodeGatewayToken => _prefs.getString(_keyNodeGatewayToken);
  set nodeGatewayToken(String? value) {
    if (value != null && value.isNotEmpty) {
      _prefs.setString(_keyNodeGatewayToken, value);
    } else {
      _prefs.remove(_keyNodeGatewayToken);
    }
  }

  int? get nodeGatewayPort {
    final val = _prefs.getInt(_keyNodeGatewayPort);
    return val;
  }
  set nodeGatewayPort(int? value) {
    if (value != null) {
      _prefs.setInt(_keyNodeGatewayPort, value);
    } else {
      _prefs.remove(_keyNodeGatewayPort);
    }
  }
}
