import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'start_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const PetMoveApp());
}

class PetMoveApp extends StatelessWidget {
  const PetMoveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PETMOVE',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0), // 남색 테마
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const StartScreen(),
    );
  }
}