import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'pet_update_service.dart';
import 'package:teamproject/feed_screen.dart';
import 'package:teamproject/my_page_screen.dart';
import 'package:teamproject/pet_registration_screen.dart';
import 'package:teamproject/walk/walk_screen.dart';
import 'package:teamproject/friends_screen.dart';
import 'package:teamproject/like_notification_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Map<String, dynamic>? _representativePet;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRepresentativePet();
    PetUpdateService().addListener(_loadRepresentativePet);
  }

  @override
  void dispose() {
    PetUpdateService().removeListener(_loadRepresentativePet);
    super.dispose();
  }

  Future<void> _loadRepresentativePet() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('No authenticated user found');
        setState(() => _isLoading = false);
        return;
      }

      print('Loading representative pet for user: ${user.uid}');

      final petsSnapshot = await _firestore
          .collection('pets')
          .where('userId', isEqualTo: user.uid)
          .where('isRepresentative', isEqualTo: true)
          .get();

      print('Found ${petsSnapshot.docs.length} representative pets');

      if (petsSnapshot.docs.isNotEmpty) {
        final petData = petsSnapshot.docs.first.data() as Map<String, dynamic>;
        print('Representative pet data: $petData');
        setState(() {
          _representativePet = {
            'id': petsSnapshot.docs.first.id,
            ...petData,
          };
          _isLoading = false;
        });
        print('Representative pet loaded successfully');
      } else {
        setState(() {
          _representativePet = null;
          _isLoading = false;
        });
        print('No representative pet found');
      }
    } catch (e) {
      print('Error loading representative pet: $e');
      setState(() {
        _representativePet = null;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // 뒤로가기 버튼을 누르면 앱 종료 확인 다이얼로그 표시
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('앱 종료'),
            content: const Text('앱을 종료하시겠습니까?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('아니오'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('예'),
              ),
            ],
          ),
        );

        if (shouldExit == true) {
          // 앱 완전 종료 - 앱 밖으로 나가기
          SystemNavigator.pop();
          return true;
        }
        return false;
      },
      child: Scaffold(
        appBar: _currentIndex == 0 ? AppBar(
          backgroundColor: const Color(0xFF233554),
          elevation: 0,
          automaticallyImplyLeading: false,
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 16),
              child: IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LikeNotificationScreen(),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.notifications_outlined,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ],
        ) : null,
        body: _buildBody(),
        bottomNavigationBar: _buildBottomNavigationBar(),
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return _buildHomeScreen();
      case 1:
        return const FeedScreen();
      case 2:
        return _buildAddScreen();
      case 3:
        return _buildFriendsScreen();
      case 4:
        return MyPageScreen();
      default:
        return _buildHomeScreen();
    }
  }

  Widget _buildHomeScreen() {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _representativePet == null
            ? _buildNoPetState()
            : _buildRepresentativePetCard();
  }

  Widget _buildNoPetState() {
    return Container(
      color: const Color(0xFFF5F5F5),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상단 헤더
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '오늘의 산책',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF233554),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF233554),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '대표 반려동물',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // 빈 상태 카드
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    const Icon(
                      Icons.pets_outlined,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '등록된 반려동물이 없습니다.',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '마이페이지에서 반려동물을 등록해주세요',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '마이페이지에서 반려동물을 등록해주세요',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRepresentativePetCard() {
    return Container(
      color: const Color(0xFFF5F5F5),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 반려동물 이미지
              Container(
                width: double.infinity,
                height: 240,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  color: Colors.grey[200],
                ),
                child: _representativePet!['imageUrl'] != null && _representativePet!['imageUrl'].isNotEmpty
                    ? ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        child: Image.network(
                          _representativePet!['imageUrl'],
                          width: double.infinity,
                          height: 240,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Icon(Icons.pets, size: 60, color: Colors.grey),
                            );
                          },
                        ),
                      )
                    : const Center(
                        child: Icon(Icons.pets, size: 60, color: Colors.grey),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 반려동물 정보
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoField('이름', _representativePet!['name'] ?? '이름 없음'),
                        _buildInfoField('품종', _representativePet!['breed'] ?? '품종 정보 없음'),
                        _buildInfoField('생년월일', _formatBirthDate(_representativePet!['birthDate'])),
                        _buildInfoField('성별', _representativePet!['gender'] == 'male' ? '남' : 
                                       (_representativePet!['gender'] == 'female' ? '여' : '정보 없음')),
                        if (_representativePet!['weight'] != null && _representativePet!['weight'].toString().isNotEmpty)
                          _buildInfoField('몸무게', '${_representativePet!['weight']}kg'),
                        if (_representativePet!['isNeutered'] != null)
                          _buildInfoField('중성화 여부', _representativePet!['isNeutered'] == true ? '했음' : '안했음'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label :',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatBirthDate(dynamic birthDate) {
    if (birthDate == null) return '정보 없음';
    
    try {
      if (birthDate is Timestamp) {
        final date = birthDate.toDate();
        return '${date.year.toString().substring(2)}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      return '정보 없음';
    }
    
    return '정보 없음';
  }

  Widget _buildAddScreen() {
    return WalkScreen(
      onBackToHome: () {
        setState(() => _currentIndex = 0);
      },
      showOnlyWalkTab: false,
    );
  }

  Widget _buildFriendsScreen() {
    return const FriendsScreen();
  }


  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: const BoxDecoration(color: Color(0xFF233554)),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.home, '홈', 0),
              _buildNavItem(Icons.grid_view, '피드', 1),
              _buildCenterNavItem(),
              _buildNavItem(Icons.person_add, '친구', 3),
              _buildNavItem(Icons.person, 'MY', 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: isSelected ? Colors.white : Colors.grey, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterNavItem() {
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = 2),
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: const Color(0xFF233554),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Center(
          child: CustomPaint(
            painter: BoneIconPainter(),
            size: const Size(28, 28),
          ),
        ),
      ),
    );
  }
}

class BoneIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final radius = size.width / 6;

    canvas.drawCircle(Offset(centerX - size.width / 4, centerY), radius, paint);
    canvas.drawCircle(Offset(centerX + size.width / 4, centerY), radius, paint);

    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(centerX, centerY),
        width: size.width / 2,
        height: radius * 1.5,
      ),
      Radius.circular(radius / 2),
    );
    canvas.drawRRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}