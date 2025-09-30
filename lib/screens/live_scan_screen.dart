import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:wifi_iot/wifi_iot.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:app_settings/app_settings.dart';
import '../services/scan_log_db.dart';

class LiveScanScreen extends StatefulWidget {
  const LiveScanScreen({super.key});

  @override
  State<LiveScanScreen> createState() => _LiveScanScreenState();
}

class _LiveScanScreenState extends State<LiveScanScreen> {
  // Phone WiFi scan results
  List<NetworkData> _phoneScanResults = [];
  bool _isPhoneScanning = false;
  final GlobalKey<RefreshIndicatorState> _refreshKey =
      GlobalKey<RefreshIndicatorState>();

  // Start phone WiFi scan
  Future<void> _startPhoneWifiScan() async {
    final int minimumSpinnerMs = 3000;
    final start = DateTime.now();
    setState(() {
      _isPhoneScanning = true;
      _errorMessage = null;
      _phoneScanResults.clear();
    });
    try {
      final List<WifiNetwork> networks = await WiFiForIoTPlugin.loadWifiList();
      final List<NetworkData> results = networks
          .map((n) => NetworkData(
                ssid: n.ssid ?? '',
                mac: n.bssid ?? '',
                rssi: n.level ?? 0,
                channel: n.frequency ?? 0,
                security: n.capabilities ?? '',
              ))
          .toList();
      final elapsed = DateTime.now().difference(start).inMilliseconds;
      final remaining = minimumSpinnerMs - elapsed;
      if (remaining > 0) {
        await Future.delayed(Duration(milliseconds: remaining));
      }
      if (mounted) {
        setState(() {
          _phoneScanResults = results;
          _isPhoneScanning = false;
        });
      }
      // Persist scan results to logs and save session stats
      try {
        final now = DateTime.now().millisecondsSinceEpoch;
        final sessionId = 'session_$now';
        
        // Calculate statistics (Low risk = Secure, Medium/High = Vulnerable)
        int secureCount = 0;
        int vulnerableCount = 0;
        
        for (final n in results) {
          final risk = _assessRisk(n.security);
          if (risk == _Risk.low) {
            secureCount++;
          } else {
            vulnerableCount++;
          }
        }
        
        final payload = results
            .map((n) => {
                  'ssid': n.ssid,
                  'bssid': n.mac,
                  'security': n.security,
                  'channel': n.channel,
                  'rssi': n.rssi,
                  'now': now,
                  'risk': _getRiskString(_assessRisk(n.security)),
                  'source': 'live_scan',
                  'sessionId': sessionId,
                })
            .toList();
        await ScanLogDb().upsertNetworks(payload);
        
        // Save session statistics
        await ScanLogDb().saveScanSession(
          sessionId: sessionId,
          timestamp: now,
          totalNetworks: results.length,
          secureNetworks: secureCount,
          vulnerableNetworks: vulnerableCount,
        );
      } catch (_) {}
    } catch (e) {
      final elapsed = DateTime.now().difference(start).inMilliseconds;
      final remaining = minimumSpinnerMs - elapsed;
      if (remaining > 0) {
        await Future.delayed(Duration(milliseconds: remaining));
      }
      if (mounted) {
        setState(() {
          _errorMessage = 'Phone WiFi scan failed: $e';
          _isPhoneScanning = false;
        });
      }
    }
  }

  // Stop phone scan and clear results
  void _stopPhoneWifiScan() {
    setState(() {
      _isPhoneScanning = false;
      _phoneScanResults.clear();
    });
  }

  // Handles incoming TCP data from ESP32
  void _handleSocketData(List<int> data) {
    try {
      final message = String.fromCharCodes(data).trim();
      debugPrint('[DEBUG] Received from ESP32: $message');

      if (message.startsWith('LIVE_DATA:')) {
        _parseLiveData(message);
      } else if (message.startsWith('LIVE_SCAN_STARTED')) {
        setState(() {
          _isScanning = true;
          _connectionStatus = 'Live scan started';
          _errorMessage = null; // Clear any previous errors
        });
      } else if (message.startsWith('LIVE_SCAN_STOPPED')) {
        setState(() {
          _isScanning = false;
          _connectionStatus = 'Live scan stopped';
        });
      } else if (message.startsWith('LIVE_SCAN_ERROR:')) {
        final error = message.substring('LIVE_SCAN_ERROR:'.length);
        setState(() {
          _errorMessage = 'ESP32 Error: $error';
          _isScanning = false;
        });
      } else if (message.startsWith('ZYNC_LIVE_SCAN_READY')) {
        setState(() {
          _connectionStatus = 'ESP32 Ready for Live Scan';
          _errorMessage = null; // Clear any previous errors
        });
        debugPrint('[DEBUG] ZYNC_LIVE_SCAN_READY received');
      } else if (message == 'PING') {
        // Respond to ESP32 ping to keep connection alive
        if (_socket != null && _socket!.isBroadcast) {
          _socket!.write('PONG\n');
        }
      } else {
        debugPrint('[DEBUG] Received unknown message: $message');
      }
    } catch (e) {
      debugPrint('[DEBUG] Error handling socket data: $e');
    }
  }

  // --- Static constants ---
  static const String ESP32_SSID = 'ZYNC_Device';
  static const String ESP32_PASSWORD = 'zync1234';
  static const int ESP32_PORT = 8888;
  static const List<String> ESP32_IP_CANDIDATES = [
    '192.168.4.1', // Default ESP32 AP mode
    '192.168.1.1', // Common router IP
    '192.168.0.1', // Another common router IP
    '10.0.0.1', // Alternative network range
  ];
  static const String CMD_START_SCAN = 'START_LIVE_SCAN';
  static const String CMD_STOP_SCAN = 'STOP_LIVE_SCAN';

  // --- State variables ---
  bool _isConnected = false;
  bool _isScanning = false;
  bool _isConnecting = false;
  String _connectionStatus = 'Not Connected';
  List<NetworkData> _networks = [];
  String? _errorMessage;
  Socket? _socket;
  Timer? _connectionTimer;
  Timer? _reconnectTimer;
  String? _manualESP32IP;

  // --- Helper for TCP connection retry ---
  Future<void> _connectToWiFi() async {
    // TODO: Implement actual WiFi connection logic if needed
    return;
  }

  Future<void> _closeAndRetryTCPConnection() async {
    try {
      if (_socket != null) {
        debugPrint('[DEBUG] Closing previous socket connection');
        await _socket!.close();
      }
    } catch (e) {
      debugPrint('[DEBUG] Error closing socket: $e');
    }
    _socket = null;

    int retries = 0;
    bool connected = false;
    Exception? lastError;
    while (!connected && retries < 3) {
      try {
        debugPrint(
            '[DEBUG] TCP connect attempt ${retries + 1} to $_manualESP32IP:$ESP32_PORT');
        await _connectToSocket();
        connected = true;
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        debugPrint('[DEBUG] TCP connection failed: $e');
        await Future.delayed(const Duration(seconds: 2));
        retries++;
      }
    }
    if (!connected) {
      debugPrint('[DEBUG] All TCP connection attempts failed');
      throw lastError ?? Exception('TCP connection failed');
    }
  }

  @override
  void initState() {
    super.initState();
    // Set the known ESP32 IP by default
    _manualESP32IP = '192.168.4.1';
    _checkCurrentConnection();
  }

  @override
  void dispose() {
    _disconnectFromESP32();
    _connectionTimer?.cancel();
    _reconnectTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkCurrentConnection() async {
    try {
      final info = NetworkInfo();
      final currentSSID = await info.getWifiName();

      if (currentSSID?.replaceAll('"', '') == ESP32_SSID) {
        setState(() {
          _connectionStatus = 'Connected to ZYNC Device';
          _isConnected = true;
        });
        // Auto-start phone WiFi scan when already connected to ESP32
        await _startLiveScan();
      } else {
        setState(() {
          _connectionStatus = 'Not connected to ZYNC Device';
          _isConnected = false;
        });
      }
    } catch (e) {
      debugPrint('Error checking current connection: $e');
    }
  }

  Future<void> _connectToESP32() async {
    if (_isConnecting) return;
    setState(() {
      _isConnecting = true;
      _errorMessage = null;
      _connectionStatus = 'Checking ESP32 WiFi...';
    });

    try {
      // Only verify WiFi SSID; no TCP socket for this flow
      final info = NetworkInfo();
      final currentSSID = await info.getWifiName();
      debugPrint('Current SSID: $currentSSID');
      if (currentSSID?.replaceAll('"', '') != ESP32_SSID) {
        throw Exception('Not connected to ESP32 WiFi');
      }

      setState(() {
        _isConnected = true;
        _isConnecting = false;
        _connectionStatus = 'Connected to ESP32 WiFi';
      });
    } catch (e) {
      setState(() {
        _isConnected = false;
        _isConnecting = false;
        _errorMessage = 'Connection check failed: $e';
        _connectionStatus = 'Not connected to ZYNC Device';
      });
      debugPrint('Connection check error: $e');
    }
  }

  Future<void> _connectToSocket() async {
    try {
      setState(() {
        _connectionStatus = 'Establishing TCP connection...';
      });

      // Always try the known ESP32 IP first, then fallback to discovery
      String? esp32IP = _manualESP32IP;

      // If no manual IP is set, try the known ESP32 IP first
      if (esp32IP == null) {
        debugPrint(
            '[DEBUG] No manual IP set, trying known ESP32 IP: 192.168.4.1');
        esp32IP = '192.168.4.1';
      }

      debugPrint(
          '[DEBUG] Attempting connection to ESP32 at $esp32IP:$ESP32_PORT');

      // Create socket connection
      _socket = await Socket.connect(esp32IP, ESP32_PORT,
          timeout: const Duration(seconds: 10));

      // Set up data listener
      _socket!.listen(
        _handleSocketData,
        onError: _handleSocketError,
        onDone: _handleSocketClosed,
        cancelOnError: false,
      );

      debugPrint('[DEBUG] TCP connection established to $esp32IP:$ESP32_PORT');

      // Wait a moment for the ESP32 to send the welcome message
      await Future.delayed(const Duration(milliseconds: 1000));

      // Verify we received the welcome message
      if (_connectionStatus != 'ESP32 Ready for Live Scan') {
        debugPrint('[DEBUG] Warning: Did not receive ESP32 welcome message');
        // Still consider connection successful if we can communicate
        setState(() {
          _connectionStatus = 'Connected to ESP32 (awaiting welcome message)';
        });
      }
    } catch (e) {
      debugPrint('[DEBUG] TCP connection error: $e');
      throw Exception('TCP connection failed: $e');
    }
  }

  Future<String?> _discoverESP32IP() async {
    try {
      // Get the gateway IP (usually the ESP32's IP when connected to its WiFi)
      final info = NetworkInfo();
      final gatewayIP = await info.getWifiGatewayIP();

      debugPrint('Gateway IP discovery result: $gatewayIP');

      if (gatewayIP != null && gatewayIP.isNotEmpty) {
        debugPrint('Discovered gateway IP: $gatewayIP');
        return gatewayIP;
      }

      // If gateway discovery fails, try to get WiFi info
      final wifiIP = await info.getWifiIP();
      debugPrint('WiFi IP: $wifiIP');

      // If we have a WiFi IP, try to construct the gateway IP
      if (wifiIP != null && wifiIP.isNotEmpty) {
        final parts = wifiIP.split('.');
        if (parts.length == 4) {
          final gatewayCandidate = '${parts[0]}.${parts[1]}.${parts[2]}.1';
          debugPrint('Constructed gateway candidate: $gatewayCandidate');
          return gatewayCandidate;
        }
      }
    } catch (e) {
      debugPrint('Error discovering ESP32 IP: $e');
    }
    return null;
  }

  Future<String?> _tryCommonIPs() async {
    for (final ip in ESP32_IP_CANDIDATES) {
      try {
        debugPrint('Trying to connect to $ip:$ESP32_PORT');
        final testSocket = await Socket.connect(ip, ESP32_PORT,
            timeout: const Duration(seconds: 3));
        await testSocket.close();
        debugPrint('Successfully connected to $ip:$ESP32_PORT');
        return ip;
      } catch (e) {
        debugPrint('Failed to connect to $ip:$ESP32_PORT - $e');
        continue;
      }
    }
    return null;
  }

  void _parseLiveData(String message) {
    try {
      // Format: LIVE_DATA:3:SSID1,MAC1,RSSI1,CH1,SEC1;SSID2,MAC2,RSSI2,CH2,SEC2
      final parts = message.split(':');
      if (parts.length < 3) return;

      final networkCount =
          int.tryParse(parts[1]) ?? 0; // unused, kept for format completeness
      final networkData = parts[2];

      if (networkData.isEmpty) return;

      final networks = networkData.split(';');
      final List<NetworkData> newNetworks = [];

      for (final network in networks) {
        if (network.isEmpty) continue;

        final fields = network.split(',');
        if (fields.length >= 5) {
          newNetworks.add(NetworkData(
            ssid: fields[0],
            mac: fields[1],
            rssi: int.tryParse(fields[2]) ?? 0,
            channel: int.tryParse(fields[3]) ?? 0,
            security: fields[4],
          ));
        }
      }

      if (mounted) {
        setState(() {
          _networks = newNetworks;
          _errorMessage = null;
        });
      }
    } catch (e) {
      debugPrint('Error parsing live data: $e');
    }
  }

  void _handleSocketError(error) {
    debugPrint('[DEBUG] Socket error: $error');
    setState(() {
      _errorMessage = 'Socket error: $error';
      _isConnected = false;
      _isScanning = false;
    });
    _scheduleReconnect();
  }

  void _handleSocketClosed() {
    debugPrint('[DEBUG] Socket closed');
    setState(() {
      _isConnected = false;
      _isScanning = false;
      _connectionStatus = 'Connection lost';
    });
    _scheduleReconnect();
  }

  void _startConnectionMonitoring() {
    _connectionTimer?.cancel();
    _connectionTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkConnectionHealth();
    });
  }

  void _checkConnectionHealth() async {
    if (!_isConnected || _socket == null) return;

    try {
      // Check WiFi connection
      final info = NetworkInfo();
      final currentSSID = await info.getWifiName();
      if (currentSSID?.replaceAll('"', '') != ESP32_SSID) {
        throw Exception('WiFi connection lost');
      }

      // Check if socket is still responsive
      if (_socket != null && _socket!.isBroadcast) {
        try {
          _socket!.write('PING\n');
        } catch (e) {
          debugPrint('Socket ping failed: $e');
          throw Exception('Socket connection lost');
        }
      }
    } catch (e) {
      debugPrint('Connection health check failed: $e');
      _handleSocketError(e);
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && !_isConnected) {
        _connectToESP32();
      }
    });
  }

  Future<void> _startLiveScan() async {
    // Use phone WiFi to scan, but require ESP32 WiFi connection
    final info = NetworkInfo();
    final currentSSID = await info.getWifiName();
    if (currentSSID?.replaceAll('"', '') != ESP32_SSID) {
      setState(() {
        _errorMessage = 'Please connect to the ESP32 (ZYNC_Device) first.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not connected to ESP32 WiFi')),
      );
      return;
    }

    setState(() {
      _errorMessage = null;
    });
    await _startPhoneWifiScan();
  }

  Future<void> _openWifiSettings() async {
    try {
      // Use app_settings to deep-link to WiFi settings if possible
      await AppSettings.openAppSettings(type: AppSettingsType.wifi);
    } catch (e) {
      // Fallback to generic settings if WiFi page not available
      await openAppSettings();
    }
  }

  Future<void> _stopLiveScan() async {
    if (!_isConnected || _socket == null) return;

    try {
      _socket!.write('$CMD_STOP_SCAN\n');
      debugPrint('Sent: $CMD_STOP_SCAN');
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to stop scan: $e';
      });
    }
  }

  Future<void> _disconnectFromESP32() async {
    try {
      // Stop scan if running
      if (_isScanning) {
        await _stopLiveScan();
      }

      // Close socket
      await _socket?.close();
      _socket = null;

      // Cancel timers
      _connectionTimer?.cancel();
      _reconnectTimer?.cancel();

      setState(() {
        _isConnected = false;
        _isScanning = false;
        _isConnecting = false;
        _connectionStatus = 'Disconnected';
        _networks.clear();
      });
    } catch (e) {
      debugPrint('Error disconnecting: $e');
    }
  }

  void _showSettingsDialog() {
    final ipController =
        TextEditingController(text: _manualESP32IP ?? '192.168.4.1');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'ESP32 Connection Settings',
          style: TextStyle(fontFamily: 'Barlow', fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Configure ESP32 connection settings:',
              style: TextStyle(fontFamily: 'Barlow'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ipController,
              decoration: const InputDecoration(
                labelText: 'ESP32 IP Address',
                hintText: 'e.g., 192.168.4.1',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            const Text(
              'Current ESP32 Configuration:',
              style:
                  TextStyle(fontFamily: 'Barlow', fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              '• MAC: F4:65:0B:E8:E9:91',
              style: TextStyle(fontFamily: 'Barlow', color: Colors.grey),
            ),
            const Text(
              '• IP: 192.168.4.1',
              style: TextStyle(fontFamily: 'Barlow', color: Colors.grey),
            ),
            const Text(
              '• Port: 8888',
              style: TextStyle(fontFamily: 'Barlow', color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                final ip = ipController.text.trim();
                if (ip.isNotEmpty) {
                  Navigator.of(context).pop();
                  await _testConnection(ip);
                }
              },
              child: const Text('Test Connection'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final ip = ipController.text.trim();
              if (ip.isNotEmpty) {
                setState(() {
                  _manualESP32IP = ip;
                });
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('ESP32 IP set to: $ip')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _testConnection(String ip) async {
    try {
      setState(() {
        _connectionStatus = 'Testing connection to $ip...';
      });

      debugPrint('Testing connection to $ip:$ESP32_PORT');

      // Test TCP connection
      final testSocket = await Socket.connect(ip, ESP32_PORT,
          timeout: const Duration(seconds: 5));
      await testSocket.close();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Connection successful to $ip:$ESP32_PORT'),
          backgroundColor: Colors.green,
        ),
      );

      setState(() {
        _manualESP32IP = ip;
        _connectionStatus = 'Connection test successful';
      });
    } catch (e) {
      debugPrint('Connection test failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Connection failed: $e'),
          backgroundColor: Colors.red,
        ),
      );

      setState(() {
        _connectionStatus = 'Connection test failed';
      });
    }
  }

  Color _getSignalStrengthColor(int rssi) {
    if (rssi >= -50) return Colors.green;
    if (rssi >= -60) return Colors.lightGreen;
    if (rssi >= -70) return Colors.yellow;
    if (rssi >= -80) return Colors.orange;
    return Colors.red;
  }

  Widget _buildSignalStrengthIndicator(int rssi) {
    final color = _getSignalStrengthColor(rssi);
    final bars = rssi >= -50
        ? 4
        : rssi >= -60
            ? 3
            : rssi >= -70
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

  // --- Risk UI helpers ---
  Widget _buildRiskSubtitle(NetworkData n) {
    final risk = _assessRisk(n.security);
    final color = risk == _Risk.high
        ? Colors.red
        : risk == _Risk.medium
            ? Colors.orange
            : Colors.green;
    final label = risk == _Risk.high
        ? 'High risk'
        : risk == _Risk.medium
            ? 'Medium risk'
            : 'Safer';
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: Text(label,
              style: TextStyle(
                fontFamily: 'Barlow',
                color: color,
                fontWeight: FontWeight.w600,
              )),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _riskReason(n.security),
            style: const TextStyle(fontFamily: 'Barlow', color: Colors.grey),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildRiskBadgeAndReason(NetworkData n) {
    final risk = _assessRisk(n.security);
    final color = risk == _Risk.high
        ? Colors.red
        : risk == _Risk.medium
            ? Colors.orange
            : Colors.green;
    final label = risk == _Risk.high
        ? 'High risk'
        : risk == _Risk.medium
            ? 'Medium risk'
            : 'Safer';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: Text(label,
              style: TextStyle(
                fontFamily: 'Barlow',
                color: color,
                fontWeight: FontWeight.w600,
              )),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _riskReason(n.security),
            style: const TextStyle(fontFamily: 'Barlow'),
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendation(NetworkData n) {
    final risk = _assessRisk(n.security);
    final text = risk == _Risk.high
        ? 'Avoid using this network.'
        : risk == _Risk.medium
            ? 'Use only for casual browsing.'
            : 'Preferred for most use.';
    return Text(text, style: const TextStyle(fontFamily: 'Barlow'));
  }

  Widget _buildSignalNote(int rssi) {
    final label = rssi >= -60
        ? 'Strong'
        : rssi >= -70
            ? 'OK'
            : 'Weak';
    return Text('Signal: $label', style: const TextStyle(fontFamily: 'Barlow'));
  }

  _Risk _assessRisk(String security) {
    final s = security.toUpperCase();
    if (s.contains('OPEN')) return _Risk.high;
    if (s.contains('WEP')) return _Risk.medium;
    if (s.contains('WPA3') || s.contains('WPA2')) return _Risk.low;
    if (s.contains('WPA')) return _Risk.medium;
    return _Risk.medium;
  }

  String _getRiskString(_Risk risk) {
    switch (risk) {
      case _Risk.high:
        return 'High';
      case _Risk.medium:
        return 'Medium';
      case _Risk.low:
        return 'Low';
    }
  }

  String _riskReason(String security) {
    final s = security.toUpperCase();
    if (s.contains('OPEN')) return 'No password. Anyone can join.';
    if (s.contains('WEP') ||
        (s.contains('WPA') && !s.contains('WPA2') && !s.contains('WPA3')))
      return 'Old security. Easier to break.';
    if (s.contains('WPA2') || s.contains('WPA3'))
      return 'Strong security. Harder to break.';
    return 'Security unknown.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Live Scan',
          style: TextStyle(fontFamily: 'Barlow', fontWeight: FontWeight.w600),
        ),
      ),
      body: RefreshIndicator(
        key: _refreshKey,
        onRefresh: () async {
          await _startLiveScan();
        },
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Connection status bar
            Container(
              padding: const EdgeInsets.all(12),
              color: _isConnected
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.errorContainer,
              child: Row(
                children: [
                  Icon(
                    _isConnected ? Icons.wifi : Icons.wifi_off,
                    color: _isConnected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _connectionStatus,
                      style: TextStyle(
                        fontFamily: 'Barlow',
                        fontWeight: FontWeight.w600,
                        color: _isConnected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                  if (_isConnecting)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
            ),

            // Error message
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                color: Theme.of(context).colorScheme.errorContainer,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
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
                    if (_errorMessage!.contains('TCP connection failed')) ...[
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _manualESP32IP = '192.168.4.1';
                            _errorMessage = null;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'ESP32 IP set to 192.168.4.1. Try connecting again.'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        },
                        icon: const Icon(Icons.settings),
                        label: const Text('Set IP to 192.168.4.1'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Make sure your ESP32 is powered on and the TCP server is running on port 8888.',
                        style: TextStyle(
                          fontFamily: 'Barlow',
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                    // Add troubleshooting tips for live scan issues
                    if (_errorMessage!.contains('ESP32 Error')) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Troubleshooting tips:',
                        style: TextStyle(
                          fontFamily: 'Barlow',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '• Ensure ESP32 is powered and WiFi AP is active\n'
                        '• Check that ESP32 is scanning for networks\n'
                        '• Try restarting the ESP32 device\n'
                        '• Verify WiFi connection to ZYNC_Device network',
                        style: TextStyle(
                          fontFamily: 'Barlow',
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

            // Scan status (only while scanning)
            if (_isConnected && _isPhoneScanning)
              Container(
                padding: const EdgeInsets.all(8),
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: Row(
                  children: [
                    Icon(
                      Icons.radar,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Scanning... (${_phoneScanResults.length} networks)',
                      style: TextStyle(
                        fontFamily: 'Barlow',
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ],
                ),
              ),

            // Network list (phone WiFi scan results)
            if (_isPhoneScanning)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_phoneScanResults.isNotEmpty) ...[
              ..._phoneScanResults
                  .where((n) =>
                      n.ssid != ESP32_SSID &&
                      n.mac.toUpperCase() != 'F4:65:0B:E8:E9:91')
                  .map((network) => Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: ExpansionTile(
                          leading: _buildSignalStrengthIndicator(network.rssi),
                          title: Text(
                            network.ssid.isEmpty
                                ? '<Hidden Network>'
                                : network.ssid,
                            style: const TextStyle(
                              fontFamily: 'Barlow',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: _buildRiskSubtitle(network),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildRiskBadgeAndReason(network),
                                  const SizedBox(height: 8),
                                  _buildRecommendation(network),
                                  const SizedBox(height: 12),
                                  _buildSignalNote(network.rssi),
                                  const SizedBox(height: 12),
                                  ExpansionTile(
                                    title: const Text('More details',
                                        style: TextStyle(fontFamily: 'Barlow')),
                                    childrenPadding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    children: [
                                      _detailRow('Security:', network.security),
                                      _detailRow('MAC Address:', network.mac),
                                      _detailRow(
                                          'Channel:', '${network.channel}'),
                                      _detailRow(
                                          'Signal:', '${network.rssi} dBm'),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: ElevatedButton.icon(
                                      onPressed: _openWifiSettings,
                                      icon: const Icon(Icons.wifi),
                                      label: const Text('Connect'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ] else
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(
                  child: Text(
                    'Connect to ESP32 to start scanning.',
                    style: TextStyle(
                      fontFamily: 'Barlow',
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isPhoneScanning ? null : _startLiveScan,
        tooltip: _isPhoneScanning ? 'Scanning...' : 'Refresh',
        child: const Icon(Icons.refresh),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: _isConnected
          ? null
          : BottomAppBar(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _testConnection('192.168.4.1'),
                        icon: const Icon(Icons.wifi_find),
                        label: const Text('Quick Test (192.168.4.1)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _showSettingsDialog,
                        icon: const Icon(Icons.settings),
                        label: const Text('Settings'),
                      ),
                    ),
                  ],
                ),
              ),
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

enum _Risk { high, medium, low }

class NetworkData {
  final String ssid;
  final String mac;
  final int rssi;
  final int channel;
  final String security;

  NetworkData({
    required this.ssid,
    required this.mac,
    required this.rssi,
    required this.channel,
    required this.security,
  });
}
