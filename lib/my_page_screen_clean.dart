import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
      debugPrint('사용자 데이터 로드 오류: $e');
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
        toolbarHeight: 40,
        automaticallyImplyLeading: false,
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
              image: _userInfo?['profileImageUrl'] != null && _userInfo!['profileImageUrl'].isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(_userInfo!['profileImageUrl']),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: _userInfo?['profileImageUrl'] == null || _userInfo!['profileImageUrl'].isEmpty
                ? const Icon(
                    Icons.person,
                    size: 40,
                    color: Colors.grey,
                  )
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
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text(
                          '등록된 반려동물이 없습니다',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '마이페이지에서 반려동물을 먼저 등록해주세요',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
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
                                builder: (context) => PetConfirmationScreen(
                                  petId: pet['id'],
                                ),
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
                                  image: pet['imageUrl'] != null && pet['imageUrl'].isNotEmpty
                                      ? DecorationImage(
                                          image: NetworkImage(pet['imageUrl']),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: pet['imageUrl'] == null || pet['imageUrl'].isEmpty
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
                MaterialPageRoute(builder: (context) => const ActivityHistoryScreen()),
              );
              break;
            case '차단된 사용자':
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BlockedUsersScreen()),
              );
              break;
            case '대표 반려동물 선택':
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const RepresentativePetScreen()),
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
      child: Column(
        children: [
          SizedBox(
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
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '💡 팁',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF233554),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '반려동물 등록 버튼을 누르면 새로운 반려동물을 추가할 수 있습니다.\\n여러 마리의 반려동물을 등록하여 관리해보세요!',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
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
        title: const Text(
          '산책 기록',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _walkRecords.isEmpty
              ? const Center(
                  child: Text(
                    '산책 기록이 없습니다',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
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
                              child: record['route'] != null && (record['route'] as List).isNotEmpty
                                  ? CustomPaint(
                                      painter: RoutePainter(record['route'] as List<dynamic>),
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
