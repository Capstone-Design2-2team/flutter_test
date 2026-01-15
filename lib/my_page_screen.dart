import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'posts_screen.dart';
import 'following_screen.dart';
import 'followers_screen.dart';
import 'pet_registration_screen.dart';
import 'user_service.dart';
import 'profile_edit_screen.dart';
import 'activity_history_screen.dart';
import 'pet_confirmation_screen.dart';
import 'blocked_users_screen.dart';
import 'representative_pet_screen.dart';
import 'pet_edit_screen.dart';
import 'dart:math' as math;

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({super.key});

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _locationPublic = false;
  Map<String, dynamic>? _userInfo;
  String? _userLocation; // 위치 정보 별도 저장
  int _postsCount = 0;
  int _followingCount = 0;
  int _followersCount = 0;
  List<Map<String, dynamic>> _pets = [];
  bool _isLoading = true;
  List<Map<String, dynamic>> _nearbyWalkers = []; // 반경 1km 내 산책 중인 사용자
  bool _isLoggingOut = false; // 로그아웃 진행 중 상태

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
        final userLocation = userInfo?['location'] as String?;

        setState(() {
          _userInfo = userInfo;
          _postsCount = postsCount;
          _followingCount = followingCount;
          _followersCount = followersCount;
          _locationPublic = locationPublic;
          _pets = pets;
          _userLocation = userLocation; // 위치 정보 별도 저장
          _isLoading = false;
        });

        // 위치 공개 상태일 때만 주변 산책 사용자 확인
        if (locationPublic && userLocation != null) {
          await _checkNearbyWalkers(userLocation);
        }
      }
    } catch (e) {
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

      // 위치 공개 상태일 때만 주변 산책 사용자 확인
      if (value && _userLocation != null) {
        await _checkNearbyWalkers(_userLocation);
      } else {
        setState(() {
          _nearbyWalkers = [];
        });
      }
    }
  }

  Future<void> _checkNearbyWalkers(String? userLocation) async {
    if (userLocation == null) return;

    try {
      // 현재 시간 기준으로 1시간 내에 시작된 산책 기록 확인
      final now = DateTime.now();
      final oneHourAgo = now.subtract(const Duration(hours: 1));

      final walkSnapshot = await FirebaseFirestore.instance
          .collection('walks')
          .where('startTime', isGreaterThanOrEqualTo: oneHourAgo)
          .where('isWalking', isEqualTo: true)
          .get();

      List<Map<String, dynamic>> nearbyWalkers = [];

      for (var doc in walkSnapshot.docs) {
        final walkData = doc.data() as Map<String, dynamic>;
        final walkerId = walkData['userId'] as String?;
        final walkerLocation =
            walkData['currentLocation'] as Map<String, dynamic>?;

        if (walkerId != null &&
            walkerLocation != null &&
            walkerId != _auth.currentUser?.uid) {
          final walkerLat = walkerLocation['latitude'] as double?;
          final walkerLng = walkerLocation['longitude'] as double?;

          if (walkerLat != null && walkerLng != null) {
            // 간단한 거리 계산 (실제로는 Geolocator.distanceBetween 사용)
            final distance = _calculateDistance(
              double.parse(userLocation.split(',')[0]), // 사용자 위도
              double.parse(userLocation.split(',')[1]), // 사용자 경도
              walkerLat,
              walkerLng,
            );

            if (distance <= 1.0) {
              // 1km 이내
              final walkerInfo = await UserService.getUserInfo(walkerId);
              if (walkerInfo != null) {
                nearbyWalkers.add({
                  'userId': walkerId,
                  'nickname': walkerInfo['nickname'] ?? '알 수 없음',
                  'distance': distance,
                  'startTime': walkData['startTime'],
                });
              }
            }
          }
        }
      }

      setState(() {
        _nearbyWalkers = nearbyWalkers;
      });
    } catch (e) {
      print('주변 산책 사용자 확인 오류: $e');
    }
  }

  double _calculateDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const double earthRadius = 6371; // 지구 반지름 (km)
    final double dLat = _toRadians(lat2 - lat1);
    final double dLng = _toRadians(lng2 - lng1);

    final double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF233554),
        elevation: 0,
        toolbarHeight: 40,
        automaticallyImplyLeading: false,
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
                  const SizedBox(height: 80),
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
              image:
                  _userInfo?['profileImageUrl'] != null &&
                      _userInfo!['profileImageUrl'].isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(_userInfo!['profileImageUrl']),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child:
                _userInfo?['profileImageUrl'] == null ||
                    _userInfo!['profileImageUrl'].isEmpty
                ? const Icon(Icons.person, size: 40, color: Colors.grey)
                : null,
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
                if (_locationPublic &&
                    _userLocation != null &&
                    _userLocation!.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 16,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _userLocation!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                ] else if (_locationPublic) ...[
                  Row(
                    children: [
                      const Icon(
                        Icons.location_off,
                        size: 16,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 5),
                      const Text(
                        '위치 정보 없음',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                ],
                Text(
                  _userInfo?['introduction'] ?? '한줄 소개',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.grey),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProfileEditScreen(),
                ),
              );
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
                _buildTabButton('팔로워', 2, _followersCount),
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
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text('위치 공개', style: TextStyle(fontSize: 14)),
              Checkbox(
                value: _locationPublic,
                onChanged: (value) {
                  _updateLocationPublic(value ?? false);
                },
                activeColor: const Color(0xFF233554),
              ),
            ],
          ),
          if (_locationPublic && _nearbyWalkers.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF233554).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF233554).withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.people,
                        size: 16,
                        color: Color(0xFF233554),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '반경 1km 내 산책 중인 사용자',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF233554),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ..._nearbyWalkers
                      .map(
                        (walker) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.directions_walk,
                                size: 14,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  '${walker['nickname']} (${(walker['distance'] * 1000).toStringAsFixed(0)}m)',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTabButton(String title, int index, int count) {
    return GestureDetector(
      onTap: () {
        switch (index) {
          case 0:
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const PostsScreen()),
            );
            break;
          case 1:
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const FollowingScreen()),
            );
            break;
          case 2:
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const FollowersScreen()),
            );
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
      margin: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
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
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            _pets.isEmpty
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text(
                          '등록된 반려동물이 없습니다',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '마이페이지에서 반려동물을 먼저 등록해주세요',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
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
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    PetConfirmationScreen(petId: pet['id']),
                              ),
                            );
                          },
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  shape: BoxShape.circle,
                                  image:
                                      pet['imageUrl'] != null &&
                                          pet['imageUrl'].isNotEmpty
                                      ? DecorationImage(
                                          image: NetworkImage(pet['imageUrl']),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child:
                                    pet['imageUrl'] == null ||
                                        pet['imageUrl'].isEmpty
                                    ? const Icon(Icons.pets, color: Colors.grey)
                                    : null,
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
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
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
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
      child: Column(
        children: [
          _buildMenuButton('나의 활동 이력'),
          const SizedBox(height: 10),
          _buildMenuButton('차단된 사용자'),
          const SizedBox(height: 10),
          _buildMenuButton('대표 반려동물 선택'),
          const SizedBox(height: 10),
          _buildLogoutButton(),
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
          switch (title) {
            case '나의 활동 이력':
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ActivityHistoryScreen(),
                ),
              );
              break;
            case '차단된 사용자':
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const BlockedUsersScreen(),
                ),
              );
              break;
            case '대표 반려동물 선택':
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const RepresentativePetScreen(),
                ),
              );
              break;
          }
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Container(
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: MaterialButton(
        onPressed: () {
          _showLogoutConfirmation();
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '로그아웃',
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  void _showLogoutConfirmation() {
    if (_isLoggingOut) return; // 이미 로그아웃 진행 중이면 무시
    
    showDialog(
      context: context,
      barrierDismissible: false, // 다이얼로그 외부 클릭으로 닫기 방지
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('로그아웃'),
          content: const Text('정말로 로그아웃하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // 다이얼로그 닫기
              },
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context); // 다이얼로그 닫기
                await _performLogout();
              },
              child: _isLoggingOut 
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('로그아웃', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _performLogout() async {
    if (_isLoggingOut) return; // 이미 로그아웃 진행 중이면 무시
    
    setState(() {
      _isLoggingOut = true;
    });
    
    try {
      await _auth.signOut();
      
      // 앱을 완전히 재시작하여 초기 화면으로 이동
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      
      // 성공 메시지는 앱 재시작 후에 표시되므로 제거
      // ScaffoldMessenger.of(context).showSnackBar(
      //   const SnackBar(
      //     content: Text('로그아웃되었습니다.'),
      //     backgroundColor: Colors.green,
      //   ),
      // );
    } catch (e) {
      print('로그아웃 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('로그아웃에 실패했습니다.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoggingOut = false;
      });
    }
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
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const PetRegistrationScreen(),
              ),
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

class WalkHistoryScreen extends StatefulWidget {
  final String? petId;

  const WalkHistoryScreen({super.key, this.petId});

  @override
  State<WalkHistoryScreen> createState() => _WalkHistoryScreenState();
}

class _WalkHistoryScreenState extends State<WalkHistoryScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> _walkRecords = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWalkHistory();
  }

  Future<void> _loadWalkHistory() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      Query query = _firestore
          .collection('walk_records')
          .where('user_id', isEqualTo: user.uid)
          .orderBy('date', descending: true);

      if (widget.petId != null) {
        query = query.where('pet_id', isEqualTo: widget.petId);
      }

      final snapshot = await query.get();

      List<Map<String, dynamic>> records = [];
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        records.add({
          'id': doc.id,
          'date': data['date'],
          'distance_km': data['distance_km'] ?? 0.0,
          'duration_minutes': data['duration_minutes'] ?? 0,
          'route': data['route'] as List<dynamic>?,
          'pet_id': data['pet_id'],
          'pet_name': data['pet_name'] ?? '알 수 없는 펫',
        });
      }

      setState(() {
        _walkRecords = records;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading walk history: $e');
      setState(() => _isLoading = false);
    }
  }

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatTime(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF233554),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _walkRecords.isEmpty
          ? const Center(
              child: Text(
                '산책 기록이 없습니다',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _walkRecords.length,
              itemBuilder: (context, index) {
                final record = _walkRecords[index];
                final date = record['date'] as Timestamp;

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE0E0E0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              record['pet_name'],
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF233554),
                              ),
                            ),
                            Text(
                              _formatDate(date),
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.straighten,
                              color: Colors.grey,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${record['distance_km']}km',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Icon(
                              Icons.access_time,
                              color: Colors.grey,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${record['duration_minutes']}분',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 200,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE0E0E0)),
                          ),
                          child:
                              record['route'] != null &&
                                  (record['route'] as List).isNotEmpty
                              ? CustomPaint(
                                  painter: RoutePainter(
                                    record['route'] as List<dynamic>,
                                  ),
                                  child: Container(),
                                )
                              : const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.map_outlined,
                                        size: 48,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '경로 정보가 없습니다',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class RoutePainter extends CustomPainter {
  final List<dynamic> routePoints;

  RoutePainter(this.routePoints);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF233554)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    if (routePoints.isEmpty) return;

    final path = Path();
    final bounds = Rect.fromLTWH(0, 0, size.width, size.height);
    final center = bounds.center;
    final radius = math.min(size.width, size.height) * 0.4;

    for (int i = 0; i < routePoints.length; i++) {
      final angle = (i / (routePoints.length - 1)) * 2 * math.pi;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
