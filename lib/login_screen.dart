import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'main_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final String input = _idController.text.trim();
        String email = input;

        // 이메일 형식이 아니면 닉네임 또는 user_id로 간주하고 Firestore에서 이메일 찾기
        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(input)) {
          // 먼저 닉네임으로 검색
          QuerySnapshot querySnapshot = await _firestore
              .collection('users')
              .where('nickname', isEqualTo: input)
              .limit(1)
              .get();

          // 닉네임으로 찾지 못하면 user_id로 검색
          if (querySnapshot.docs.isEmpty) {
            querySnapshot = await _firestore
                .collection('users')
                .where('user_id', isEqualTo: input)
                .limit(1)
                .get();
          }

          if (querySnapshot.docs.isEmpty) {
            if (mounted) {
              setState(() => _isLoading = false);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('등록되지 않은 아이디/닉네임입니다.'),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return;
          }

          final data = querySnapshot.docs.first.data() as Map<String, dynamic>?;
          // user_id 필드 사용 (이미지 구조에 맞춤), 없으면 email 필드 사용 (기존 데이터 호환)
          email = data?['user_id'] as String? ?? 
                  data?['email'] as String? ?? '';
          if (email.isEmpty) {
            if (mounted) {
              setState(() => _isLoading = false);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('이메일 정보를 찾을 수 없습니다.'),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return;
          }
        } else {
          // 이메일 형식이면 user_id로도 확인
          final QuerySnapshot emailCheck = await _firestore
              .collection('users')
              .where('user_id', isEqualTo: input)
              .limit(1)
              .get();

          if (emailCheck.docs.isEmpty) {
            if (mounted) {
              setState(() => _isLoading = false);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('등록되지 않은 이메일입니다.'),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return;
          }
        }

        // Firebase 인증으로 로그인
        final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
          email: email,
          password: _passwordController.text,
        );

        if (userCredential.user != null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('로그인 성공!'),
                backgroundColor: Colors.green,
              ),
            );
            // 로그인 성공 후 메인 화면으로 이동
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const MainScreen()),
            );
          }
        }
      } on FirebaseAuthException catch (e) {
        String errorMessage = '로그인에 실패했습니다.';
        if (e.code == 'user-not-found') {
          errorMessage = '등록되지 않은 이메일입니다.';
        } else if (e.code == 'wrong-password') {
          errorMessage = '비밀번호가 잘못되었습니다.';
        } else if (e.code == 'invalid-email') {
          errorMessage = '유효하지 않은 이메일 형식입니다.';
        } else if (e.code == 'user-disabled') {
          errorMessage = '비활성화된 계정입니다.';
        } else if (e.code == 'too-many-requests') {
          errorMessage = '너무 많은 시도가 있었습니다. 나중에 다시 시도해주세요.';
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('오류가 발생했습니다: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  String? _validateId(String? value) {
    if (value == null || value.isEmpty) {
      return '아이디/닉네임을 입력해주세요.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return '비밀번호를 입력해주세요.';
    }
    return null;
  }

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF233554),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(30),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '로그인',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 40),
              TextFormField(
                controller: _idController,
                decoration: const InputDecoration(
                  labelText: '아이디/닉네임',
                  hintText: '이메일 또는 닉네임을 입력하시오.',
                  border: OutlineInputBorder(),
                ),
                validator: _validateId,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '비밀번호',
                  hintText: '비밀번호 입력하시오.',
                  border: OutlineInputBorder(),
                ),
                validator: _validatePassword,
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF233554),
                  ),
                  onPressed: _isLoading ? null : _login,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          '로그인',
                          style: TextStyle(color: Colors.white, fontSize: 18),
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
