import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'posts_screen.dart';
import 'following_screen.dart';
import 'followers_screen.dart';
import 'pet_registration_screen.dart';
import 'user_service.dart';

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
      setState(() {
        _isLoading = false;
      });
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
            child: const Icon(
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
            padding: const EdgeInsets.symmetric(vertical: 10),
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
      margin: const EdgeInsets.symmetric(horizontal: 20),
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
                              child: const Icon(Icons.pets, color: Colors.grey),
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
          const SizedBox(height: 10),
          _buildMenuButton('차단된 사용자'),
          const SizedBox(height: 10),
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
