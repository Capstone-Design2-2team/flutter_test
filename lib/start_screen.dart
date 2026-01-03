import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'signup_screen.dart';

class StartScreen extends StatelessWidget {
  const StartScreen({super.key});

  @override
  Widget build(BuildContext context) {
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