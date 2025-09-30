import 'package:flutter/material.dart';
import 'device_scanning_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wifi_iot/wifi_iot.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:app_settings/app_settings.dart';
import 'dart:io';

class AddDeviceScreen extends StatefulWidget {
  const AddDeviceScreen({super.key});

  @override
  State<AddDeviceScreen> createState() => _AddDeviceScreenState();
}

class _AddDeviceScreenState extends State<AddDeviceScreen> {
  String? _connectedDeviceSSID;
  bool _isLoading = true;
  int _batteryPercentage = 0;
  bool _isCharging = false;
  bool _fetchingBattery = false;

  @override
  void initState() {
    super.initState();
    _checkConnectedDevice();
  }

  Future<void> _fetchBatteryStatus() async {
    if (_connectedDeviceSSID == null) return;
    
    setState(() {
      _fetchingBattery = true;
    });

    try {
      // Connect to ESP32 TCP server to get battery status
      final socket = await Socket.connect('192.168.4.1', 8888, timeout: const Duration(seconds: 5));
      
      // Send battery status request
      socket.write('GET_BATTERY\n');
      await socket.flush();
      
      // Wait for response
      final response = await socket.timeout(const Duration(seconds: 3)).first;
      final data = String.fromCharCodes(response).trim();
      
      // Parse response: "BATTERY:85:0" (percentage:charging)
      if (data.startsWith('BATTERY:')) {
        final parts = data.substring(8).split(':');
        if (parts.length >= 2) {
          setState(() {
            _batteryPercentage = int.tryParse(parts[0]) ?? 0;
            _isCharging = parts[1] == '1';
          });
        }
      }
      
      socket.close();
    } catch (e) {
      // If battery fetch fails, show default values
      setState(() {
        _batteryPercentage = 0;
        _isCharging = false;
      });
    } finally {
      setState(() {
        _fetchingBattery = false;
      });
    }
  }

  Future<void> _checkConnectedDevice() async {
    final prefs = await SharedPreferences.getInstance();
    final connectedSSID = prefs.getString('connected_device_ssid');
    
    // Verify if actually connected to the WiFi network
    if (connectedSSID != null) {
      try {
        final info = NetworkInfo();
        final currentSSID = await info.getWifiName();
        final cleanSSID = currentSSID?.replaceAll('"', '');
        
        // If not actually connected to the saved device, clear the state
        if (cleanSSID != connectedSSID) {
          await prefs.remove('connected_device_ssid');
          if (mounted) {
            setState(() {
              _connectedDeviceSSID = null;
              _isLoading = false;
            });
          }
          return;
        }
      } catch (e) {
        // If error checking connection, clear the state
        await prefs.remove('connected_device_ssid');
        if (mounted) {
          setState(() {
            _connectedDeviceSSID = null;
            _isLoading = false;
          });
        }
        return;
      }
    }
    
    if (mounted) {
      setState(() {
        _connectedDeviceSSID = connectedSSID;
        _isLoading = false;
      });
      
      // Fetch battery status if connected
      if (connectedSSID != null) {
        _fetchBatteryStatus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _connectedDeviceSSID != null ? 'Connected Device' : 'Add Device',
          style: const TextStyle(
              fontFamily: 'Barlow', fontWeight: FontWeight.w600),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_connectedDeviceSSID != null) ...[
                    // Connected device UI
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(60),
                      ),
                      child: Icon(
                        Icons.memory,
                        size: 60,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      _connectedDeviceSSID!,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontFamily: 'Barlow',
                                fontWeight: FontWeight.w600,
                              ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'ZYNC Device Connected',
                      style: TextStyle(
                        fontFamily: 'Barlow',
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Battery Status (compact)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Battery Icon (smaller)
                          _buildBatteryIcon(_batteryPercentage, _isCharging),
                          const SizedBox(width: 8),
                          // Battery Percentage
                          Text(
                            _fetchingBattery ? 'Checking...' : '$_batteryPercentage%',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontFamily: 'Barlow',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (_isCharging) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.bolt,
                              size: 14,
                              color: Colors.amber,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () async {
                        // Attempt to disconnect from ESP32 WiFi network
                        try {
                          await WiFiForIoTPlugin.disconnect();
                        } catch (_) {}

                        final prefs = await SharedPreferences.getInstance();
                        await prefs.remove('connected_device_ssid');
                        if (mounted) {
                          setState(() {
                            _connectedDeviceSSID = null;
                          });
                        }
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Disconnected from ZYNC Device'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.link_off),
                      label: const Text(
                        'Disconnect Device',
                        style: TextStyle(
                          fontFamily: 'Barlow',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ] else ...[
                    // Add new device UI
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(60),
                      ),
                      child: Icon(
                        Icons.memory,
                        size: 60,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Add a New Device',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontFamily: 'Barlow',
                                fontWeight: FontWeight.w600,
                              ),
                    ),
                    const SizedBox(height: 16),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        'Connect your ZYNC device to start syncing your data',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(fontFamily: 'Barlow', color: Colors.grey),
                      ),
                    ),
                    const SizedBox(height: 48),
                    FilledButton.icon(
                      onPressed: () async {
                        // Check if WiFi is enabled before scanning
                        bool wifiEnabled = false;
                        try {
                          wifiEnabled = await WiFiForIoTPlugin.isEnabled();
                        } catch (e) {
                          wifiEnabled = false;
                        }
                        
                        if (!wifiEnabled) {
                          // Show dialog to enable WiFi
                          if (mounted) {
                            final shouldEnable = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('WiFi is Off'),
                                content: const Text(
                                  'WiFi needs to be enabled to scan for ZYNC devices. Please enable WiFi in your device settings.',
                                  style: TextStyle(fontFamily: 'Barlow'),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: const Text('Open Settings'),
                                  ),
                                ],
                              ),
                            );
                            
                            if (shouldEnable == true) {
                              // Open WiFi settings
                              await AppSettings.openAppSettings(type: AppSettingsType.wifi);
                              
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please enable WiFi and return to the app to scan.'),
                                    duration: Duration(seconds: 3),
                                  ),
                                );
                              }
                              return;
                            } else {
                              return;
                            }
                          }
                        }
                        
                        if (mounted) {
                          final result = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const DeviceScanningScreen(),
                            ),
                          );
                          if (result == true) {
                            // Refresh the connected device status
                            _checkConnectedDevice();
                          }
                        }
                      },
                      icon: const Icon(Icons.search),
                      label: const Text(
                        'Start Scanning',
                        style: TextStyle(
                          fontFamily: 'Barlow',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildBatteryIcon(int percentage, bool charging) {
    IconData icon;
    Color color;

    if (charging) {
      icon = Icons.battery_charging_full;
      color = Colors.green;
    } else if (percentage > 80) {
      icon = Icons.battery_full;
      color = Colors.green;
    } else if (percentage > 50) {
      icon = Icons.battery_5_bar;
      color = Colors.lightGreen;
    } else if (percentage > 30) {
      icon = Icons.battery_3_bar;
      color = Colors.orange;
    } else if (percentage > 10) {
      icon = Icons.battery_2_bar;
      color = Colors.deepOrange;
    } else {
      icon = Icons.battery_1_bar;
      color = Colors.red;
    }

    return Icon(
      icon,
      size: 20,  // Smaller icon
      color: color,
    );
  }
}
