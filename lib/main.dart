import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

// Global theme state
ThemeMode currentThemeMode = ThemeMode.system;
String currentThemeName = 'System Default';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final greeted = prefs.getBool('greeted') ?? false;
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

  runApp(MyApp(greeted: greeted));
}

class MyApp extends StatefulWidget {
  final bool greeted;
  const MyApp({super.key, required this.greeted});

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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZYNC',
      theme: _lightTheme,
      darkTheme: _darkTheme,
      themeMode: _themeMode,
      home: widget.greeted ? const DashboardScreen() : const SplashScreen(),
      debugShowCheckedModeBanner: false,
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
        content: const Text('Here are the terms and conditions...'),
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
  bool _bluetooth = false;
  bool _location = false;
  bool _storage = false;
  bool _internet = false;
  bool _notifications = false;

  Future<void> _onBluetoothChanged(bool? value) async {
    if (value == true) {
      final scanStatus = await Permission.bluetoothScan.request();
      final connectStatus = await Permission.bluetoothConnect.request();
      if (scanStatus.isGranted && connectStatus.isGranted) {
        setState(() => _bluetooth = true);
      } else {
        setState(() => _bluetooth = false);
      }
    } else {
      setState(() => _bluetooth = false);
    }
  }

  Future<void> _onLocationChanged(bool? value) async {
    if (value == true) {
      final status = await Permission.location.request();
      setState(() => _location = status.isGranted);
    } else {
      setState(() => _location = false);
    }
  }

  Future<void> _onStorageChanged(bool? value) async {
    if (value == true) {
      if (Platform.isAndroid && (await _getAndroidSdkInt()) >= 33) {
        // On Android 13+, no permission needed for app-private storage
        setState(() => _storage = true);
      } else {
        final status = await Permission.storage.request();
        setState(() => _storage = status.isGranted);
      }
    } else {
      setState(() => _storage = false);
    }
  }

  Future<int> _getAndroidSdkInt() async {
    // Use platform channel or package_info_plus for a robust solution, but for now:
    return (await Permission.storage.status).isGranted
        ? 32
        : 33; // fallback, always allow on 33+
  }

  Future<void> _onNotificationChanged(bool? value) async {
    if (value == true) {
      final status = await Permission.notification.request();
      setState(() => _notifications = status.isGranted);
    } else {
      setState(() => _notifications = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allEnabled =
        _bluetooth && _location && _storage && _internet && _notifications;
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Permissions Required',
                  style: TextStyle(
                    color: CupertinoColors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Barlow',
                  ),
                ),
                const SizedBox(height: 24),
                PermissionCheckboxTile(
                  title: 'Bluetooth',
                  explanation:
                      'Required for communicating with the WiFi scanner.',
                  value: _bluetooth,
                  onChanged: _onBluetoothChanged,
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
                  onChanged: (val) => setState(() => _internet = val ?? false),
                ),
                PermissionCheckboxTile(
                  title: 'Notifications',
                  explanation: 'To send important alerts to you.',
                  value: _notifications,
                  onChanged: _onNotificationChanged,
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton.filled(
                    onPressed: allEnabled
                        ? () {
                            Navigator.of(context).pushReplacement(
                              CupertinoPageRoute(
                                builder: (_) => const DashboardScreen(),
                              ),
                            );
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

class _DashboardScreenState extends State<DashboardScreen> {
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

  void _applyTheme(ThemeMode themeMode, String themeName) {
    MyApp.of(context)?.changeTheme(themeMode, themeName);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor =
        theme.textTheme.bodyLarge?.color ??
        (theme.brightness == Brightness.dark ? Colors.white : Colors.black);

    return Material(
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
                  onTap: () => Navigator.of(context).pop(),
                ),
                ListTile(
                  leading: Icon(CupertinoIcons.wifi, color: textColor),
                  title: Text(
                    'Live Scan',
                    style: TextStyle(color: textColor, fontFamily: 'Barlow'),
                  ),
                  onTap: () => Navigator.of(context).pop(),
                ),
                ListTile(
                  leading: Icon(CupertinoIcons.doc_text, color: textColor),
                  title: Text(
                    'Scan Logs',
                    style: TextStyle(color: textColor, fontFamily: 'Barlow'),
                  ),
                  onTap: () => Navigator.of(context).pop(),
                ),
                ListTile(
                  leading: Icon(CupertinoIcons.device_laptop, color: textColor),
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
                  onTap: () => Navigator.of(context).pop(),
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
                  child: _buildDashboardButton(
                    context,
                    onTap: () {
                      // TODO: Navigate to Add Device screen
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Add Device'),
                          content: const Text(
                            'Add Device functionality will be implemented here.',
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
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(CupertinoIcons.add, color: textColor),
                        const SizedBox(width: 12),
                        Text(
                          'Add Device',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 20,
                            fontFamily: 'Barlow',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: _buildDashboardButton(
                    context,
                    onTap: () {
                      // TODO: Navigate to Live Scan screen
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Live Scan'),
                          content: const Text(
                            'Live Scan functionality will be implemented here.',
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
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Text(
                            'Initiates a Bluetooth command to ESP32 to begin scanning nearby networks',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: theme.textTheme.bodySmall?.color,
                              fontSize: 14,
                              fontFamily: 'Barlow',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
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
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Text(
                            'View Scan Logs From The Device',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: theme.textTheme.bodySmall?.color,
                              fontSize: 14,
                              fontFamily: 'Barlow',
                            ),
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
