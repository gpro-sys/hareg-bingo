/// Hareg Bingo application entry point.
library;

import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/card_storage.dart';

/// Boots the app with preferences loaded before the first frame.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CardStorage.setup();
  runApp(const HaregBingoApp());
}

/// Root of Hareg Bingo - a 75-ball cartela bingo caller.
class HaregBingoApp extends StatelessWidget {
  const HaregBingoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hareg Bingo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6B43C4),
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
