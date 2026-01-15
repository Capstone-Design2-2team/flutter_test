import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:teamproject/walk_record_check_screen.dart';
import 'package:teamproject/pet_update_service.dart';
import 'package:teamproject/pet_edit_screen.dart';

class PetConfirmationScreen extends StatefulWidget {
  final String petId;

  const PetConfirmationScreen({super.key, required this.petId});

  @override
  State<PetConfirmationScreen> createState() => _PetConfirmationScreenState();
}

class _PetConfirmationScreenState extends State<PetConfirmationScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Map<String, dynamic>? _petData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPetData();
    // Listen for pet updates
    PetUpdateService().addListener(_loadPetData);
  }

  @override
  void dispose() {
    // Remove listener when screen is disposed
    PetUpdateService().removeListener(_loadPetData);
    super.dispose();
  }

  Future<void> _loadPetData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      final petDoc = await _firestore.collection('pets').doc(widget.petId).get();
      
      if (petDoc.exists) {
        setState(() {
          _petData = petDoc.data() as Map<String, dynamic>;
          _isLoading = false;
        });
      } else {
        if (mounted) {
          setState(() {
            _petData = null;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading pet data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatBirthDate(dynamic birthDate) {
    if (birthDate == null) return '정보 없음';
    
    if (birthDate is Timestamp) {
      final date = birthDate.toDate();
      return '${date.year}년 ${date.month}월 ${date.day}일';
    }
    
    return birthDate.toString();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_petData == null) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Text('펫 정보를 찾을 수 없습니다'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF233554),
        elevation: 0,
        titleSpacing: 16,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20), // Add space at the top
            // 메인 이미지 영역
            GestureDetector(
              onTap: () {
                // 반려동물 정보를 클릭하면 펫 정보 수정 화면으로 이동
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PetEditScreen(petId: widget.petId),
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                height: 300,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF233554), width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: _petData!['imageUrl'] != null && _petData!['imageUrl'].isNotEmpty
                      ? Image.network(
                          _petData!['imageUrl'],
                          width: double.infinity,
                          height: 300,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: double.infinity,
                              height: 300,
                              color: Colors.grey[300],
                              child: const Icon(Icons.pets, size: 80, color: Colors.grey),
                            );
                          },
                        )
                      : Container(
                          width: double.infinity,
                          height: 300,
                          color: Colors.grey[300],
                          child: const Icon(Icons.pets, size: 80, color: Colors.grey),
                        ),
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // 정보 표시 섹션
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow('이름:', _petData!['name'] ?? '정보 없음'),
                  _buildInfoRow('품종:', _petData!['breed'] ?? '정보 없음'),
                  _buildInfoRow('생년월일:', _formatBirthDate(_petData!['birthDate'])),
                  _buildInfoRow('성별:', _petData!['gender'] ?? '정보 없음'),
                  _buildInfoRow('몸무게:', '${_petData!['weight'] ?? 0}kg'),
                  _buildInfoRow('중성화 여부:', _petData!['isNeutered'] == true ? '완료' : '미완료'),
                ],
              ),
            ),

            // 산책기록 확인 버튼
            Container(
              width: double.infinity,
              height: 50,
              margin: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF233554),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ElevatedButton(
                onPressed: () {
                  print('DEBUG: Navigate to WalkRecordCheckScreen with petId: ${widget.petId}');
                  // WalkRecordCheckScreen으로 전환
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => WalkRecordCheckScreen(petId: widget.petId),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF233554),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  '산책기록 확인',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
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
    final isSelected = index == 2; // 반려동물 탭이 활성화 상태
    return GestureDetector(
      onTap: () {
        // TODO: 화면 전환 로직 추가
      },
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
      onTap: () {
        // TODO: 현재 화면 유지
      },
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
