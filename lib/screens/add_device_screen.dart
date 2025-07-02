import 'package:flutter/material.dart';
import 'device_scanning_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AddDeviceScreen extends StatefulWidget {
  const AddDeviceScreen({super.key});

  @override
  State<AddDeviceScreen> createState() => _AddDeviceScreenState();
}

class _AddDeviceScreenState extends State<AddDeviceScreen> {
  String? _connectedDeviceSSID;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkConnectedDevice();
  }

  Future<void> _checkConnectedDevice() async {
    final prefs = await SharedPreferences.getInstance();
    final connectedSSID = prefs.getString('connected_device_ssid');
    if (mounted) {
      setState(() {
        _connectedDeviceSSID = connectedSSID;
        _isLoading = false;
      });
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
                      'ESP32 Device Connected',
                      style: TextStyle(
                        fontFamily: 'Barlow',
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 32),
                    FilledButton.icon(
                      onPressed: () async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.remove('connected_device_ssid');
                        if (mounted) {
                          setState(() {
                            _connectedDeviceSSID = null;
                          });
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
                        'Connect your ESP32 device to start syncing your data',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(fontFamily: 'Barlow', color: Colors.grey),
                      ),
                    ),
                    const SizedBox(height: 48),
                    FilledButton.icon(
                      onPressed: () async {
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
}
