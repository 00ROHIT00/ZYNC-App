import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';

class LiveScanScreen extends StatefulWidget {
  const LiveScanScreen({super.key});

  @override
  State<LiveScanScreen> createState() => _LiveScanScreenState();
}

class _LiveScanScreenState extends State<LiveScanScreen> {
  final List<TerminalLine> _lines = [];
  final ScrollController _scrollController = ScrollController();
  Timer? _timer;
  bool _isScanning = false;

  final List<String> _commands = [
    'Initializing scan module...',
    'Scanning network interfaces...',
    'Detecting nearby access points...',
    'Analyzing signal strength...',
    'Checking encryption protocols...',
    'Identifying potential vulnerabilities...',
    'Mapping network topology...',
    'Monitoring traffic patterns...',
    'Scanning port 443...',
    'Scanning port 80...',
    'Checking DNS configuration...',
    'Analyzing packet structure...',
    'Verifying SSL certificates...',
    'Testing network latency...',
  ];

  final List<String> _results = [
    'Found open network: "Guest_Network"',
    'Detected WPA2 encryption on "Home_Network"',
    'High signal strength: -45 dBm',
    'Weak encryption detected on "IoT_Network"',
    'Port 80 is open on 192.168.1.1',
    'SSL certificate expires in 30 days',
    'DNS response time: 23ms',
    'Network latency: 15ms',
    'Detected hidden SSID network',
    'Found 3 devices on network',
    'MAC address: 00:1A:2B:3C:4D:5E',
    'Channel congestion detected',
    'IPv6 support verified',
    'DHCP server found: 192.168.1.1',
  ];

  @override
  void initState() {
    super.initState();
    _startScanning();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _startScanning() {
    setState(() {
      _isScanning = true;
      _lines.clear();
      _addLine('Starting ZYNC network scan...', isCommand: true);
    });

    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!_isScanning) {
        timer.cancel();
        return;
      }

      final random = Random();
      if (random.nextBool()) {
        _addLine(_commands[random.nextInt(_commands.length)], isCommand: true);
      } else {
        _addLine(_results[random.nextInt(_results.length)], isCommand: false);
      }
    });
  }

  void _stopScanning() {
    setState(() {
      _isScanning = false;
      _addLine('Scan completed.', isCommand: true);
    });
    _timer?.cancel();
  }

  void _addLine(String text, {required bool isCommand}) {
    setState(() {
      _lines.add(
        TerminalLine(
          text: text,
          timestamp: DateTime.now(),
          isCommand: isCommand,
        ),
      );
    });

    // Scroll to bottom after new line is added
    Future.delayed(const Duration(milliseconds: 50), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLightMode = theme.brightness == Brightness.light;

    return Scaffold(
      backgroundColor: isLightMode ? Colors.white : Colors.black,
      appBar: AppBar(
        title: const Text(
          'Live Scan',
          style: TextStyle(fontFamily: 'Barlow', fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: Icon(_isScanning ? Icons.stop : Icons.play_arrow),
            onPressed: _isScanning ? _stopScanning : _startScanning,
          ),
        ],
      ),
      body: Container(
        color: isLightMode ? Colors.black : Colors.black,
        child: ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          itemCount: _lines.length,
          itemBuilder: (context, index) {
            final line = _lines[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '[${line.timestamp.hour.toString().padLeft(2, '0')}:${line.timestamp.minute.toString().padLeft(2, '0')}:${line.timestamp.second.toString().padLeft(2, '0')}] ',
                        style: const TextStyle(
                          color: Colors.green,
                          fontFamily: 'monospace',
                          fontSize: 14,
                        ),
                      ),
                      if (line.isCommand)
                        const Text(
                          '\$ ',
                          style: TextStyle(
                            color: Colors.blue,
                            fontFamily: 'monospace',
                            fontSize: 14,
                          ),
                        ),
                      Expanded(
                        child: Text(
                          line.text,
                          style: TextStyle(
                            color: line.isCommand
                                ? Colors.yellow
                                : Colors.white,
                            fontFamily: 'monospace',
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class TerminalLine {
  final String text;
  final DateTime timestamp;
  final bool isCommand;

  TerminalLine({
    required this.text,
    required this.timestamp,
    required this.isCommand,
  });
}
