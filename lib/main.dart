import 'package:flutter/material.dart';
import 'brand.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'screens/onboarding_screen.dart';
import 'state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await app.loadPrefs();
  runApp(const WhatstoreApp());
}

class WhatstoreApp extends StatelessWidget {
  const WhatstoreApp({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app,
        builder: (_, __) => MaterialApp(
          title: Brand.name,
          debugShowCheckedModeBanner: false,
          theme: appTheme(),
          home: const _Root(),
        ),
      );
}

/// Onboarding (1re ouverture) -> connexion -> application.
class _Root extends StatelessWidget {
  const _Root();
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app,
        builder: (_, __) => !app.onboarded
            ? const OnboardingScreen()
            : app.user == null
                ? const LoginScreen()
                : const MainShell(),
      );
}
