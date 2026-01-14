import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:teamproject/walk/walk_record_edit_simple_screen.dart';

class WalkRecordDetailScreen extends StatefulWidget {
  final String walkRecordId;
  final String? petId;

  const WalkRecordDetailScreen({
    super.key,
    required this.walkRecordId,
    this.petId,
  });

  @override
  State<WalkRecordDetailScreen> createState() => _WalkRecordDetailScreenState();
}

class _WalkRecordDetailScreenState extends State<WalkRecordDetailScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  Map<String, dynamic>? _walkRecord;
  Map<String, dynamic>? _pet;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWalkRecord();
  }

  Future<void> _loadWalkRecord() async {
    try {
      // 산책 기록 불러오기
      final walkDoc = await _firestore.collection('walk_records').doc(widget.walkRecordId).get();
      
      if (!walkDoc.exists) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final walkData = walkDoc.data()!;
      
      // 반려동물 정보 불러오기
      String? petId = widget.petId;
      if (petId == null && walkData['pet_ids'] != null && walkData['pet_ids'].isNotEmpty) {
        petId = walkData['pet_ids'][0];
      }

      Map<String, dynamic>? petData;
      if (petId != null) {
        final petDoc = await _firestore.collection('pets').doc(petId).get();
        if (petDoc.exists) {
          petData = petDoc.data();
        }
      }

      setState(() {
        _walkRecord = walkData;
        _pet = petData;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading walk record: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    return DateFormat('yyyy-MM-dd').format(date);
  }

  String _formatTimeRange(Timestamp start, Timestamp end) {
    final startTime = DateFormat('HH:mm').format(start.toDate());
    final endTime = DateFormat('HH:mm').format(end.toDate());
    return '$startTime - $endTime';
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
          '산책기록 확인 상세 페이지',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _walkRecord == null
              ? const Center(child: Text('산책 기록을 찾을 수 없습니다.'))
              : _buildWalkRecordDetail(),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildWalkRecordDetail() {
    final startTime = _walkRecord!['start_time'] as Timestamp;
    final endTime = _walkRecord!['end_time'] as Timestamp;
    final distance = _walkRecord!['distance_km'] ?? 0.0;
    final images = _walkRecord!['post_images'] as List<dynamic>?;
    final firstImage = images != null && images.isNotEmpty ? images.first.toString() : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 반려동물 정보
          _buildPetInfo(),
          
          const SizedBox(height: 20),
          
          // 산책 기록 제목
          const Text(
            '산책 기록',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF233554),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // 산책 사진
          Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF233554), width: 1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: firstImage != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(firstImage, fit: BoxFit.cover),
                  )
                : const Center(
                    child: Text(
                      '산책 사진',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF233554),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
          ),
          
          const SizedBox(height: 16),
          
          // 날짜
          Text(
            _formatDate(startTime),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFF233554),
            ),
          ),
          
          const SizedBox(height: 8),
          
          // 산책 시간
          Text(
            '산책시간: ${_formatTimeRange(startTime, endTime)}',
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF233554),
            ),
          ),
          
          const SizedBox(height: 8),
          
          // 총 거리
          Text(
            '총 거리 : ${distance}km',
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF233554),
            ),
          ),
          
          const SizedBox(height: 30),
          
          // 이동 경로 보기 버튼
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('이동 경로 보기 기능')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF233554),
                side: const BorderSide(color: Color(0xFF233554)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: const Text(
                '이동 경로 보기',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // 산책거리/시간 통계 그래프 보기 버튼
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('산책거리/시간 통계 그래프 보기 기능')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF233554),
                side: const BorderSide(color: Color(0xFF233554)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: const Text(
                '산책거리/시간 통계 그래프 보기',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 30),
          
          // 산책기록 정보 수정 버튼
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => WalkRecordEditSimpleScreen(
                      walkRecordId: widget.walkRecordId,
                    ),
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
                '산책기록 정보 수정',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPetInfo() {
    String petName = '반려동물 이름';
    String? petImageUrl;

    if (_pet != null) {
      petName = (_pet!['name'] ?? _pet!['pet_name'] ?? '반려동물 이름').toString();
      petImageUrl = (_pet!['imageUrl'] ?? _pet!['photo_url'] ?? _pet!['image_url'] ?? '').toString();
    }

    return Row(
      children: [
        // 반려동물 사진 + 체크 아이콘
        Stack(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey[300]!, width: 1),
              ),
              child: ClipOval(
                child: petImageUrl != null && petImageUrl.isNotEmpty
                    ? Image.network(petImageUrl, fit: BoxFit.cover)
                    : Container(
                        color: Colors.grey[200],
                        child: const Icon(
                          Icons.pets,
                          color: Colors.grey,
                          size: 30,
                        ),
                      ),
              ),
            ),
            // 체크 아이콘
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        
        const SizedBox(width: 16),
        
        // 반려동물 이름
        Text(
          petName,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF233554),
          ),
        ),
      ],
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildCenterNavItem() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: const Color(0xFF233554),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: CustomPaint(
          painter: BoneIconPainter(),
          size: const Size(28, 28),
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
