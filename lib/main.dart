import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'start_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 상태표시줄과 네비게이션 바 설정
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarDividerColor: Colors.transparent,
  ));
  
  // 네비게이션 바 숨김 설정
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  
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
      theme: AppTheme.lightTheme,
      // 상태표시줄과 네비게이션 바 설정
      builder: (context, child) {
        return GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
          },
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: EdgeInsets.zero, // Remove any default padding
            ),
            child: child!,
          ),
        );
      },
      home: const StartScreen(),
    );
  }
}