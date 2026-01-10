import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:teamproject/feed_screen.dart';
import 'package:teamproject/my_page_screen.dart';
import 'package:teamproject/pet_registration_screen.dart';
import 'package:teamproject/walk/walk_screen.dart';
import 'package:teamproject/friends_screen.dart';
import 'walk/walk_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // RouteSettings에서 초기 탭 인덱스 확인
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is int && args >= 0 && args <= 4) {
        setState(() {
          _currentIndex = args;
        });
      }
    });
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
        // appBar: AppBar(
        //   backgroundColor: const Color(0xFF233554),
        //   elevation: 0,
        //   automaticallyImplyLeading: false,
        //   leading: null,
        //   toolbarHeight: kToolbarHeight,
        // ),
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
    return const Center(
      child: Text(
        '등록된 반려동물이 없습니다.',
        style: TextStyle(color: Colors.grey, fontSize: 16),
      ),
    );
  }

  Widget _buildAddScreen() {
    return WalkScreen(
      onBackToHome: () {
        setState(() => _currentIndex = 0);
      },
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