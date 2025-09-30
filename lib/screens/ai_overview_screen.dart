import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:async';
import 'package:wifi_iot/wifi_iot.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:network_info_plus/network_info_plus.dart';
import '../config/gemini_config.dart';

class AIOverviewScreen extends StatefulWidget {
  const AIOverviewScreen({super.key});

  @override
  State<AIOverviewScreen> createState() => _AIOverviewScreenState();
}

class _AIOverviewScreenState extends State<AIOverviewScreen> {
  bool _isScanning = false;
  List<NetworkData> _networks = [];
  String? _errorMessage;
  String? _expandedNetworkBssid;
  Map<String, String> _aiAnalysisCache = {};
  Map<String, bool> _loadingAnalysis = {};

  @override
  void initState() {
    super.initState();
    // Check connection before auto-starting scan
    Future.delayed(const Duration(milliseconds: 500), () {
      _checkConnectionAndScan();
    });
  }

  Future<void> _checkConnectionAndScan() async {
    // Check if connected to ZYNC device
    final prefs = await SharedPreferences.getInstance();
    final connectedSSID = prefs.getString('connected_device_ssid');
    
    if (connectedSSID == null) {
      setState(() {
        _errorMessage = 'Not connected to ZYNC Device. Please connect a device first.';
      });
      return;
    }
    
    // Verify actual WiFi connection
    try {
      final info = NetworkInfo();
      final currentSSID = await info.getWifiName();
      final cleanSSID = currentSSID?.replaceAll('"', '');
      
      if (cleanSSID != connectedSSID) {
        // Clear stale connection state
        await prefs.remove('connected_device_ssid');
        setState(() {
          _errorMessage = 'Not connected to ZYNC Device. Please connect a device first.';
        });
        return;
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Not connected to ZYNC Device. Please connect a device first.';
      });
      return;
    }
    
    // If connected, start scan
    _startScan();
  }

  Future<void> _startScan() async {
    if (!GeminiConfig.isConfigured) {
      setState(() {
        _errorMessage = 'Gemini API key not configured. Please add your API key in lib/config/gemini_config.dart';
      });
      return;
    }

    setState(() {
      _isScanning = true;
      _errorMessage = null;
      _networks.clear();
      _expandedNetworkBssid = null;
      _aiAnalysisCache.clear();
      _loadingAnalysis.clear();
    });

    try {
      final List<WifiNetwork> networks = await WiFiForIoTPlugin.loadWifiList();
      final List<NetworkData> results = networks
          .map((n) => NetworkData(
                ssid: n.ssid ?? 'Hidden Network',
                bssid: n.bssid ?? '',
                rssi: n.level ?? 0,
                channel: n.frequency ?? 0,
                security: n.capabilities ?? 'Unknown',
              ))
          .where((n) => n.ssid.toUpperCase() != 'ZYNC_DEVICE') // Filter out ZYNC_Device
          .toList();

      // Minimum scan time for better UX
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        setState(() {
          _networks = results;
          _isScanning = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Scan failed: $e';
          _isScanning = false;
        });
      }
    }
  }

  Future<String> _getAIAnalysis(NetworkData network) async {
    // Check cache first
    if (_aiAnalysisCache.containsKey(network.bssid)) {
      return _aiAnalysisCache[network.bssid]!;
    }

    try {
      final model = GenerativeModel(
        model: 'gemini-1.5-flash-latest',
        apiKey: GeminiConfig.apiKey,
      );

      final prompt = '''
Analyze this WiFi network and provide a security assessment:

Network Name (SSID): ${network.ssid}
Security Type: ${network.security}
Signal Strength: ${network.rssi} dBm (${_getSignalQuality(network.rssi)})
Channel/Frequency: ${network.channel} MHz

Please provide:
1. Security Level (Secure/Vulnerable/Critical)
2. Security Concerns (if any)
3. What this network could be used for
4. Recommendations for the user

Keep the response concise and user-friendly (max 200 words).
''';

      final content = [Content.text(prompt)];
      
      // Retry logic for API overload
      int retries = 3;
      Exception? lastError;
      
      for (int i = 0; i < retries; i++) {
        try {
          final response = await model.generateContent(content);
          final analysis = response.text ?? 'Unable to generate analysis';
          _aiAnalysisCache[network.bssid] = analysis;
          return analysis;
        } catch (e) {
          lastError = e is Exception ? e : Exception(e.toString());
          if (i < retries - 1) {
            // Wait before retrying (exponential backoff)
            await Future.delayed(Duration(seconds: (i + 1) * 2));
          }
        }
      }
      
      // If all retries failed, just return the basic analysis without error message
      return _getBasicAnalysis(network);
    } catch (e) {
      // Return basic analysis without showing error to user
      return _getBasicAnalysis(network);
    }
  }

  String _getBasicAnalysis(NetworkData network) {
    final risk = _getRiskLevel(network.security);
    final signal = _getSignalQuality(network.rssi);
    
    String analysis = '';
    
    // Security assessment
    if (risk == 'Critical') {
      analysis += '🔴 CRITICAL RISK: This is an open network with no encryption. Anyone can intercept your data.\n\n';
      analysis += 'Security Concerns:\n• No password protection\n• All traffic visible to others\n• Easy target for hackers\n\n';
      analysis += 'Recommendation: AVOID this network. Never use for sensitive activities.';
    } else if (risk == 'Vulnerable') {
      analysis += '🟠 VULNERABLE: This network uses outdated security (WEP or old WPA).\n\n';
      analysis += 'Security Concerns:\n• Weak encryption\n• Can be cracked with tools\n• Not recommended for important data\n\n';
      analysis += 'Recommendation: Use only if necessary, preferably with a VPN.';
    } else if (risk == 'Secure') {
      analysis += '🟢 SECURE: This network uses modern encryption (WPA2/WPA3).\n\n';
      analysis += 'Security Features:\n• Strong encryption\n• Protected against common attacks\n• Safe for general use\n\n';
      analysis += 'Recommendation: Safe to use for most activities. Signal is $signal.';
    } else {
      analysis += '⚪ UNKNOWN: Security type could not be determined.\n\n';
      analysis += 'Recommendation: Proceed with caution. Verify network security before connecting.';
    }
    
    return analysis;
  }

  String _getSignalQuality(int rssi) {
    if (rssi >= -50) return 'Excellent';
    if (rssi >= -60) return 'Good';
    if (rssi >= -70) return 'Fair';
    return 'Weak';
  }

  String _getRiskLevel(String security) {
    final s = security.toUpperCase();
    if (s.contains('OPEN')) return 'Critical';
    if (s.contains('WEP')) return 'Vulnerable';
    if (s.contains('WPA3') || s.contains('WPA2')) return 'Secure';
    if (s.contains('WPA')) return 'Vulnerable';
    return 'Unknown';
  }

  Color _getRiskColor(String security) {
    final risk = _getRiskLevel(security);
    switch (risk) {
      case 'Critical':
        return Colors.red.shade700;
      case 'Vulnerable':
        return Colors.orange.shade700;
      case 'Secure':
        return Colors.green.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  IconData _getRiskIcon(String security) {
    final risk = _getRiskLevel(security);
    switch (risk) {
      case 'Critical':
        return Icons.dangerous;
      case 'Vulnerable':
        return Icons.warning;
      case 'Secure':
        return Icons.verified_user;
      default:
        return Icons.help_outline;
    }
  }

  Future<void> _toggleNetworkExpansion(NetworkData network) async {
    if (_expandedNetworkBssid == network.bssid) {
      // Collapse
      setState(() {
        _expandedNetworkBssid = null;
      });
    } else {
      // Expand and load AI analysis
      setState(() {
        _expandedNetworkBssid = network.bssid;
        _loadingAnalysis[network.bssid] = true;
      });

      // Get AI analysis
      final analysis = await _getAIAnalysis(network);
      
      if (mounted) {
        setState(() {
          _loadingAnalysis[network.bssid] = false;
          _aiAnalysisCache[network.bssid] = analysis;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'AI Network Overview',
          style: TextStyle(fontFamily: 'Barlow', fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isScanning ? null : _checkConnectionAndScan,
          ),
        ],
      ),
      body: Column(
        children: [
          // Status bar
          Container(
            padding: const EdgeInsets.all(16),
            color: _isScanning
                ? theme.colorScheme.primaryContainer
                : (_errorMessage != null
                    ? theme.colorScheme.errorContainer
                    : theme.colorScheme.surfaceVariant),
            child: Row(
              children: [
                if (_isScanning)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(
                    _errorMessage != null ? Icons.error_outline : Icons.radar,
                    color: _errorMessage != null
                        ? theme.colorScheme.error
                        : theme.colorScheme.primary,
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _isScanning
                        ? 'Scanning for networks...'
                        : _errorMessage ??
                            'Found ${_networks.length} network${_networks.length != 1 ? 's' : ''}',
                    style: TextStyle(
                      fontFamily: 'Barlow',
                      fontWeight: FontWeight.w600,
                      color: _errorMessage != null
                          ? theme.colorScheme.error
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Networks list
          Expanded(
            child: _networks.isEmpty && !_isScanning
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.wifi_off,
                          size: 64,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage ?? 'No networks found',
                          style: TextStyle(
                            fontSize: 16,
                            color: theme.colorScheme.onSurfaceVariant,
                            fontFamily: 'Barlow',
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _checkConnectionAndScan,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Scan Again'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _networks.length,
                    itemBuilder: (context, index) {
                      final network = _networks[index];
                      final isExpanded = _expandedNetworkBssid == network.bssid;
                      final isLoading = _loadingAnalysis[network.bssid] ?? false;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: isExpanded ? 4 : 1,
                        child: InkWell(
                          onTap: () => _toggleNetworkExpansion(network),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Network header
                                Row(
                                  children: [
                                    Icon(
                                      _getRiskIcon(network.security),
                                      color: _getRiskColor(network.security),
                                      size: 28,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            network.ssid,
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              fontFamily: 'Barlow',
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: _getRiskColor(network.security)
                                                      .withOpacity(0.2),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  _getRiskLevel(network.security),
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: _getRiskColor(network.security),
                                                    fontFamily: 'Barlow',
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                _getSignalQuality(network.rssi),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: theme.colorScheme.onSurfaceVariant,
                                                  fontFamily: 'Barlow',
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      isExpanded
                                          ? Icons.keyboard_arrow_up
                                          : Icons.keyboard_arrow_down,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ],
                                ),

                                // Expanded details with AI analysis
                                if (isExpanded) ...[
                                  const SizedBox(height: 16),
                                  const Divider(),
                                  const SizedBox(height: 16),

                                  // Basic network info
                                  _buildInfoRow(
                                    'Security',
                                    network.security,
                                    Icons.security,
                                    theme,
                                  ),
                                  const SizedBox(height: 8),
                                  _buildInfoRow(
                                    'Signal Strength',
                                    '${network.rssi} dBm',
                                    Icons.signal_wifi_4_bar,
                                    theme,
                                  ),
                                  const SizedBox(height: 8),
                                  _buildInfoRow(
                                    'Channel',
                                    '${network.channel} MHz',
                                    Icons.router,
                                    theme,
                                  ),

                                  const SizedBox(height: 16),
                                  const Divider(),
                                  const SizedBox(height: 16),

                                  // AI Analysis section
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.auto_awesome,
                                        size: 20,
                                        color: theme.colorScheme.primary,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'AI Security Analysis',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.primary,
                                          fontFamily: 'Barlow',
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  if (isLoading)
                                    Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(24),
                                        child: Column(
                                          children: [
                                            const CircularProgressIndicator(),
                                            const SizedBox(height: 16),
                                            Text(
                                              'Analyzing network with Gemini AI...',
                                              style: TextStyle(
                                                color: theme.colorScheme.onSurfaceVariant,
                                                fontFamily: 'Barlow',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  else if (_aiAnalysisCache.containsKey(network.bssid))
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.surfaceVariant
                                            .withOpacity(0.5),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        _aiAnalysisCache[network.bssid]!,
                                        style: TextStyle(
                                          fontSize: 14,
                                          height: 1.5,
                                          color: theme.colorScheme.onSurfaceVariant,
                                          fontFamily: 'Barlow',
                                        ),
                                      ),
                                    ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon, ThemeData theme) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurfaceVariant,
            fontFamily: 'Barlow',
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurface,
              fontFamily: 'Barlow',
            ),
          ),
        ),
      ],
    );
  }
}

class NetworkData {
  final String ssid;
  final String bssid;
  final int rssi;
  final int channel;
  final String security;

  NetworkData({
    required this.ssid,
    required this.bssid,
    required this.rssi,
    required this.channel,
    required this.security,
  });
}
