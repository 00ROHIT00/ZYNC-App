import 'package:flutter/cupertino.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final greeted = prefs.getBool('greeted') ?? false;
  runApp(MyApp(greeted: greeted));
}

class MyApp extends StatelessWidget {
  final bool greeted;
  const MyApp({super.key, required this.greeted});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: 'ZYNC',
      theme: const CupertinoThemeData(
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
      home: greeted ? const HomeScreen() : const SplashScreen(),
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
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _controller.forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(seconds: 1), () {
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
      child: SafeArea(
        child: Stack(
          children: [
            // ZYNC at the top
            Positioned(
              top: 32,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  'ZYNC',
                  style: const TextStyle(
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
                            decoration: TextDecoration.underline,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      child: Center(
        child: Text(
          'Welcome to ZYNC!',
          style: const TextStyle(
            color: CupertinoColors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
            fontFamily: 'Barlow',
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
      child: Center(
        child: Text(
          'Hello ${widget.name}, welcome to ZYNC',
          style: const TextStyle(
            color: CupertinoColors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
            fontFamily: 'Barlow',
          ),
          textAlign: TextAlign.center,
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
                          // TODO: Navigate to the next screen
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
