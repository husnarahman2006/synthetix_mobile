import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';

import 'constants/synthetix_constants.dart';
import 'screens/synthetix_compiler.dart';
import 'screens/auth_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const SynthetixApp());
}

class SynthetixApp extends StatelessWidget {
  const SynthetixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Synthetix Mobile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: SynthetixConstants.primaryColor),
        useMaterial3: true,
        scrollbarTheme: ScrollbarThemeData(
          thumbVisibility: WidgetStateProperty.all(true),
          trackVisibility: WidgetStateProperty.all(true),
          thickness: WidgetStateProperty.all(8.0),
          radius: const Radius.circular(4.0),
          thumbColor: WidgetStateProperty.all(Colors.grey.withAlpha(150)),
          trackColor: WidgetStateProperty.all(Colors.black38),
        ),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: SynthetixConstants.terminalBackground,
              body: Center(child: CircularProgressIndicator(color: SynthetixConstants.primaryColor)),
            );
          }
          // If a user session exists, route straight to the compiler interface
          if (snapshot.hasData) {
            return const CompilerScreen();
          }
          // Otherwise, serve the login/registration gateway
          return const AuthScreen();
        },
      ),
    );
  }
}