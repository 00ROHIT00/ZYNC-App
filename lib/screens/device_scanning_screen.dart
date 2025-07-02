import 'package:flutter/material.dart';
import 'package:wifi_scan/wifi_scan.dart';
import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:wifi_iot/wifi_iot.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceScanningScreen extends StatefulWidget {
  const DeviceScanningScreen({super.key});

  @override
  State<DeviceScanningScreen> createState() => _DeviceScanningScreenState();
}

class _DeviceScanningScreenState extends State<DeviceScanningScreen> {
  bool _isScanning = false;
  bool _isWifiEnabled = false;
  Timer? _scanTimer;
  bool _hasPermissions = false;
  Timer? _wifiCheckTimer;
  List<WiFiAccessPoint> _foundDevices = [];
  final TextEditingController _passwordController = TextEditingController();
  bool _isConnecting = false;
  bool _obscurePassword = true;
  String? _connectedDeviceSSID;
  // Target BSSID in uppercase for consistent comparison
  static const String TARGET_BSSID = 'F4:65:0B:E8:E9:91';
  // Fallback SSID prefix in case BSSID matching fails
  static const String FALLBACK_SSID_PREFIX = 'Dummy';
  DateTime? _lastScanTime;

  @override
  void initState() {
    super.initState();
    _checkConnectedDevice();
    _initWifiScanning();
    // Check WiFi state less frequently to avoid throttling
    _wifiCheckTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkWifiState();
    });
  }

  Future<void> _checkConnectedDevice() async {
    final prefs = await SharedPreferences.getInstance();
    final connectedSSID = prefs.getString('connected_device_ssid');
    if (mounted) {
      setState(() {
        _connectedDeviceSSID = connectedSSID;
      });
    }
  }

  Future<void> _saveConnectedDevice(String ssid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('connected_device_ssid', ssid);
    if (mounted) {
      setState(() {
        _connectedDeviceSSID = ssid;
      });
    }
  }

  String _normalizeBSSID(String bssid) {
    // Remove any colons, dashes, or spaces and convert to uppercase
    return bssid.replaceAll(RegExp('[:-\\s]'), '').toUpperCase();
  }

  bool _isTargetDevice(WiFiAccessPoint ap) {
    // First try BSSID match
    final normalizedBSSID = _normalizeBSSID(ap.bssid);
    final normalizedTarget = _normalizeBSSID(TARGET_BSSID);

    if (normalizedBSSID == normalizedTarget) {
      return true;
    }

    // Fallback to SSID prefix match
    return ap.ssid.toUpperCase().startsWith(FALLBACK_SSID_PREFIX.toUpperCase());
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _scanTimer?.cancel();
    _wifiCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkWifiState() async {
    try {
      // First check if WiFi scanning is supported
      final canScan = await WiFiScan.instance.canStartScan();
      final canGetResults = await WiFiScan.instance.canGetScannedResults();

      debugPrint('Can start scan: $canScan');
      debugPrint('Can get results: $canGetResults');

      bool isEnabled = false;

      if (canScan == CanStartScan.yes &&
          canGetResults == CanGetScannedResults.yes) {
        isEnabled = true;
      } else {
        debugPrint('Cannot scan: $canScan, Cannot get results: $canGetResults');
        // Request permissions if needed
        if (!_hasPermissions) {
          await _requestPermissions();
        }
      }

      if (mounted) {
        setState(() {
          _isWifiEnabled = isEnabled;
          if (!isEnabled) {
            _isScanning = false;
            _scanTimer?.cancel();
          }
        });

        if (!isEnabled) {
          await _showEnableWifiDialog();
        } else if (!_isScanning) {
          await startScan();
        }
      }
    } catch (e) {
      debugPrint('Error checking WiFi state: $e');
      if (mounted) {
        setState(() {
          _isWifiEnabled = false;
          _isScanning = false;
        });
      }
    }
  }

  Future<void> _showLocationServiceDialog() async {
    if (!mounted) return;

    return showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: const Text(
            'Location Services Required',
            style: TextStyle(fontFamily: 'Barlow'),
          ),
          content: const Text(
            'Location services need to be enabled to scan for nearby devices. Would you like to open settings?',
            style: TextStyle(fontFamily: 'Barlow'),
          ),
          actions: <Widget>[
            CupertinoDialogAction(
              child: const Text(
                'Not Now',
                style: TextStyle(fontFamily: 'Barlow'),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              child: const Text(
                'Open Settings',
                style: TextStyle(fontFamily: 'Barlow'),
              ),
              onPressed: () async {
                Navigator.of(context).pop();
                await openAppSettings();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _initWifiScanning() async {
    try {
      // Request required permissions first
      _hasPermissions = await _requestPermissions();
      if (!_hasPermissions) {
        debugPrint('Required permissions not granted');
        return;
      }

      // Initial WiFi check
      await _checkWifiState();
    } catch (e) {
      debugPrint('Error initializing WiFi scan: $e');
    }
  }

  Future<void> _showEnableWifiDialog() async {
    if (!mounted) return;

    // Don't show the dialog if it's already showing
    if (ModalRoute.of(context)?.isCurrent != true) return;

    return showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: const Text(
            'WiFi Required',
            style: TextStyle(fontFamily: 'Barlow'),
          ),
          content: const Text(
            'WiFi needs to be turned on to scan for ZYNC devices. Would you like to open settings to enable WiFi?',
            style: TextStyle(fontFamily: 'Barlow'),
          ),
          actions: <Widget>[
            CupertinoDialogAction(
              child: const Text(
                'Not Now',
                style: TextStyle(fontFamily: 'Barlow'),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              child: const Text(
                'Open Settings',
                style: TextStyle(fontFamily: 'Barlow'),
              ),
              onPressed: () async {
                Navigator.of(context).pop();
                await _turnOnWifi();
              },
            ),
          ],
        );
      },
    );
  }

  Future<bool> _requestPermissions() async {
    if (Platform.isAndroid) {
      if (await _getAndroidSdkInt() >= 33) {
        // Android 13 and above needs NEARBY_WIFI_DEVICES
        final status = await Permission.nearbyWifiDevices.request();
        return status.isGranted;
      } else {
        // Below Android 13 needs location permission
        final status = await Permission.locationWhenInUse.request();
        return status.isGranted;
      }
    }
    // On iOS, we don't need special permissions for WiFi scanning
    return true;
  }

  Future<void> startScan() async {
    try {
      if (!_hasPermissions || !_isWifiEnabled) {
        debugPrint('Cannot start scan: permissions not granted or WiFi is off');
        return;
      }

      setState(() => _isScanning = true);

      // Start periodic scanning
      _scanTimer?.cancel();
      _scanTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
        await _performScan();
      });

      // Start initial scan
      await _performScan();
    } catch (e) {
      debugPrint('Error starting scan: $e');
      setState(() => _isScanning = false);
    }
  }

  Future<void> _performScan() async {
    try {
      // Check if enough time has passed since last scan (Android throttles scans)
      final now = DateTime.now();
      if (_lastScanTime != null) {
        final difference = now.difference(_lastScanTime!);
        if (difference.inSeconds < 4) {
          // Android typically requires 4 seconds between scans
          debugPrint(
            'Skipping scan due to throttling (${difference.inSeconds}s since last scan)',
          );
          return;
        }
      }

      // Try to get results from the last scan first
      var results = await WiFiScan.instance.getScannedResults();
      debugPrint('Got ${results.length} networks from previous scan');

      // Only start a new scan if we didn't get any results
      if (results.isEmpty) {
        final result = await WiFiScan.instance.startScan();
        debugPrint('Started new WiFi scan, result: $result');

        if (result == CanStartScan.yes) {
          _lastScanTime = now;
          // Wait a bit for the scan to complete
          await Future.delayed(const Duration(seconds: 2));
          results = await WiFiScan.instance.getScannedResults();
        } else {
          debugPrint('Failed to start WiFi scan: $result');
        }
      }

      // Debug print all networks
      debugPrint('==== Found ${results.length} networks ====');
      for (var network in results) {
        debugPrint('SSID: ${network.ssid}');
        debugPrint('BSSID: ${network.bssid}');
        debugPrint('Signal: ${network.level} dBm');
        debugPrint('Frequency: ${network.frequency} MHz');
        debugPrint('------------------------');
      }

      // Filter for our specific device with improved matching
      final targetDevices = results.where(_isTargetDevice).toList();

      debugPrint('Found ${targetDevices.length} matching devices');
      for (var device in targetDevices) {
        debugPrint(
          'Matched device - SSID: ${device.ssid}, BSSID: ${device.bssid}',
        );
      }

      if (mounted) {
        setState(() {
          _foundDevices = targetDevices;
        });
      }
    } catch (e) {
      debugPrint('Error during WiFi scan: $e');
      if (mounted) {
        setState(() => _isScanning = false);
      }
    }
  }

  Future<int> _getAndroidSdkInt() async {
    if (Platform.isAndroid) {
      final nearbyDevicesStatus = await Permission.nearbyWifiDevices.status;
      // This is a simplified way to check. In a production app, you'd want to use
      // package_info_plus or platform channels to get the actual SDK version
      return nearbyDevicesStatus.isGranted ? 33 : 32;
    }
    return 33; // Default to latest for non-Android platforms
  }

  Future<void> _turnOnWifi() async {
    // On modern Android and iOS, we can't directly turn on WiFi
    // Instead, we'll guide the user to system settings
    await openAppSettings();
  }

  Future<void> _showPasswordDialog(WiFiAccessPoint device) async {
    _passwordController.clear();
    _obscurePassword = true;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                'Connect to ${device.ssid}',
                style: const TextStyle(
                  fontFamily: 'Barlow',
                  fontWeight: FontWeight.w600,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Enter the device password to connect:',
                    style: TextStyle(fontFamily: 'Barlow'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: const OutlineInputBorder(),
                      labelStyle: const TextStyle(fontFamily: 'Barlow'),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setDialogState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    obscureText: _obscurePassword,
                    style: const TextStyle(fontFamily: 'Barlow'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontFamily: 'Barlow'),
                  ),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop(true);
                  },
                  child: const Text(
                    'Connect',
                    style: TextStyle(
                      fontFamily: 'Barlow',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      await _connectToDevice(device, _passwordController.text);
    }
  }

  Future<void> _connectToDevice(WiFiAccessPoint device, String password) async {
    if (!mounted) return;

    setState(() => _isConnecting = true);

    try {
      // Store current network info to restore later if needed
      final info = NetworkInfo();
      final currentSSID = await info.getWifiName();

      // Show connection progress
      _showConnectionProgress(device.ssid);

      // Attempt to connect to the device
      final connected = await WiFiForIoTPlugin.connect(
        device.ssid,
        password: password,
        security: NetworkSecurity.WPA,
        joinOnce: true,
      );

      if (!mounted) return;

      if (connected) {
        // Save the connected device
        await _saveConnectedDevice(device.ssid);

        // Connection successful
        _showConnectionSuccess(device.ssid);

        // Navigate back with success result after a short delay
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            Navigator.of(context)
                .pop(true); // Return true to indicate successful connection
          }
        });
      } else {
        // Connection failed
        _showConnectionError('Failed to connect to the device');
        // Try to reconnect to previous network if available
        if (currentSSID != null) {
          await WiFiForIoTPlugin.connect(currentSSID.replaceAll('"', ''));
        }
      }
    } catch (e) {
      debugPrint('Error connecting to device: $e');
      if (mounted) {
        _showConnectionError('Error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isConnecting = false);
      }
    }
  }

  void _showConnectionProgress(String ssid) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(width: 16),
            Text(
              'Connecting to $ssid...',
              style: const TextStyle(fontFamily: 'Barlow'),
            ),
          ],
        ),
        duration: const Duration(seconds: 30),
      ),
    );
  }

  void _showConnectionSuccess(String ssid) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle,
              color: Colors.white,
            ),
            const SizedBox(width: 16),
            Text(
              'Connected to $ssid',
              style: const TextStyle(fontFamily: 'Barlow'),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showConnectionError(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'Barlow')),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // If we have a connected device, show that instead of scanning
    if (_connectedDeviceSSID != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Connected Device',
            style: TextStyle(fontFamily: 'Barlow', fontWeight: FontWeight.w600),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
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
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
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
            ],
          ),
        ),
      );
    }

    // Original scanning UI
    return WillPopScope(
      onWillPop: () async {
        _scanTimer?.cancel();
        _wifiCheckTimer?.cancel();
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Scanning for Devices',
            style: TextStyle(fontFamily: 'Barlow', fontWeight: FontWeight.w600),
          ),
          actions: [
            if (!_isWifiEnabled)
              IconButton(
                icon: const Icon(CupertinoIcons.wifi),
                onPressed: () async {
                  await _showEnableWifiDialog();
                },
                tooltip: 'Enable WiFi',
              ),
          ],
        ),
        body: Stack(
          children: [
            Center(
              child: _isWifiEnabled
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_foundDevices.isEmpty) ...[
                          SizedBox(
                            width: 120,
                            height: 120,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: 120,
                                  height: 120,
                                  child: CircularProgressIndicator(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    strokeWidth: 4,
                                  ),
                                ),
                                Icon(
                                  Icons.memory,
                                  size: 60,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                          Text(
                            'Searching for ESP32 Devices...',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontFamily: 'Barlow',
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: 16),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              'Make sure your ESP32 device is nearby and powered on',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Barlow',
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ] else ...[
                          Expanded(
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Text(
                                    'ESP32 Device${_foundDevices.length > 1 ? 's' : ''} Found!',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          fontFamily: 'Barlow',
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ),
                                Expanded(
                                  child: ListView.builder(
                                    itemCount: _foundDevices.length,
                                    padding: const EdgeInsets.all(16),
                                    itemBuilder: (context, index) {
                                      final device = _foundDevices[index];
                                      return Card(
                                        child: ListTile(
                                          leading: Icon(
                                            Icons.memory,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                          ),
                                          title: Text(
                                            device.ssid.isEmpty
                                                ? 'ESP32 Device'
                                                : device.ssid,
                                            style: const TextStyle(
                                              fontFamily: 'Barlow',
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          subtitle: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Signal Strength: ${device.level} dBm',
                                                style: const TextStyle(
                                                    fontFamily: 'Barlow'),
                                              ),
                                              Text(
                                                'MAC: ${device.bssid}',
                                                style: const TextStyle(
                                                  fontFamily: 'Barlow',
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                          trailing: const Icon(
                                              Icons.arrow_forward_ios),
                                          onTap: _isConnecting
                                              ? null
                                              : () =>
                                                  _showPasswordDialog(device),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(60),
                          ),
                          child: Icon(
                            Icons.wifi_off,
                            size: 60,
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          'WiFi is Off',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontFamily: 'Barlow',
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                        const SizedBox(height: 16),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            'Please turn on WiFi to scan for nearby ESP32 devices',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Barlow',
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        FilledButton.icon(
                          onPressed: _turnOnWifi,
                          icon: const Icon(Icons.wifi),
                          label: const Text(
                            'Turn On WiFi',
                            style: TextStyle(
                              fontFamily: 'Barlow',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
            if (_isConnecting)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
