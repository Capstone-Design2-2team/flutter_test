import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  bool _isLoading = false;
  bool _isNicknameChecked = false;
  bool _isCheckingNickname = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _signup() async {
    if (_formKey.currentState!.validate()) {
      if (!_isNicknameChecked) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('닉네임 중복확인을 해주세요.')),
        );
        return;
      }

      setState(() => _isLoading = true);
      try {
        final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

        if (userCredential.user != null) {
          final user = userCredential.user!;
          final nickname = _nicknameController.text.trim();
          final bio = _bioController.text.trim();
          final email = _emailController.text.trim();
          
          // 사용자 프로필 업데이트 (닉네임)
          await user.updateDisplayName(nickname);
          
          // Firestore에 사용자 정보 저장 (이미지와 동일한 필드 구조)
          await _firestore.collection('users').doc(user.uid).set({
            'user_id': email,
            'uid': user.uid,
            'nickname': nickname,
            'bio': bio.isNotEmpty ? bio : '',
            'current_location': [0.0, 0.0], // [위도, 경도]
            'follower_count': 0,
            'following_count': 0,
            'post_count': 0,
            'is_location_public': false,
            'main_pet_id': 'none',
            'profile_image': 'https://via.placeholder.com/150',
          }, SetOptions(merge: true));
          
          if (mounted) {
            // 회원가입 완료 다이얼로그 표시
            await _showSignupSuccessDialog(context);
          }
        }
      } on FirebaseAuthException catch (e) {
        String errorMessage = '회원가입에 실패했습니다.';
        if (e.code == 'weak-password') {
          errorMessage = '비밀번호가 너무 약합니다.';
        } else if (e.code == 'email-already-in-use') {
          errorMessage = '이미 사용 중인 이메일입니다.';
        } else if (e.code == 'invalid-email') {
          errorMessage = '유효하지 않은 이메일 형식입니다.';
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage)),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('오류가 발생했습니다: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  String? _validateNickname(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '닉네임을 입력해주세요.';
    }
    final trimmed = value.trim();
    if (trimmed.length < 2) {
      return '닉네임은 2자 이상이어야 합니다.';
    }
    if (trimmed.length > 20) {
      return '닉네임은 20자 이하여야 합니다.';
    }
    // 특수문자 제한 (한글, 영문, 숫자, 언더스코어, 하이픈만 허용)
    if (!RegExp(r'^[가-힣a-zA-Z0-9_-]+$').hasMatch(trimmed)) {
      return '닉네임은 한글, 영문, 숫자, _, - 만 사용 가능합니다.';
    }
    return null;
  }

  Future<void> _checkNickname() async {
    final nickname = _nicknameController.text.trim();
    
    // 기본 검증
    final validationError = _validateNickname(nickname);
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validationError)),
      );
      return;
    }

    setState(() {
      _isCheckingNickname = true;
      _isNicknameChecked = false;
    });

    try {
      // Firestore에서 닉네임 중복 확인
      final QuerySnapshot querySnapshot = await _firestore
          .collection('users')
          .where('nickname', isEqualTo: nickname)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        // 닉네임이 이미 존재함
        if (mounted) {
          setState(() {
            _isNicknameChecked = false;
            _isCheckingNickname = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('이미 사용 중인 닉네임입니다.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        // 닉네임 사용 가능
        if (mounted) {
          setState(() {
            _isNicknameChecked = true;
            _isCheckingNickname = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('사용 가능한 닉네임입니다.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } on FirebaseException catch (e) {
      // Firestore 오류 처리
      String errorMessage = '닉네임 확인 중 오류가 발생했습니다.';
      if (e.code == 'permission-denied') {
        errorMessage = '권한이 없습니다. 관리자에게 문의하세요.';
      } else if (e.code == 'unavailable') {
        errorMessage = '서비스를 사용할 수 없습니다. 네트워크를 확인해주세요.';
      } else if (e.code == 'deadline-exceeded') {
        errorMessage = '요청 시간이 초과되었습니다. 다시 시도해주세요.';
      }
      
      if (mounted) {
        setState(() {
          _isNicknameChecked = false;
          _isCheckingNickname = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // 기타 예외 처리
      if (mounted) {
        setState(() {
          _isNicknameChecked = false;
          _isCheckingNickname = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류가 발생했습니다: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 예외 처리 로직 (Validation)
  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return '이메일을 입력해주세요.';
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) return '유효한 이메일 형식이 아닙니다.';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return '비밀번호를 입력해주세요.';
    if (value.length < 6) return '비밀번호는 6자 이상이어야 합니다.';
    return null;
  }

  Future<void> _showSignupSuccessDialog(BuildContext context) async {
    return showDialog(
      context: context,
      barrierDismissible: false, // 다이얼로그 외부 터치로 닫기 방지
      builder: (BuildContext context) {
        return PopScope(
          canPop: false, // 뒤로가기 버튼으로 닫기 방지
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 28),
                SizedBox(width: 10),
                Text(
                  '회원가입 완료',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: const Text(
              '회원가입이 성공적으로 완료되었습니다!\n\n이제 로그인하여 서비스를 이용하실 수 있습니다.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF233554),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop(); // 다이얼로그 닫기
                    // 모든 화면을 제거하고 시작 화면으로 이동
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  child: const Text(
                    '확인',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nicknameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF233554),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: const Text('회원가입', style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabel("아이디"),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  hintText: '이메일을 입력하시오.',
                  border: OutlineInputBorder(),
                ),
                validator: _validateEmail,
              ),
              const SizedBox(height: 20),
              _buildLabel("비밀번호"),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  hintText: '비밀번호 입력하시오.',
                  border: OutlineInputBorder(),
                ),
                validator: _validatePassword,
              ),
              const SizedBox(height: 20),
              _buildLabel("비밀번호 확인"),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  hintText: '비밀번호 재확인',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value != _passwordController.text ? '비밀번호가 일치하지 않습니다.' : null,
              ),
              const SizedBox(height: 20),
              _buildLabel("닉네임"),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _nicknameController,
                      decoration: InputDecoration(
                        hintText: '닉네임 입력 (2-20자)',
                        border: const OutlineInputBorder(),
                        suffixIcon: _isNicknameChecked
                            ? const Icon(Icons.check_circle, color: Colors.green)
                            : _isCheckingNickname
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: Padding(
                                      padding: EdgeInsets.all(12.0),
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  )
                                : null,
                      ),
                      onChanged: (value) {
                        if (_isNicknameChecked) {
                          setState(() => _isNicknameChecked = false);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF233554)),
                    onPressed: _isCheckingNickname ? null : _checkNickname,
                    child: _isCheckingNickname
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('중복확인', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildLabel("한 줄 소개"),
              TextFormField(
                controller: _bioController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '자신을 소개해주세요.',
                ),
                maxLines: 2,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF233554)),
                  onPressed: _isLoading ? null : _signup,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('회원 가입', style: TextStyle(color: Colors.white, fontSize: 18)),
                ),
              ),
              const SizedBox(height: 30), // 키보드 공간 확보를 위한 여백 추가
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)));
}