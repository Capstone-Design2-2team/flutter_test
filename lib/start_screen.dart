import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import 'signup_screen.dart';

class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isCheckingAuth = true;

  @override
  void initState() {
    super.initState();
    _checkAutoLogin();
  }

  Future<void> _checkAutoLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keepLoggedIn = prefs.getBool('keepLoggedIn') ?? false;

      if (keepLoggedIn) {
        // Firebase 인증 상태 확인
        final user = _auth.currentUser;
        if (user != null) {
          // 이미 로그인되어 있으면 메인 화면으로 이동
          // TODO: 메인 화면이 생기면 여기서 Navigator.pushReplacement로 이동
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('자동 로그인되었습니다.'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          // 저장된 이메일이 있지만 세션이 만료된 경우
          final savedEmail = prefs.getString('userEmail');
          if (savedEmail != null) {
            // 세션 만료로 인한 자동 로그인 실패
            await prefs.setBool('keepLoggedIn', false);
          }
        }
      }
    } catch (e) {
      // 오류 발생 시 자동 로그인 실패 처리
      debugPrint('자동 로그인 체크 오류: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingAuth = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingAuth) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // 로고 영역 (이미지나 텍스트로 대체)
              const Text(
                'PETMOVE',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF233554), letterSpacing: 2),
              ),
              const Spacer(),
              // 시작하기 버튼
              _buildButton(context, '시작하기', const LoginScreen()),
              const SizedBox(height: 15),
              // 회원가입 버튼
              _buildButton(context, '회원 가입', const SignupScreen()),
              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildButton(BuildContext context, String text, Widget nextScreen) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF233554),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => nextScreen)),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 16)),
      ),
    );
  }
}