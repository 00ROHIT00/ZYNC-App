import 'package:flutter/material.dart';
import 'dart:async';
import 'package:wifi_scan/wifi_scan.dart';
import 'package:permission_handler/permission_handler.dart';

class LiveScanScreen extends StatefulWidget {
  const LiveScanScreen({super.key});

  @override
  State<LiveScanScreen> createState() => _LiveScanScreenState();
}

class _LiveScanScreenState extends State<LiveScanScreen> {
  List<WiFiAccessPoint> _accessPoints = [];
  Timer? _scanTimer;
  bool _isScanning = false;
  String? _errorMessage;
  DateTime? _lastScanTime;

  @override
  void initState() {
    super.initState();
    _checkPermissionAndStartScan();
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkPermissionAndStartScan() async {
    try {
      // Request permissions
      if (await _requestPermissions()) {
        _startScanning();
      } else {
        setState(() {
          _errorMessage = 'Required permissions not granted';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error initializing: $e';
      });
    }
  }

  Future<bool> _requestPermissions() async {
    // Request location permission for WiFi scanning
    final status = await Permission.locationWhenInUse.request();
    return status.isGranted;
  }

  void _startScanning() {
    setState(() {
      _isScanning = true;
      _errorMessage = null;
    });

    // Perform initial scan
    _performScan();

    // Set up periodic scanning
    _scanTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _performScan();
    });
  }

  void _stopScanning() {
    _scanTimer?.cancel();
    setState(() {
      _isScanning = false;
    });
  }

  Future<void> _performScan() async {
    try {
      // Check for scan throttling
      final now = DateTime.now();
      if (_lastScanTime != null) {
        final difference = now.difference(_lastScanTime!);
        if (difference.inSeconds < 4) {
          return; // Skip this scan due to throttling
        }
      }

      final canScan = await WiFiScan.instance.canStartScan();
      if (canScan != CanStartScan.yes) {
        setState(() {
          _errorMessage = 'Cannot start WiFi scan: $canScan';
        });
        return;
      }

      // Start the scan
      final result = await WiFiScan.instance.startScan();
      if (result == true) {
        _lastScanTime = now;

        // Wait a bit for the scan to complete
        await Future.delayed(const Duration(seconds: 2));

        // Get the results
        final results = await WiFiScan.instance.getScannedResults();

        if (mounted) {
          setState(() {
            _accessPoints = results;
            _errorMessage = null;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Scan error: $e';
        });
      }
    }
  }

  String _getSecurityType(WiFiAccessPoint ap) {
    if (ap.capabilities.contains('WPA3')) return 'WPA3';
    if (ap.capabilities.contains('WPA2')) return 'WPA2';
    if (ap.capabilities.contains('WPA')) return 'WPA';
    if (ap.capabilities.contains('WEP')) return 'WEP';
    return 'Open';
  }

  Color _getSignalStrengthColor(int level) {
    if (level >= -50) return Colors.green;
    if (level >= -60) return Colors.lightGreen;
    if (level >= -70) return Colors.yellow;
    if (level >= -80) return Colors.orange;
    return Colors.red;
  }

  Widget _buildSignalStrengthIndicator(int level) {
    final color = _getSignalStrengthColor(level);
    final bars = level >= -50
        ? 4
        : level >= -60
            ? 3
            : level >= -70
                ? 2
                : 1;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(4, (index) {
        return Container(
          width: 3,
          height: 6.0 + (index * 3),
          margin: const EdgeInsets.symmetric(horizontal: 1),
          color: index < bars ? color : Colors.grey.withOpacity(0.3),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Live WiFi Scan',
          style: TextStyle(fontFamily: 'Barlow', fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: Icon(_isScanning ? Icons.stop : Icons.play_arrow),
            onPressed: _isScanning ? _stopScanning : _startScanning,
            tooltip: _isScanning ? 'Stop Scanning' : 'Start Scanning',
          ),
        ],
      ),
      body: Column(
        children: [
          // Status bar
          Container(
            padding: const EdgeInsets.all(8),
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Row(
              children: [
                Icon(
                  _isScanning ? Icons.wifi_find : Icons.wifi_off,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  _isScanning
                      ? 'Scanning... (${_accessPoints.length} networks found)'
                      : 'Scan stopped',
                  style: TextStyle(
                    fontFamily: 'Barlow',
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                if (_isScanning) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          if (_errorMessage != null)
            Container(
              padding: const EdgeInsets.all(8),
              color: Theme.of(context).colorScheme.errorContainer,
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontFamily: 'Barlow',
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Network list
          Expanded(
            child: _accessPoints.isEmpty
                ? Center(
                    child: Text(
                      _isScanning
                          ? 'Scanning for networks...'
                          : 'No networks found',
                      style: const TextStyle(
                        fontFamily: 'Barlow',
                        color: Colors.grey,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: _accessPoints.length,
                    itemBuilder: (context, index) {
                      final ap = _accessPoints[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: ExpansionTile(
                          leading: _buildSignalStrengthIndicator(ap.level),
                          title: Text(
                            ap.ssid.isEmpty ? '<Hidden Network>' : ap.ssid,
                            style: const TextStyle(
                              fontFamily: 'Barlow',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            '${_getSecurityType(ap)} • ${ap.level} dBm',
                            style: const TextStyle(fontFamily: 'Barlow'),
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _detailRow('MAC Address:', ap.bssid),
                                  _detailRow(
                                      'Frequency:', '${ap.frequency} MHz'),
                                  _detailRow('Channel:',
                                      '${(ap.frequency - 2407) ~/ 5}'),
                                  _detailRow('Security:', ap.capabilities),
                                  _detailRow(
                                    'Signal Strength:',
                                    '${ap.level} dBm',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _performScan,
        tooltip: 'Refresh Scan',
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Barlow',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontFamily: 'Barlow'),
            ),
          ),
        ],
      ),
    );
  }
}
