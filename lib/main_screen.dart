import 'package:flutter/material.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF233554),
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: null, // 뒤로가기 화살표 완전히 제거
        toolbarHeight: kToolbarHeight, // 기본 높이 유지
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return _buildHomeScreen();
      case 1:
        return _buildFeedScreen();
      case 2:
        return _buildAddScreen();
      case 3:
        return _buildFriendsScreen();
      case 4:
        return _buildMyPageScreen();
      default:
        return _buildHomeScreen();
    }
  }

  Widget _buildHomeScreen() {
    return const Center(
      child: Text(
        '등록된 반려동물이 없습니다.',
        style: TextStyle(
          color: Colors.grey,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildFeedScreen() {
    return const Center(
      child: Text(
        '피드 화면',
        style: TextStyle(fontSize: 18),
      ),
    );
  }

  Widget _buildAddScreen() {
    return const Center(
      child: Text(
        '추가 화면',
        style: TextStyle(fontSize: 18),
      ),
    );
  }

  Widget _buildFriendsScreen() {
    return const Center(
      child: Text(
        '친구 화면',
        style: TextStyle(fontSize: 18),
      ),
    );
  }

  Widget _buildMyPageScreen() {
    return const Center(
      child: Text(
        'MY 화면',
        style: TextStyle(fontSize: 18),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF233554),
      ),
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
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected ? Colors.white : Colors.grey,
            size: 24,
          ),
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
      onTap: () {
        setState(() {
          _currentIndex = 2;
        });
      },
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: const Color(0xFF233554),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: 2,
          ),
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

// 뼈 모양 아이콘을 그리는 CustomPainter
class BoneIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final radius = size.width / 6;

    // 뼈 모양: 두 개의 원과 중간 연결 부분
    // 왼쪽 원
    canvas.drawCircle(
      Offset(centerX - size.width / 4, centerY),
      radius,
      paint,
    );

    // 오른쪽 원
    canvas.drawCircle(
      Offset(centerX + size.width / 4, centerY),
      radius,
      paint,
    );

    // 중간 연결 부분 (사각형)
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

