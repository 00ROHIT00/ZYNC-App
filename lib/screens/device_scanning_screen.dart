import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';

class DeviceScanningScreen extends StatefulWidget {
  const DeviceScanningScreen({super.key});

  @override
  State<DeviceScanningScreen> createState() => _DeviceScanningScreenState();
}

class _DeviceScanningScreenState extends State<DeviceScanningScreen> {
  bool _isScanning = false;
  bool _isBluetoothOn = false;
  StreamSubscription<BluetoothAdapterState>? _adapterStateSubscription;

  @override
  void initState() {
    super.initState();
    _checkBluetoothState();
  }

  @override
  void dispose() {
    _adapterStateSubscription?.cancel();
    stopScan();
    super.dispose();
  }

  Future<void> _checkBluetoothState() async {
    try {
      _adapterStateSubscription = FlutterBluePlus.adapterState.listen((state) {
        setState(() {
          _isBluetoothOn = state == BluetoothAdapterState.on;
          if (_isBluetoothOn && !_isScanning) {
            startScan();
          }
        });
      });
    } catch (e) {
      debugPrint('Error checking Bluetooth state: $e');
    }
  }

  Future<void> startScan() async {
    try {
      setState(() => _isScanning = true);
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 30),
        androidUsesFineLocation: true,
      );
    } catch (e) {
      debugPrint('Error starting scan: $e');
      setState(() => _isScanning = false);
    }
  }

  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
      setState(() => _isScanning = false);
    } catch (e) {
      debugPrint('Error stopping scan: $e');
    }
  }

  Future<void> _turnOnBluetooth() async {
    try {
      await FlutterBluePlus.turnOn();
    } catch (e) {
      debugPrint('Error turning on Bluetooth: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Scanning for Devices',
          style: TextStyle(fontFamily: 'Barlow', fontWeight: FontWeight.w600),
        ),
      ),
      body: Center(
        child: _isBluetoothOn
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
                          Icons.bluetooth_searching,
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
                      Icons.bluetooth_disabled,
                      size: 60,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Bluetooth is Off',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontFamily: 'Barlow',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'Please turn on Bluetooth to scan for nearby ZYNC devices',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Barlow',
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: _turnOnBluetooth,
                    icon: const Icon(Icons.bluetooth),
                    label: const Text(
                      'Turn On Bluetooth',
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
}
