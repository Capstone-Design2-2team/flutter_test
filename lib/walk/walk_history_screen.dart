import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:teamproject/walk/walk_record_screen.dart';
import 'package:teamproject/walk/walk_record_edit_screen.dart';
import 'package:teamproject/walk/walk_record_detail_screen.dart';
import 'package:teamproject/pet_edit_screen.dart';
import 'walk_screen.dart';

class WalkHistoryScreen extends StatefulWidget {
  final String? petId;
  const WalkHistoryScreen({super.key, this.petId});

  @override
  State<WalkHistoryScreen> createState() => _WalkHistoryScreenState();
}

class _WalkHistoryScreenState extends State<WalkHistoryScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _uid;

  @override
  void initState() {
    super.initState();
    _uid = _auth.currentUser?.uid;
  }

  String _formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  String _formatTimeRange(DateTime start, DateTime end) {
    final startStr = DateFormat('HH:mm').format(start);
    final endStr = DateFormat('HH:mm').format(end);
    return '산책시간 : $startStr ~ $endStr';
  }

  @override
  Widget build(BuildContext context) {
    if (_uid == null) {
      return const Scaffold(
        body: Center(child: Text('로그인이 필요합니다.')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF233554),
        title: const Text(
          '산책기록 확인',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
        toolbarHeight: 50,
      ),
      body: Column(
        children: [
          Expanded(
            child: Column(
              children: [
                // 1. 반려동물 프로필 영역
                _buildPetProfile(),

                // 2. 산책 기록 리스트
                Expanded(
                  child: _buildWalkList(),
                ),
              ],
            ),
          ),
          
          // 3. 하단 산책하기 버튼
          _buildBottomButton(),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildPetProfile() {
    if (widget.petId != null && widget.petId!.isNotEmpty) {
      return StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('pets').doc(widget.petId!).snapshots(),
        builder: (context, snapshot) {
          String name = '반려동물 이름';
          String? imageUrl;
          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            name = (data['name'] ?? data['pet_name'] ?? '반려동물 이름').toString();
            imageUrl = (data['imageUrl'] ?? data['photo_url'] ?? data['image_url'] ?? '').toString();
          }
          return _petHeader(name: name, imageUrl: imageUrl, petId: widget.petId!);
        },
      );
    } else {
      return StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('pets')
            .where('userId', isEqualTo: _uid)
            .limit(1)
            .snapshots(),
        builder: (context, snapshot) {
          String name = '반려동물 이름';
          String? imageUrl;
          String? petId;
          if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
            final doc = snapshot.data!.docs.first;
            final data = doc.data() as Map<String, dynamic>;
            name = (data['name'] ?? data['pet_name'] ?? '반려동물 이름').toString();
            imageUrl = (data['imageUrl'] ?? data['photo_url'] ?? data['image_url'] ?? '').toString();
            petId = doc.id;
          }
          return _petHeader(name: name, imageUrl: imageUrl, petId: petId);
        },
      );
    }
  }

  Widget _petHeader({required String name, String? imageUrl, String? petId}) {
    return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Row(
            children: [
              // 반려동물 사진 + 체크 배지
              Stack(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey[200]!, width: 1),
                    ),
                    child: ClipOval(
                      child: imageUrl != null && imageUrl.isNotEmpty
                          ? Image.network(imageUrl, fit: BoxFit.cover)
                          : Image.asset('assets/images/default_pet.png',
                              errorBuilder: (context, error, stackTrace) => 
                                const Icon(Icons.pets, color: Colors.grey, size: 30),
                          ),
                    ),
                  ),
                  // 체크 배지
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.white, blurRadius: 0, spreadRadius: 2),
                        ],
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 10,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              
              // 반려동물 이름
              Text(
                name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF233554),
                ),
              ),
              const Spacer(), // 이름과 수정 아이콘 사이 간격 벌리기 (이미지처럼 우측 정렬 느낌)

              // 수정 버튼 (연필 아이콘)
              GestureDetector(
                onTap: () {
                  if (petId != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PetEditScreen(petId: petId!),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('반려동물 정보를 찾을 수 없습니다.')),
                    );
                  }
                },
                child: const Icon(Icons.edit, size: 18, color: Color(0xFF233554)),
              ),
            ],
          ),
        );
  }

  Widget _buildWalkList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 20, right: 20, bottom: 10),
          child: Text(
            '산책 기록',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF233554),
            ),
          ),
        ),
        const Divider(height: 1, thickness: 1, color: Colors.grey),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: (() {
              Query query = _firestore.collection('walk_records');
              if (widget.petId != null && widget.petId!.isNotEmpty) {
                query = query.where('pet_ids', arrayContains: widget.petId!);
              } else {
                query = query.where('user_id', isEqualTo: _uid);
              }
              return query.snapshots();
            })(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                // 인덱스 에러 등의 상세 내용을 보여주기보다 사용자 친화적인 메시지 출력
                return Center(child: Text('데이터를 불러오는 중 오류가 발생했습니다.\n${snapshot.error}')); 
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data?.docs.toList() ?? [];

              // 메모리 내에서 최신순 정렬
              docs.sort((a, b) {
                final aTime = (a.data() as Map<String, dynamic>)['start_time'] as Timestamp;
                final bTime = (b.data() as Map<String, dynamic>)['start_time'] as Timestamp;
                return bTime.compareTo(aTime);
              });

              if (docs.isEmpty) {
                return const Center(child: Text('산책 기록이 없습니다.'));
              }

              return ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: docs.length,
                separatorBuilder: (context, index) => const Divider(height: 1, thickness: 1, color: Colors.grey),
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final startTime = (data['start_time'] as Timestamp).toDate();
                  final endTime = (data['end_time'] as Timestamp).toDate();
                  final distanceKm = data['distance_km'] ?? 0.0;
                  final images = data['post_images'] as List<dynamic>?;
                  final firstImage = (images != null && images.isNotEmpty) ? images.first.toString() : null;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 산책 사진 (정사각형 박스)
                        GestureDetector(
                          onTap: () {
                            // 산책 기록 상세 페이지로 이동
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => WalkRecordDetailScreen(
                                  walkRecordId: docs[index].id,
                                  petId: widget.petId,
                                ),
                              ),
                            );
                          },
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFF233554), width: 0.5),
                              color: Colors.white,
                            ),
                            child: firstImage != null
                                ? Image.network(firstImage, fit: BoxFit.cover)
                                : const Center(
                                    child: Text(
                                      '산책 사진',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF233554),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        
                        // 정보 (날짜, 시간, 거리)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _formatDate(startTime),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF233554),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _formatTimeRange(startTime, endTime),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF233554),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '총 거리 : ${distanceKm.toString()}km',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF233554),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBottomButton() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20, top: 10),
      child: ElevatedButton(
        onPressed: () {
          Navigator.pop(context);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF233554),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(0),
          ),
          elevation: 0,
        ),
        child: const Text(
          '산책하기',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
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
    // 2번(산책) 탭을 활성화된 상태(흰색)로 표시
    final isSelected = index == 2; 
    return Column(
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
    );
  }

  Widget _buildCenterNavItem() {
    // 산책 아이콘 활성화 상태로 표시
    return Container(
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
