import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'dart:ui'; // Add this import for ImageFilter
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'screens/add_device_screen.dart';
import 'screens/live_scan_screen.dart';

// Global theme state
ThemeMode currentThemeMode = ThemeMode.system;
String currentThemeName = 'System Default';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final greeted = prefs.getBool('greeted') ?? false;
  final permissionsGranted = prefs.getBool('permissionsGranted') ?? false;
  final username = prefs.getString('username') ?? '';
  currentThemeName = prefs.getString('theme') ?? 'Dark Theme';

  switch (currentThemeName) {
    case 'Light Theme':
      currentThemeMode = ThemeMode.light;
      break;
    case 'Dark Theme':
      currentThemeMode = ThemeMode.dark;
      break;
    case 'System Default':
    default:
      currentThemeMode = ThemeMode.system;
      break;
  }

  runApp(
    MyApp(
      greeted: greeted,
      permissionsGranted: permissionsGranted,
      username: username,
    ),
  );
}

class MyApp extends StatefulWidget {
  final bool greeted;
  final bool permissionsGranted;
  final String username;

  const MyApp({
    super.key,
    required this.greeted,
    required this.permissionsGranted,
    required this.username,
  });

  @override
  State<MyApp> createState() => _MyAppState();

  static _MyAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<_MyAppState>();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = currentThemeMode;

  void changeTheme(ThemeMode themeMode, String themeName) async {
    setState(() {
      _themeMode = themeMode;
    });
    currentThemeMode = themeMode;
    currentThemeName = themeName;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme', themeName);
  }

  final _lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: Colors.blue,
    scaffoldBackgroundColor: Colors.white,
    fontFamily: 'Barlow',
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.black),
      bodyMedium: TextStyle(color: Colors.black),
    ),
    cupertinoOverrideTheme: const CupertinoThemeData(
      brightness: Brightness.light,
      primaryColor: CupertinoColors.activeBlue,
      scaffoldBackgroundColor: CupertinoColors.white,
      textTheme: CupertinoTextThemeData(
        textStyle: TextStyle(
          color: CupertinoColors.black,
          fontSize: 17,
          fontFamily: 'Barlow',
        ),
      ),
    ),
  );

  final _darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: Colors.blue,
    scaffoldBackgroundColor: Colors.black,
    fontFamily: 'Barlow',
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.white),
      bodyMedium: TextStyle(color: Colors.white),
    ),
    cupertinoOverrideTheme: const CupertinoThemeData(
      brightness: Brightness.dark,
      primaryColor: CupertinoColors.activeBlue,
      scaffoldBackgroundColor: CupertinoColors.black,
      textTheme: CupertinoTextThemeData(
        textStyle: TextStyle(
          color: CupertinoColors.white,
          fontSize: 17,
          fontFamily: 'Barlow',
        ),
      ),
    ),
  );

  Widget _getHome() {
    if (!widget.greeted) {
      return const SplashScreen();
    }
    if (!widget.permissionsGranted) {
      return PermissionsScreen(name: widget.username);
    }
    return const DashboardScreen();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZYNC',
      theme: _lightTheme,
      darkTheme: _darkTheme,
      themeMode: _themeMode,
      home: _getHome(),
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        DefaultMaterialLocalizations.delegate,
        DefaultCupertinoLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''), // English
      ],
      locale: const Locale('en', ''),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _controller.forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 500), () {
          _controller.reverse();
        });
      } else if (status == AnimationStatus.dismissed) {
        Navigator.of(context).pushReplacement(
          CupertinoPageRoute(builder: (_) => const GreetingScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      child: Material(
        type: MaterialType.transparency,
        child: Center(
          child: FadeTransition(
            opacity: _animation,
            child: const Text(
              'ZYNC',
              style: TextStyle(
                color: CupertinoColors.white,
                fontSize: 48,
                fontWeight: FontWeight.bold,
                letterSpacing: 8,
                fontFamily: 'Barlow',
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GreetingScreen extends StatefulWidget {
  const GreetingScreen({super.key});

  @override
  State<GreetingScreen> createState() => _GreetingScreenState();
}

class _GreetingScreenState extends State<GreetingScreen> {
  final TextEditingController _controller = TextEditingController();
  String? _greetedName;
  bool _acceptedTerms = false;
  bool _loading = false;

  void _submit() async {
    final name = _controller.text.trim();
    if (name.isNotEmpty && _acceptedTerms) {
      setState(() {
        _loading = true;
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('greeted', true);
      await prefs.setString('username', name);
      setState(() {
        _greetedName = name;
        _loading = false;
      });
      Navigator.of(context).pushReplacement(
        CupertinoPageRoute(builder: (_) => WelcomeScreen(name: name)),
      );
    }
  }

  bool get _canContinue =>
      _controller.text.trim().isNotEmpty && _acceptedTerms && !_loading;

  void _openTerms() {
    // Show a Cupertino dialog or push a new page with terms
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Terms and Conditions'),
        content: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Text(
              '''Last updated: June 2025

Welcome to ZYNC — your personal portable WiFi security scanner.

By using the ZYNC mobile application and hardware device (collectively referred to as the "Service"), you agree to the following Terms and Conditions. Please read them carefully.

1. Acceptance of Terms
By accessing or using ZYNC, you confirm that you have read, understood, and agree to be bound by these Terms. If you do not agree, do not use the app or device.

2. Description of Service
ZYNC allows users to:
\u2022 Scan nearby WiFi networks using a portable device.
\u2022 Display details such as SSID, encryption type, and potential risks.
\u2022 Connect the device to the mobile app via Bluetooth to view live scan data.
\u2022 Store and view scan logs through the mobile app.

The app and device are intended to inform and assist users in identifying potentially insecure WiFi connections. It does not interfere, tamper with, or access any network content.

3. User Responsibility
You agree to use ZYNC only for lawful purposes. You shall not:
\u2022 Attempt unauthorized access to networks.
\u2022 Use the device/app for hacking, eavesdropping, or packet sniffing.
\u2022 Share inaccurate or misleading scan data.

ZYNC is a passive scanner — it does not connect to any network without user consent.

4. Data Collection and Privacy
ZYNC may collect:
\u2022 Scan metadata (SSID, signal strength, encryption type).
\u2022 Device information (non-personally identifiable).
\u2022 App usage statistics (for performance improvements).

All data remains local to the user's device unless manually exported. ZYNC does not share your data with third parties.

5. No Warranty
ZYNC is provided on an "as-is" basis. We do not guarantee:
\u2022 The accuracy or completeness of scan results.
\u2022 That all security threats will be detected.
\u2022 Uninterrupted or error-free operation.

You are solely responsible for how you act based on scan data.

6. Limitation of Liability
In no event shall ZYNC, its developers, or affiliates be liable for:
\u2022 Any damage caused by reliance on scan results.
\u2022 Loss of data, network issues, or unauthorized access.
\u2022 Any indirect or consequential losses.

7. Modifications to Terms
We reserve the right to update these Terms at any time. Continued use of the app or device after changes means you accept the updated terms.''',
              textAlign: TextAlign.left,
              style: TextStyle(
                color: CupertinoTheme.of(context).textTheme.textStyle.color,
                fontSize: 14,
              ),
            ),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Close'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          child: Stack(
            children: [
              // ZYNC at the top
              const Positioned(
                top: 32,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    'ZYNC',
                    style: TextStyle(
                      color: CupertinoColors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 8,
                      fontFamily: 'Barlow',
                    ),
                  ),
                ),
              ),
              // Main content
              Center(
                child: _greetedName == null
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 80),
                          const Text(
                            'What should we call you?',
                            style: TextStyle(
                              color: CupertinoColors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'Barlow',
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: 250,
                            child: CupertinoTextField(
                              controller: _controller,
                              placeholder: 'Enter your name',
                              style: const TextStyle(
                                color: CupertinoColors.white,
                                fontFamily: 'Barlow',
                              ),
                              placeholderStyle: const TextStyle(
                                color: CupertinoColors.systemGrey,
                                fontFamily: 'Barlow',
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                color: CupertinoColors.darkBackgroundGray,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              onChanged: (_) => setState(() {}),
                              onSubmitted: (_) => _submit(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          CupertinoButton.filled(
                            onPressed: _canContinue ? _submit : null,
                            child: _loading
                                ? const CupertinoActivityIndicator()
                                : const Text(
                                    'Continue',
                                    style: TextStyle(fontFamily: 'Barlow'),
                                  ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 80),
                          Text(
                            'Hello, $_greetedName!',
                            style: const TextStyle(
                              color: CupertinoColors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Barlow',
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Welcome to ZYNC.',
                            style: TextStyle(
                              color: CupertinoColors.systemGrey,
                              fontSize: 18,
                              fontFamily: 'Barlow',
                            ),
                          ),
                        ],
                      ),
              ),
              // Accept Terms and Conditions at the bottom
              if (_greetedName == null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 32,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CupertinoSwitch(
                        value: _acceptedTerms,
                        onChanged: (val) {
                          setState(() {
                            _acceptedTerms = val;
                          });
                        },
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: GestureDetector(
                          onTap: _openTerms,
                          child: const Text(
                            'Accept Terms and Conditions',
                            style: TextStyle(
                              color: CupertinoColors.activeBlue,
                              fontSize: 16,
                              fontFamily: 'Barlow',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      child: Material(
        type: MaterialType.transparency,
        child: Center(
          child: Text(
            'Welcome to ZYNC!',
            style: TextStyle(
              color: CupertinoColors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              fontFamily: 'Barlow',
            ),
          ),
        ),
      ),
    );
  }
}

class WelcomeScreen extends StatefulWidget {
  final String name;
  const WelcomeScreen({super.key, required this.name});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 1), () {
      Navigator.of(context).pushReplacement(
        CupertinoPageRoute(
          builder: (_) => PermissionsScreen(name: widget.name),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      child: Material(
        type: MaterialType.transparency,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Hello ${widget.name}',
                style: const TextStyle(
                  color: CupertinoColors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Barlow',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Welcome to ZYNC.',
                style: TextStyle(
                  color: CupertinoColors.systemGrey,
                  fontSize: 18,
                  fontFamily: 'Barlow',
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PermissionsScreen extends StatefulWidget {
  final String name;
  const PermissionsScreen({super.key, required this.name});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  bool _wifi = false;
  bool _location = false;
  bool _storage = false;
  bool _internet = false;
  bool _notifications = false;

  void _showToast(BuildContext context, String message) {
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 100.0,
        left: 24.0,
        right: 24.0,
        child: SafeArea(
          child: Material(
            color: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(25.0),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 16.0,
                  ),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey6.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(25.0),
                    border: Border.all(
                      color: CupertinoColors.systemGrey5.withOpacity(0.5),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        CupertinoIcons.arrow_left_circle,
                        color: CupertinoTheme.of(context).primaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          message,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: CupertinoTheme.of(
                              context,
                            ).textTheme.textStyle.color,
                            fontSize: 16.0,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Barlow',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);

    // Add a fade-in animation
    overlayEntry.markNeedsBuild();

    // Remove after delay with fade-out
    Future.delayed(const Duration(seconds: 2), () {
      overlayEntry.remove();
    });
  }

  @override
  void initState() {
    super.initState();
    _checkCurrentPermissions();
  }

  Future<void> _checkCurrentPermissions() async {
    // Check WiFi permissions
    final wifiScan = await Permission.nearbyWifiDevices.status;
    final wifiState = await Permission.locationWhenInUse.status;
    final wifi = wifiScan.isGranted && wifiState.isGranted;

    // Check Location permission
    final location = await Permission.location.status;

    // Check Storage permission
    bool storage = false;
    if (Platform.isAndroid && (await _getAndroidSdkInt()) >= 33) {
      // On Android 13+, no permission needed for app-private storage
      storage = true;
    } else {
      final storageStatus = await Permission.storage.status;
      storage = storageStatus.isGranted;
    }

    // Check Notification permission
    final notifications = await Permission.notification.status;

    // Internet permission is always granted on Android and iOS
    const internet = true;

    if (mounted) {
      setState(() {
        _wifi = wifi;
        _location = location.isGranted;
        _storage = storage;
        _internet = internet;
        _notifications = notifications.isGranted;
      });
    }
  }

  Future<void> _onWifiChanged(bool? value) async {
    if (value == true) {
      final wifiScanStatus = await Permission.nearbyWifiDevices.request();
      final locationStatus = await Permission.locationWhenInUse.request();
      if (mounted) {
        final granted = wifiScanStatus.isGranted && locationStatus.isGranted;
        setState(() => _wifi = granted);
        if (!granted) {
          _showToast(
            context,
            'WiFi and Location permissions are required. Please enable them in Settings.',
          );
        }
      }
    } else {
      if (mounted) {
        setState(() => _wifi = false);
      }
    }
  }

  Future<void> _onLocationChanged(bool? value) async {
    if (value == true) {
      final status = await Permission.location.request();
      if (mounted) {
        setState(() => _location = status.isGranted);
        if (!status.isGranted) {
          _showToast(
            context,
            'Location permission is required. Please enable it in Settings.',
          );
        }
      }
    } else {
      if (mounted) {
        setState(() => _location = false);
      }
    }
  }

  Future<void> _onStorageChanged(bool? value) async {
    if (value == true) {
      if (Platform.isAndroid && (await _getAndroidSdkInt()) >= 33) {
        // On Android 13+, no permission needed for app-private storage
        if (mounted) {
          setState(() => _storage = true);
        }
      } else {
        final status = await Permission.storage.request();
        if (mounted) {
          setState(() => _storage = status.isGranted);
          if (!status.isGranted) {
            _showToast(
              context,
              'Storage permission is required. Please enable it in Settings.',
            );
          }
        }
      }
    } else {
      if (mounted) {
        setState(() => _storage = false);
      }
    }
  }

  Future<int> _getAndroidSdkInt() async {
    if (Platform.isAndroid) {
      final storageStatus = await Permission.storage.status;
      // This is a simplified way to check. In a production app, you'd want to use
      // package_info_plus or platform channels to get the actual SDK version
      return storageStatus.isGranted ? 32 : 33;
    }
    return 33; // Default to latest for non-Android platforms
  }

  Future<void> _onNotificationChanged(bool? value) async {
    if (value == true) {
      final status = await Permission.notification.request();
      if (mounted) {
        setState(() => _notifications = status.isGranted);
        if (!status.isGranted) {
          _showToast(
            context,
            'Notification permission is required. Please enable it in Settings.',
          );
        }
      }
    } else {
      if (mounted) {
        setState(() => _notifications = false);
      }
    }
  }

  Future<void> _openAppSettings() async {
    await openAppSettings();
  }

  @override
  Widget build(BuildContext context) {
    final allEnabled =
        _wifi && _location && _storage && _internet && _notifications;

    return Material(
      child: CupertinoPageScaffold(
        backgroundColor: CupertinoColors.black,
        navigationBar: CupertinoNavigationBar(
          backgroundColor: CupertinoColors.black,
          border: null,
          middle: const Text(
            'Permissions Required',
            style: TextStyle(
              color: CupertinoColors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 4,
              fontFamily: 'Barlow',
            ),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                PermissionCheckboxTile(
                  title: 'WiFi',
                  explanation: 'Required for scanning nearby WiFi networks.',
                  value: _wifi,
                  onChanged: _onWifiChanged,
                ),
                PermissionCheckboxTile(
                  title: 'Location',
                  explanation:
                      'On older Android versions, Bluetooth scans require location access.',
                  value: _location,
                  onChanged: _onLocationChanged,
                ),
                PermissionCheckboxTile(
                  title: 'Storage',
                  explanation: 'For saving logs onto your phone.',
                  value: _storage,
                  onChanged: _onStorageChanged,
                ),
                PermissionCheckboxTile(
                  title: 'Internet',
                  explanation: 'For getting AI results.',
                  value: _internet,
                  onChanged:
                      (
                        _,
                      ) {}, // Internet permission is always granted, but we need a no-op function
                ),
                PermissionCheckboxTile(
                  title: 'Notifications',
                  explanation: 'To send important alerts to you.',
                  value: _notifications,
                  onChanged: _onNotificationChanged,
                ),
                const Spacer(),
                if (!allEnabled) ...[
                  Center(
                    child: CupertinoButton(
                      onPressed: _openAppSettings,
                      child: const Text(
                        'Open Settings',
                        style: TextStyle(
                          color: CupertinoColors.activeBlue,
                          fontFamily: 'Barlow',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton.filled(
                    onPressed: allEnabled
                        ? () async {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool('permissionsGranted', true);
                            if (mounted) {
                              Navigator.of(context).pushReplacement(
                                CupertinoPageRoute(
                                  builder: (_) => const DashboardScreen(),
                                ),
                              );
                            }
                          }
                        : null,
                    child: const Text(
                      'Continue',
                      style: TextStyle(fontFamily: 'Barlow'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PermissionCheckboxTile extends StatelessWidget {
  final String title;
  final String explanation;
  final bool value;
  final ValueChanged<bool?> onChanged;

  const PermissionCheckboxTile({
    super.key,
    required this.title,
    required this.explanation,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                  color: CupertinoColors.activeBlue,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Barlow',
                ),
              ),
              CupertinoSwitch(value: value, onChanged: onChanged),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            explanation,
            textDirection: TextDirection.ltr,
            style: const TextStyle(
              color: CupertinoColors.systemGrey,
              fontSize: 16,
              fontFamily: 'Barlow',
            ),
          ),
        ],
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _isHovering = false;
  DateTime? _lastBackPressTime;

  void _showToast(BuildContext context, String message) {
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 100.0,
        left: 24.0,
        right: 24.0,
        child: SafeArea(
          child: Material(
            color: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(25.0),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 16.0,
                  ),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey6.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(25.0),
                    border: Border.all(
                      color: CupertinoColors.systemGrey5.withOpacity(0.5),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        CupertinoIcons.arrow_left_circle,
                        color: CupertinoTheme.of(context).primaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          message,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: CupertinoTheme.of(
                              context,
                            ).textTheme.textStyle.color,
                            fontSize: 16.0,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Barlow',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);

    // Add a fade-in animation
    overlayEntry.markNeedsBuild();

    // Remove after delay with fade-out
    Future.delayed(const Duration(seconds: 2), () {
      overlayEntry.remove();
    });
  }

  Future<bool> _onWillPop() async {
    final now = DateTime.now();
    if (_lastBackPressTime == null ||
        now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
      _lastBackPressTime = now;
      _showToast(context, 'Swipe back again to exit');
      return false;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Widget _buildAnimatedAddIcon(Color color) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Icon(CupertinoIcons.add, color: color, size: 32);
      },
    );
  }

  Widget _buildAnimatedScanIcon(Color color) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Icon(CupertinoIcons.wifi, color: color.withOpacity(0.3), size: 32),
            Icon(CupertinoIcons.wifi, color: color.withOpacity(0.6), size: 32),
            Icon(CupertinoIcons.wifi, color: color, size: 32),
          ],
        );
      },
    );
  }

  Widget _buildAnimatedLogsIcon(Color color) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Icon(CupertinoIcons.doc_text, color: color, size: 32);
      },
    );
  }

  Widget _buildAnimatedExportIcon(Color color) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final value = sin(_animationController.value * pi);
        return Transform.translate(
          offset: Offset(0, value * 2),
          child: Icon(CupertinoIcons.arrow_up_doc, color: color, size: 32),
        );
      },
    );
  }

  Widget _buildAnimatedAIIcon(Color color) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final value = sin(_animationController.value * 2 * pi);
        return Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              CupertinoIcons.sparkles,
              color: color.withOpacity(0.3 + (value + 1) * 0.2),
              size: 32,
            ),
            Icon(CupertinoIcons.sparkles, color: color, size: 32),
          ],
        );
      },
    );
  }

  void _showThemeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.light_mode),
              title: const Text('Light Theme'),
              onTap: () {
                Navigator.of(context).pop();
                _applyTheme(ThemeMode.light, 'Light Theme');
              },
            ),
            ListTile(
              leading: const Icon(Icons.dark_mode),
              title: const Text('Dark Theme'),
              onTap: () {
                Navigator.of(context).pop();
                _applyTheme(ThemeMode.dark, 'Dark Theme');
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_system_daydream),
              title: const Text('System Default'),
              onTap: () {
                Navigator.of(context).pop();
                _applyTheme(ThemeMode.system, 'System Default');
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _openTerms() {
    // Show a Cupertino dialog or push a new page with terms
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Terms and Conditions'),
        content: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Text(
              '''Last updated: June 2025

Welcome to ZYNC — your personal portable WiFi security scanner.

By using the ZYNC mobile application and hardware device (collectively referred to as the "Service"), you agree to the following Terms and Conditions. Please read them carefully.

1. Acceptance of Terms
By accessing or using ZYNC, you confirm that you have read, understood, and agree to be bound by these Terms. If you do not agree, do not use the app or device.

2. Description of Service
ZYNC allows users to:
\u2022 Scan nearby WiFi networks using a portable device.
\u2022 Display details such as SSID, encryption type, and potential risks.
\u2022 Connect the device to the mobile app via Bluetooth to view live scan data.
\u2022 Store and view scan logs through the mobile app.

The app and device are intended to inform and assist users in identifying potentially insecure WiFi connections. It does not interfere, tamper with, or access any network content.

3. User Responsibility
You agree to use ZYNC only for lawful purposes. You shall not:
\u2022 Attempt unauthorized access to networks.
\u2022 Use the device/app for hacking, eavesdropping, or packet sniffing.
\u2022 Share inaccurate or misleading scan data.

ZYNC is a passive scanner — it does not connect to any network without user consent.

4. Data Collection and Privacy
ZYNC may collect:
\u2022 Scan metadata (SSID, signal strength, encryption type).
\u2022 Device information (non-personally identifiable).
\u2022 App usage statistics (for performance improvements).

All data remains local to the user's device unless manually exported. ZYNC does not share your data with third parties.

5. No Warranty
ZYNC is provided on an "as-is" basis. We do not guarantee:
\u2022 The accuracy or completeness of scan results.
\u2022 That all security threats will be detected.
\u2022 Uninterrupted or error-free operation.

You are solely responsible for how you act based on scan data.

6. Limitation of Liability
In no event shall ZYNC, its developers, or affiliates be liable for:
\u2022 Any damage caused by reliance on scan results.
\u2022 Loss of data, network issues, or unauthorized access.
\u2022 Any indirect or consequential losses.

7. Modifications to Terms
We reserve the right to update these Terms at any time. Continued use of the app or device after changes means you accept the updated terms.''',
              textAlign: TextAlign.left,
              style: TextStyle(
                color: CupertinoTheme.of(context).textTheme.textStyle.color,
                fontSize: 14,
              ),
            ),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Close'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  void _applyTheme(ThemeMode themeMode, String themeName) {
    MyApp.of(context)?.changeTheme(themeMode, themeName);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor =
        theme.textTheme.bodyLarge?.color ??
        (theme.brightness == Brightness.dark ? Colors.white : Colors.black);

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Material(
        child: Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: CupertinoNavigationBar(
            backgroundColor: theme.scaffoldBackgroundColor,
            border: null,
            leading: Builder(
              builder: (context) => CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => Scaffold.of(context).openDrawer(),
                child: Icon(CupertinoIcons.bars, color: textColor),
              ),
            ),
            middle: Text(
              'ZYNC',
              style: TextStyle(
                color: textColor,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 8,
                fontFamily: 'Barlow',
              ),
            ),
          ),
          drawer: Drawer(
            child: Container(
              color: theme.canvasColor,
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  DrawerHeader(
                    decoration: BoxDecoration(
                      color: theme.scaffoldBackgroundColor,
                    ),
                    child: Text(
                      'ZYNC',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 8,
                        fontFamily: 'Barlow',
                      ),
                    ),
                  ),
                  ListTile(
                    leading: Icon(CupertinoIcons.home, color: textColor),
                    title: Text(
                      'Home',
                      style: TextStyle(color: textColor, fontFamily: 'Barlow'),
                    ),
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  ListTile(
                    leading: Icon(CupertinoIcons.add, color: textColor),
                    title: Text(
                      'Add a device',
                      style: TextStyle(color: textColor, fontFamily: 'Barlow'),
                    ),
                    onTap: () {
                      Navigator.of(context).pop(); // Close drawer
                      Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (context) => const AddDeviceScreen(),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: Icon(CupertinoIcons.wifi, color: textColor),
                    title: Text(
                      'Live Scan',
                      style: TextStyle(color: textColor, fontFamily: 'Barlow'),
                    ),
                    onTap: () {
                      Navigator.of(context).pop(); // Close drawer
                      Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (context) => const LiveScanScreen(),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: Icon(CupertinoIcons.sparkles, color: textColor),
                    title: Text(
                      'AI Overview',
                      style: TextStyle(color: textColor, fontFamily: 'Barlow'),
                    ),
                    onTap: () {
                      Navigator.of(context).pop(); // Close drawer
                      // TODO: Navigate to AI Overview screen
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('AI Overview'),
                          content: const Text(
                            'AI-powered network analysis using Gemini API will be implemented here.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: Icon(CupertinoIcons.doc_text, color: textColor),
                    title: Text(
                      'Scan Logs',
                      style: TextStyle(color: textColor, fontFamily: 'Barlow'),
                    ),
                    onTap: () {
                      Navigator.of(context).pop(); // Close drawer
                      // TODO: Replace with actual Scan Logs screen when available
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Scan Logs'),
                          content: const Text(
                            'Scan Logs functionality will be implemented here.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      CupertinoIcons.device_laptop,
                      color: textColor,
                    ),
                    title: Text(
                      'Theme',
                      style: TextStyle(color: textColor, fontFamily: 'Barlow'),
                    ),
                    onTap: () => _showThemeDialog(),
                  ),
                  ListTile(
                    leading: Icon(CupertinoIcons.settings, color: textColor),
                    title: Text(
                      'Settings',
                      style: TextStyle(color: textColor, fontFamily: 'Barlow'),
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        CupertinoPageRoute(
                          builder: (_) => const SettingsScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildDashboardButton(
                            context,
                            onTap: () {
                              Navigator.push(
                                context,
                                CupertinoPageRoute(
                                  builder: (context) => const AddDeviceScreen(),
                                ),
                              );
                            },
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildAnimatedAddIcon(textColor),
                                const SizedBox(height: 16),
                                Text(
                                  'Add Device',
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Barlow',
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Connect a new ZYNC device',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: theme.textTheme.bodySmall?.color,
                                    fontSize: 14,
                                    fontFamily: 'Barlow',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: _buildDashboardButton(
                            context,
                            onTap: () {
                              Navigator.push(
                                context,
                                CupertinoPageRoute(
                                  builder: (context) => const LiveScanScreen(),
                                ),
                              );
                            },
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildAnimatedScanIcon(textColor),
                                const SizedBox(height: 16),
                                Text(
                                  'Live Scan',
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Barlow',
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Start a new network scan',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: theme.textTheme.bodySmall?.color,
                                    fontSize: 14,
                                    fontFamily: 'Barlow',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildDashboardButton(
                            context,
                            onTap: () {
                              // TODO: Navigate to Scan Logs screen
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Scan Logs'),
                                  content: const Text(
                                    'Scan Logs functionality will be implemented here.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(),
                                      child: const Text('OK'),
                                    ),
                                  ],
                                ),
                              );
                            },
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildAnimatedLogsIcon(textColor),
                                const SizedBox(height: 16),
                                Text(
                                  'Scan Logs',
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Barlow',
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'View scan history and reports',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: theme.textTheme.bodySmall?.color,
                                    fontSize: 14,
                                    fontFamily: 'Barlow',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: _buildDashboardButton(
                            context,
                            onTap: () {
                              // TODO: Navigate to AI Overview screen
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('AI Overview'),
                                  content: const Text(
                                    'AI-powered network analysis using Gemini API will be implemented here.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(),
                                      child: const Text('OK'),
                                    ),
                                  ],
                                ),
                              );
                            },
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildAnimatedAIIcon(textColor),
                                const SizedBox(height: 16),
                                Text(
                                  'AI Overview',
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Barlow',
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Gemini-powered network analysis',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: theme.textTheme.bodySmall?.color,
                                    fontSize: 14,
                                    fontFamily: 'Barlow',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: _buildDashboardButton(
                      context,
                      onTap: () {
                        // TODO: Implement export logs functionality
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Export Logs'),
                            content: const Text(
                              'Export logs functionality will be implemented here.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('OK'),
                              ),
                            ],
                          ),
                        );
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildAnimatedExportIcon(textColor),
                          const SizedBox(height: 16),
                          Text(
                            'Export Logs',
                            style: TextStyle(
                              color: textColor,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Barlow',
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Export scan logs to CSV or PDF',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: theme.textTheme.bodySmall?.color,
                              fontSize: 14,
                              fontFamily: 'Barlow',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardButton(
    BuildContext context, {
    required VoidCallback onTap,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24.0),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(color: theme.dividerColor, width: 1),
        ),
        child: child,
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor =
        theme.textTheme.bodyLarge?.color ??
        (theme.brightness == Brightness.dark ? Colors.white : Colors.black);

    return CupertinoPageScaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        border: null,
        middle: Text(
          'SETTINGS',
          style: TextStyle(
            color: textColor,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 4,
            fontFamily: 'Barlow',
          ),
        ),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            _buildSettingsTile(
              context,
              icon: CupertinoIcons.person,
              title: 'Edit Name',
              onTap: () async {
                final prefs = await SharedPreferences.getInstance();
                final currentName = prefs.getString('username') ?? '';
                if (context.mounted) {
                  Navigator.of(context).push(
                    CupertinoPageRoute(
                      builder: (_) => EditNameScreen(currentName: currentName),
                    ),
                  );
                }
              },
            ),
            _buildSettingsTile(
              context,
              icon: CupertinoIcons.bluetooth,
              title: 'Connect / Disconnect Device',
              onTap: () {
                Navigator.of(context).push(
                  CupertinoPageRoute(builder: (_) => const DevicesScreen()),
                );
              },
            ),
            _buildSettingsTile(
              context,
              icon: CupertinoIcons.doc_text,
              title: 'Terms and Conditions',
              onTap: () {
                _openTerms(context);
              },
            ),
            _buildSettingsTile(
              context,
              icon: CupertinoIcons.info,
              title: 'About Us',
              onTap: () {
                Navigator.of(context).push(
                  CupertinoPageRoute(builder: (_) => const AboutUsScreen()),
                );
              },
            ),
            _buildSettingsTile(
              context,
              icon: CupertinoIcons.shield,
              title: 'Permissions',
              onTap: () {
                Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (_) => const PermissionsScreen(name: ''),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final textColor =
        theme.textTheme.bodyLarge?.color ??
        (theme.brightness == Brightness.dark ? Colors.white : Colors.black);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: textColor),
              const SizedBox(width: 16),
              Text(
                title,
                style: TextStyle(
                  color: textColor,
                  fontSize: 18,
                  fontFamily: 'Barlow',
                ),
              ),
              const Spacer(),
              Icon(
                CupertinoIcons.chevron_right,
                color: textColor.withOpacity(0.5),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openTerms(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: Material(
              color: Colors.transparent,
              child: Container(
                color: CupertinoTheme.of(
                  context,
                ).scaffoldBackgroundColor.withOpacity(0.95),
                child: SafeArea(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: CupertinoTheme.of(
                            context,
                          ).scaffoldBackgroundColor,
                          border: Border(
                            bottom: BorderSide(
                              color: CupertinoTheme.of(
                                context,
                              ).textTheme.textStyle.color!.withOpacity(0.1),
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Terms and Conditions',
                              style: TextStyle(
                                color: CupertinoTheme.of(
                                  context,
                                ).textTheme.textStyle.color,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Barlow',
                              ),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.of(context).pop(),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: CupertinoTheme.of(
                                    context,
                                  ).textTheme.textStyle.color!.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Icon(
                                  CupertinoIcons.xmark,
                                  color: CupertinoTheme.of(
                                    context,
                                  ).textTheme.textStyle.color,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24.0,
                              vertical: 20.0,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildTermsSection(
                                  context,
                                  'Last updated: June 2025',
                                  'Welcome to ZYNC — your personal portable WiFi security scanner.',
                                  isHeader: true,
                                ),
                                _buildTermsSection(
                                  context,
                                  '1. Acceptance of Terms',
                                  'By accessing or using ZYNC, you confirm that you have read, understood, and agree to be bound by these Terms. If you do not agree, do not use the app or device.',
                                ),
                                _buildTermsSection(
                                  context,
                                  '2. Description of Service',
                                  '''ZYNC allows users to:
• Scan nearby WiFi networks using a portable device.
• Display details such as SSID, encryption type, and potential risks.
• Connect the device to the mobile app via Bluetooth to view live scan data.
• Store and view scan logs through the mobile app.

The app and device are intended to inform and assist users in identifying potentially insecure WiFi connections. It does not interfere, tamper with, or access any network content.''',
                                ),
                                _buildTermsSection(
                                  context,
                                  '3. User Responsibility',
                                  '''You agree to use ZYNC only for lawful purposes. You shall not:
• Attempt unauthorized access to networks.
• Use the device/app for hacking, eavesdropping, or packet sniffing.
• Share inaccurate or misleading scan data.

ZYNC is a passive scanner — it does not connect to any network without user consent.''',
                                ),
                                _buildTermsSection(
                                  context,
                                  '4. Data Collection and Privacy',
                                  '''ZYNC may collect:
• Scan metadata (SSID, signal strength, encryption type).
• Device information (non-personally identifiable).
• App usage statistics (for performance improvements).

All data remains local to the user's device unless manually exported. ZYNC does not share your data with third parties.''',
                                ),
                                _buildTermsSection(
                                  context,
                                  '5. No Warranty',
                                  '''ZYNC is provided on an "as-is" basis. We do not guarantee:
• The accuracy or completeness of scan results.
• That all security threats will be detected.
• Uninterrupted or error-free operation.

You are solely responsible for how you act based on scan data.''',
                                ),
                                _buildTermsSection(
                                  context,
                                  '6. Limitation of Liability',
                                  '''In no event shall ZYNC, its developers, or affiliates be liable for:
• Any damage caused by reliance on scan results.
• Loss of data, network issues, or unauthorized access.
• Any indirect or consequential losses.''',
                                ),
                                _buildTermsSection(
                                  context,
                                  '7. Modifications to Terms',
                                  'We reserve the right to update these Terms at any time. Continued use of the app or device after changes means you accept the updated terms.',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: CupertinoTheme.of(
                            context,
                          ).scaffoldBackgroundColor,
                          border: Border(
                            top: BorderSide(
                              color: CupertinoTheme.of(
                                context,
                              ).textTheme.textStyle.color!.withOpacity(0.1),
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: CupertinoButton.filled(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text(
                                  'Close',
                                  style: TextStyle(fontFamily: 'Barlow'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutCubic;
          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);
          return SlideTransition(position: offsetAnimation, child: child);
        },
      ),
    );
  }

  Widget _buildTermsSection(
    BuildContext context,
    String title,
    String content, {
    bool isHeader = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isHeader) ...[
            Text(
              title,
              style: TextStyle(
                color: CupertinoTheme.of(context).textTheme.textStyle.color,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: 'Barlow',
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            content,
            style: TextStyle(
              color: CupertinoTheme.of(
                context,
              ).textTheme.textStyle.color?.withOpacity(isHeader ? 1.0 : 0.8),
              fontSize: isHeader ? 18 : 16,
              height: 1.5,
              fontFamily: 'Barlow',
              fontWeight: isHeader ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class EditNameScreen extends StatefulWidget {
  final String currentName;

  const EditNameScreen({super.key, required this.currentName});

  @override
  State<EditNameScreen> createState() => _EditNameScreenState();
}

class _EditNameScreenState extends State<EditNameScreen> {
  late TextEditingController _controller;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final name = _controller.text.trim();
    if (name.isNotEmpty) {
      setState(() => _loading = true);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('username', name);
      setState(() => _loading = false);
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor =
        theme.textTheme.bodyLarge?.color ??
        (theme.brightness == Brightness.dark ? Colors.white : Colors.black);

    return CupertinoPageScaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        border: null,
        middle: Text(
          'EDIT NAME',
          style: TextStyle(
            color: textColor,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 4,
            fontFamily: 'Barlow',
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CupertinoTextField(
                controller: _controller,
                placeholder: 'Enter your name',
                style: TextStyle(color: textColor),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  border: Border.all(color: theme.dividerColor),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 24),
              CupertinoButton.filled(
                onPressed: _loading ? null : _saveName,
                child: _loading
                    ? const CupertinoActivityIndicator()
                    : const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DevicesScreen extends StatelessWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor =
        theme.textTheme.bodyLarge?.color ??
        (theme.brightness == Brightness.dark ? Colors.white : Colors.black);

    return Material(
      child: CupertinoPageScaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        navigationBar: CupertinoNavigationBar(
          backgroundColor: theme.scaffoldBackgroundColor,
          border: null,
          middle: Text(
            'DEVICES',
            style: TextStyle(
              color: textColor,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 4,
              fontFamily: 'Barlow',
            ),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                Icon(
                  CupertinoIcons.bluetooth,
                  size: 48,
                  color: textColor.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'No devices found',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Barlow',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Make sure your ZYNC device is powered on and within range',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textColor.withOpacity(0.7),
                    fontSize: 16,
                    fontFamily: 'Barlow',
                  ),
                ),
                const SizedBox(height: 24),
                CupertinoButton.filled(
                  onPressed: () {
                    // TODO: Implement device scanning
                  },
                  child: const Text('Scan for Devices'),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  Widget _buildFeatureItem(BuildContext context, String text) {
    final theme = Theme.of(context);
    final textColor =
        theme.textTheme.bodyLarge?.color ??
        (theme.brightness == Brightness.dark ? Colors.white : Colors.black);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Text(
        text,
        style: TextStyle(
          color: textColor.withOpacity(0.7),
          fontSize: 16,
          height: 1.5,
          fontFamily: 'Barlow',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor =
        theme.textTheme.bodyLarge?.color ??
        (theme.brightness == Brightness.dark ? Colors.white : Colors.black);

    return Material(
      child: CupertinoPageScaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        navigationBar: CupertinoNavigationBar(
          backgroundColor: theme.scaffoldBackgroundColor,
          border: null,
          middle: Text(
            'ABOUT US',
            style: TextStyle(
              color: textColor,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 4,
              fontFamily: 'Barlow',
            ),
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ZYNC is your personal portable WiFi security scanner, designed to help you identify and assess the security of wireless networks around you. Our mission is to make network security accessible and understandable for everyone.',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    height: 1.5,
                    fontFamily: 'Barlow',
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Features:',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Barlow',
                  ),
                ),
                const SizedBox(height: 8),
                _buildFeatureItem(context, '• Real-time WiFi network scanning'),
                _buildFeatureItem(context, '• Detailed security analysis'),
                _buildFeatureItem(context, '• User-friendly interface'),
                _buildFeatureItem(context, '• Portable hardware device'),
                _buildFeatureItem(context, '• Comprehensive scan logs'),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
