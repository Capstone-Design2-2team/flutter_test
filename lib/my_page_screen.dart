import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'posts_screen.dart';
import 'following_screen.dart';
import 'followers_screen.dart';
import 'pet_registration_screen.dart';
import 'user_service.dart';
import 'dart:io';

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({super.key});

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  bool _locationPublic = false;
  Map<String, dynamic>? _userInfo;
  int _postsCount = 0;
  int _followingCount = 0;
  int _followersCount = 0;
  List<Map<String, dynamic>> _pets = [];
  bool _isLoading = true;
  final ImagePicker _picker = ImagePicker();
  File? _profileImage;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final userInfo = await UserService.getCurrentUserInfo();
      final userId = UserService.getCurrentUserId();
      
      if (userId != null) {
        final postsCount = await UserService.getUserPostsCount(userId);
        final followingCount = await UserService.getUserFollowingCount(userId);
        final followersCount = await UserService.getUserFollowersCount(userId);
        final locationPublic = await UserService.getUserLocationPublic(userId);
        final pets = await UserService.getUserPets(userId);
        
        setState(() {
          _userInfo = userInfo;
          _postsCount = postsCount;
          _followingCount = followingCount;
          _followersCount = followersCount;
          _locationPublic = locationPublic;
          _pets = pets;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('사용자 데이터 로드 오류: $e');
      setState(() => _isLoading = false);
    }
  }

  void _showProfileImageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('프로필 이미지'),
        content: const Text('프로필 이미지 수정 기능은 준비 중입니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickProfileImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        setState(() {
          _profileImage = File(pickedFile.path);
        });
        await _uploadProfileImage();
      }
    } catch (e) {
      print('프로필 이미지 선택 오류: $e');
    }
  }

  Future<void> _uploadProfileImage() async {
    if (_profileImage == null) return;
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      String fileName = 'profile_${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference ref = FirebaseStorage.instance.ref().child('profile_images').child(fileName);

      UploadTask uploadTask = ref.putFile(_profileImage!);
      TaskSnapshot snapshot = await uploadTask;
      String imageUrl = await snapshot.ref.getDownloadURL();

      // Firestore에 이미지 URL 업데이트
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'profileImageUrl': imageUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 로컬 상태 업데이트
      setState(() {
        if (_userInfo != null) {
          _userInfo!['profileImageUrl'] = imageUrl;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('프로필 이미지가 업데이트되었습니다.')),
      );
    } catch (e) {
      print('프로필 이미지 업로드 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('프로필 이미지 업로드에 실패했습니다.')),
      );
    }
  }

  Future<void> _updateLocationPublic(bool value) async {
    final userId = UserService.getCurrentUserId();
    if (userId != null) {
      await UserService.updateLocationPublic(userId, value);
      setState(() {
        _locationPublic = value;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF233554),
        elevation: 0,
        toolbarHeight: 40, // 앱바 높이 줄이기
        automaticallyImplyLeading: false, // 뒤로가기 버튼 제거
        title: const Text(
          'MY',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            child: Column(
              children: [
                _buildProfileSection(),
                _buildTabsSection(),
                _buildLocationSection(),
                _buildPetSection(),
                _buildMenuButtons(),
                _buildRegisterPetButton(),
                const SizedBox(height: 80), // 하단 네비게이션 바 공간
              ],
            ),
          ),
    );
  }

  Widget _buildProfileSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              shape: BoxShape.circle,
            ),
            child: _userInfo?['profileImageUrl'] != null && _userInfo!['profileImageUrl'].isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(40),
                    child: Image.network(
                      _userInfo!['profileImageUrl'],
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.person,
                          size: 40,
                          color: Colors.grey,
                        );
                      },
                    ),
                  )
                : const Icon(
                    Icons.person,
                    size: 40,
                    color: Colors.grey,
                  ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userInfo?['nickname'] ?? '닉네임',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _userInfo?['introduction'] ?? '한줄 소개',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.grey),
            onPressed: () {
              // 프로필 편집 기능
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTabsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTabButton('게시글', 0, _postsCount),
                _buildTabButton('팔로잉', 1, _followingCount),
                _buildTabButton('팔로우', 2, _followersCount),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const Text(
            '위치 공개',
            style: TextStyle(fontSize: 14),
          ),
          Checkbox(
            value: _locationPublic,
            onChanged: (value) {
              _updateLocationPublic(value ?? false);
            },
            activeColor: const Color(0xFF233554),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String title, int index, int count) {
    return GestureDetector(
      onTap: () {
        // 해당 화면으로 이동
        switch (index) {
          case 0:
            Navigator.push(context, MaterialPageRoute(builder: (context) => const PostsScreen()));
            break;
          case 1:
            Navigator.push(context, MaterialPageRoute(builder: (context) => const FollowingScreen()));
            break;
          case 2:
            Navigator.push(context, MaterialPageRoute(builder: (context) => const FollowersScreen()));
            break;
        }
      },
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.normal,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            count.toString(),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildPetSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '반려동물 확인',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 15),
            _pets.isEmpty
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '등록된 반려동물이 없습니다',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                : Column(
                    children: _pets.map((pet) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                shape: BoxShape.circle,
                              ),
                              child: pet['imageUrl'] != null && pet['imageUrl'].isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(20),
                                      child: Image.network(
                                        pet['imageUrl'],
                                        width: 40,
                                        height: 40,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return const Icon(Icons.pets, color: Colors.grey);
                                        },
                                      ),
                                    )
                                  : const Icon(Icons.pets, color: Colors.grey),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    pet['name'] ?? '이름 없음',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    pet['breed'] ?? '품종 정보 없음',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (pet['isRepresentative'] == true)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF233554),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  '대표',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          _buildMenuButton('나의 활동 이력'),
          const SizedBox(height: 15),
          _buildMenuButton('차단된 사용자'),
          const SizedBox(height: 15),
          _buildMenuButton('대표 반려동물 선택'),
        ],
      ),
    );
  }

  Widget _buildMenuButton(String title) {
    return Container(
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: MaterialButton(
        onPressed: () {
          // 각 메뉴 기능 구현
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegisterPetButton() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF233554),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () {
            // 반려동물 등록 화면으로 이동
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const PetRegistrationScreen()),
            );
          },
          child: const Text(
            '반려동물 등록',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
