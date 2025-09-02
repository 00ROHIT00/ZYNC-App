import 'package:shared_preferences/shared_preferences.dart';
import 'package:wifi_iot/wifi_iot.dart';
import 'package:network_info_plus/network_info_plus.dart';

class ConnectionService {
  static final ConnectionService _instance = ConnectionService._internal();
  factory ConnectionService() => _instance;
  ConnectionService._internal();

  Future<void> handleAppExit() async {
    final prefs = await SharedPreferences.getInstance();
  final shouldDisconnect = false; // Always keep connection unless user manually disconnects
    final connectedDeviceSSID = prefs.getString('connected_device_ssid');

    if (shouldDisconnect && connectedDeviceSSID != null) {
      try {
        // Get current network info
        final info = NetworkInfo();
        final currentSSID = await info.getWifiName();

        // Only disconnect if we're connected to the ZYNC device
        if (currentSSID?.replaceAll('"', '') == connectedDeviceSSID) {
          await WiFiForIoTPlugin.disconnect();
          // Clear the connected device from preferences
          await prefs.remove('connected_device_ssid');
        }
      } catch (e) {
        print('Error during auto-disconnect: $e');
      }
    }
  }
}
