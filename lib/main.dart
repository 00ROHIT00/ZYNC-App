import 'package:flutter/cupertino.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

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
      // Optionally, navigate to HomeScreen after greeting
      Future.delayed(const Duration(seconds: 1), () {
        Navigator.of(context).pushReplacement(
          CupertinoPageRoute(builder: (_) => const HomeScreen()),
        );
      });
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
