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
      _loadingAnalysis.clear();
    });

    try {
      final List<WifiNetwork> networks = await WiFiForIoTPlugin.loadWifiList();
      final List<NetworkData> results = networks
          .map((n) {
            // Parse the capabilities string to extract actual security protocol
            String security = _parseSecurityType(n.capabilities ?? '');
            
            return NetworkData(
              ssid: n.ssid ?? 'Unknown',
              bssid: n.bssid ?? '',
              rssi: n.level ?? 0,
              channel: n.frequency ?? 0,
              security: security,
            );
          })
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
Analyze this WiFi network for security vulnerabilities and provide a comprehensive assessment:

Network Name (SSID): ${network.ssid}
Security Type: ${network.security}
Signal Strength: ${network.rssi} dBm (${_getSignalQuality(network.rssi)})
Channel/Frequency: ${network.channel} MHz

Please analyze and provide:

1. SECURITY LEVEL: Rate as Secure/Vulnerable/Critical

2. VULNERABILITY DETECTION:
   - Check for Evil Twin Attack indicators (suspicious duplicate SSIDs, weak signal from known network)
   - Rogue Access Point signs (unusual SSID patterns, unexpected open networks)
   - Man-in-the-Middle risks
   - Weak encryption vulnerabilities (WEP, old WPA)
   - Any other security threats

3. SPECIFIC VULNERABILITIES FOUND:
   - Name each vulnerability detected
   - Explain what it is in simple terms
   - How attackers could exploit it

4. HOW TO AVOID/PROTECT:
   - Specific steps to stay safe
   - What NOT to do on this network
   - Alternative safer options

5. RECOMMENDATIONS:
   - Should the user connect? (Yes/No/Only with VPN)
   - What activities are safe/unsafe

Keep response clear and user-friendly (max 250 words). Focus on practical security advice for non-technical users.
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
    
    // Security assessment with vulnerability details
    if (risk == 'Critical') {
      analysis += '🔴 CRITICAL RISK: Open Network\n\n';
      analysis += 'VULNERABILITIES DETECTED:\n\n';
      analysis += '1. No Encryption\n';
      analysis += 'What it is: Network has no password, anyone can join.\n';
      analysis += 'Risk: All your data (passwords, messages, browsing) is visible to anyone nearby.\n\n';
      
      analysis += '2. Man-in-the-Middle Attack Risk\n';
      analysis += 'What it is: Attackers can intercept communication between you and websites.\n';
      analysis += 'Risk: Hackers can steal login credentials, credit card info, personal data.\n\n';
      
      analysis += '3. Evil Twin Potential\n';
      analysis += 'What it is: Could be a fake network set up by attackers.\n';
      analysis += 'Risk: Designed to steal your information.\n\n';
      
      analysis += 'HOW TO PROTECT:\n';
      analysis += '• DO NOT connect to this network\n';
      analysis += '• Never enter passwords on open networks\n';
      analysis += '• Use mobile data instead\n';
      analysis += '• If you must connect, use a VPN\n\n';
      
      analysis += 'RECOMMENDATION: ❌ AVOID - Find a secure network instead.';
    } else if (risk == 'Vulnerable') {
      analysis += '🟠 VULNERABLE: Weak Encryption\n\n';
      analysis += 'VULNERABILITIES DETECTED:\n\n';
      
      analysis += '1. Outdated Security (WEP/WPA)\n';
      analysis += 'What it is: Old encryption that can be cracked in minutes.\n';
      analysis += 'Risk: Hackers can break in and see your traffic.\n\n';
      
      analysis += '2. Packet Sniffing Risk\n';
      analysis += 'What it is: Attackers can capture and read your data packets.\n';
      analysis += 'Risk: Passwords and sensitive info can be stolen.\n\n';
      
      analysis += 'HOW TO PROTECT:\n';
      analysis += '• Use a VPN if you must connect\n';
      analysis += '• Avoid banking or shopping\n';
      analysis += '• Don\'t enter passwords\n';
      analysis += '• Use HTTPS websites only\n\n';
      
      analysis += 'RECOMMENDATION: ⚠️ USE WITH CAUTION - Only for basic browsing with VPN.';
    } else if (risk == 'Secure') {
      analysis += '🟢 SECURE: Modern Encryption\n\n';
      analysis += 'SECURITY FEATURES:\n\n';
      
      analysis += '1. Strong Encryption (WPA2/WPA3)\n';
      analysis += 'What it is: Modern security that\'s hard to crack.\n';
      analysis += 'Protection: Your data is encrypted and safe from eavesdropping.\n\n';
      
      analysis += '2. Authentication Required\n';
      analysis += 'What it is: Password needed to connect.\n';
      analysis += 'Protection: Prevents unauthorized access.\n\n';
      
      analysis += 'STILL BE CAREFUL:\n';
      analysis += '• Verify you\'re connecting to the real network (not Evil Twin)\n';
      analysis += '• Check the network name matches exactly\n';
      analysis += '• Use HTTPS websites when possible\n';
      analysis += '• Keep device security updated\n\n';
      
      analysis += 'RECOMMENDATION: ✅ SAFE TO USE - Good for most activities. Signal: $signal.';
    } else {
      analysis += '⚪ UNKNOWN: Cannot Determine Security\n\n';
      analysis += 'POTENTIAL RISKS:\n';
      analysis += '• Security type unclear\n';
      analysis += '• Could be misconfigured\n';
      analysis += '• May have hidden vulnerabilities\n\n';
      
      analysis += 'HOW TO PROTECT:\n';
      analysis += '• Verify network details before connecting\n';
      analysis += '• Ask network owner about security\n';
      analysis += '• Use VPN if you connect\n\n';
      
      analysis += 'RECOMMENDATION: ⚠️ PROCEED WITH CAUTION - Verify security first.';
    }
    
    return analysis;
  }

  String _getSignalQuality(int rssi) {
    if (rssi >= -50) return 'Excellent';
    if (rssi >= -60) return 'Good';
    if (rssi >= -70) return 'Fair';
    return 'Weak';
  }

  String _parseSecurityType(String capabilities) {
    if (capabilities.isEmpty || capabilities.trim().isEmpty) {
      return 'Open';
    }
    
    final caps = capabilities.toUpperCase();
    
    // Check for specific security protocols (order matters - check strongest first)
    if (caps.contains('WPA3')) return 'WPA3';
    if (caps.contains('WPA2')) return 'WPA2';
    if (caps.contains('WPA')) return 'WPA';
    if (caps.contains('WEP')) return 'WEP';
    
    // If only ESS, WPS, or other non-security capabilities are present, it's Open
    // ESS = Extended Service Set (infrastructure mode indicator)
    // WPS = Wi-Fi Protected Setup (convenience feature)
    // These are NOT security types
    if (caps.contains('ESS') || caps.contains('WPS')) {
      // Check if there are any actual security indicators
      final hasSecurityProtocol = caps.contains('WPA') || 
                                  caps.contains('WEP') || 
                                  caps.contains('PSK') || 
                                  caps.contains('EAP');
      if (!hasSecurityProtocol) {
        return 'Open';
      }
    }
    
    // If capabilities string is Unknown or unrecognized, treat as Open for safety
    if (caps == 'UNKNOWN' || caps == 'NONE') {
      return 'Open';
    }
    
    return 'Unknown';
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
