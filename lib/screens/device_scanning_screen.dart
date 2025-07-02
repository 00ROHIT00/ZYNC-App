import 'package:flutter/material.dart';
import 'package:wifi_scan/wifi_scan.dart';
import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:flutter/cupertino.dart';

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

  @override
  void initState() {
    super.initState();
    _initWifiScanning();
    // Periodically check WiFi state
    _wifiCheckTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _checkWifiState();
    });
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    _wifiCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkWifiState() async {
    try {
      // First check if WiFi scanning is supported
      final canScan = await WiFiScan.instance.canStartScan();
      final canGetResults = await WiFiScan.instance.canGetScannedResults();
      final isEnabled =
          canScan == CanStartScan.yes &&
          canGetResults == CanGetScannedResults.yes;

      if (mounted) {
        setState(() {
          _isWifiEnabled = isEnabled;
          if (!isEnabled) {
            _isScanning = false;
            _scanTimer?.cancel();
          }
        });

        // If WiFi was just turned off or is off initially, show the dialog
        if (!isEnabled) {
          await _showEnableWifiDialog();
        } else if (!_isScanning) {
          // Start scanning when WiFi is turned on
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
      final result = await WiFiScan.instance.startScan();
      debugPrint('WiFi scan result: $result');

      if (result == CanStartScan.yes) {
        // Scan started successfully
        final results = await WiFiScan.instance.getScannedResults();
        debugPrint('Found ${results.length} networks');
      } else {
        debugPrint('Failed to start WiFi scan: $result');
        if (mounted) {
          setState(() => _isScanning = false);
        }
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

  @override
  Widget build(BuildContext context) {
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
        body: Center(
          child: _isWifiEnabled
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
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
                              color: Theme.of(context).colorScheme.primary,
                              strokeWidth: 4,
                            ),
                          ),
                          Icon(
                            Icons.wifi_find,
                            size: 60,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Searching for ZYNC Devices...',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontFamily: 'Barlow',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        'Make sure your ZYNC device is nearby and powered on',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Barlow',
                          color: Colors.grey,
                        ),
                      ),
                    ),
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
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontFamily: 'Barlow',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        'Please turn on WiFi to scan for nearby ZYNC devices',
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
      ),
    );
  }
}
