import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:teamproject/walk/walk_history_screen.dart';
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
  Map<String, dynamic>? _pet;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPets();
  }

  Future<void> _loadPets() async {
    try {
      print('PetConfirmationScreen: Loading pet with ID: ${widget.petId}');
      
      // petId 유효성 검사
      if (widget.petId == null || widget.petId.isEmpty) {
        print('PetConfirmationScreen: Invalid petId: ${widget.petId}');
        setState(() {
          _pet = null;
          _isLoading = false;
        });
        return;
      }
      
      final user = _auth.currentUser;
      if (user == null) {
        print('PetConfirmationScreen: No user logged in');
        setState(() => _isLoading = false);
        return;
      }
      print('PetConfirmationScreen: User logged in: ${user.uid}');

      // 선택된 반려동물 1마리만 불러오기
      final petDoc = await _firestore.collection('pets').doc(widget.petId).get();
      print('PetConfirmationScreen: Pet document exists: ${petDoc.exists}');
      
      if (!petDoc.exists) {
        print('PetConfirmationScreen: Pet not found with ID: ${widget.petId}');
        setState(() {
          _pet = null;
          _isLoading = false;
        });
        return;
      }
      
      final petData = petDoc.data();
      print('PetConfirmationScreen: Raw pet data: $petData');
      
      if (petData == null) {
        print('PetConfirmationScreen: Pet data is null');
        setState(() {
          _pet = null;
          _isLoading = false;
        });
        return;
      }
      
      // 데이터 형식 확인 및 변환
      final processedPet = {
        'id': petDoc.id,
        'name': petData['name'] ?? petData['pet_name'] ?? '이름 없음',
        'breed': petData['breed'] ?? petData['pet_breed'] ?? '품종 정보 없음',
        'imageUrl': petData['imageUrl'] ?? petData['photo_url'] ?? petData['image_url'] ?? '',
        'birthDate': petData['birthDate'] ?? petData['birth_date'],
        'gender': petData['gender'] ?? petData['pet_gender'],
        'weight': petData['weight'] ?? petData['pet_weight'],
        'isNeutered': petData['isNeutered'] ?? petData['is_neutered'] ?? false,
        'isRepresentative': petData['isRepresentative'] ?? petData['is_representative'] ?? false,
        'userId': petData['userId'] ?? petData['user_id'],
        'createdAt': petData['createdAt'] ?? petData['created_at'],
      };
      
      print('PetConfirmationScreen: Processed pet data: $processedPet');
      setState(() {
        _pet = processedPet;
        _isLoading = false;
      });
      
      print('PetConfirmationScreen: Pet loaded successfully');
    } catch (e, stackTrace) {
      print('PetConfirmationScreen: Error loading pets: $e');
      print('PetConfirmationScreen: Stack trace: $stackTrace');
      setState(() {
        _pet = null;
        _isLoading = false;
      });
    }
  }

  String _formatBirthDate(dynamic birthDate) {
    if (birthDate == null) return '생일 정보 없음';
    
    if (birthDate is Timestamp) {
      final date = birthDate.toDate();
      final now = DateTime.now();
      final age = now.year - date.year - (now.month < date.month || (now.month == date.month && now.day < date.day) ? 1 : 0);
      return '${age}세 (${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')})';
    }
    
    return '생일 정보 없음';
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
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications, color: Colors.white),
            onPressed: () {
              // 알람 기능
            },
          ),
        ],
        title: const Text(
          '반려동물 확인',
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
          : _pet == null
              ? _buildEmptyState()
              : _buildPetConfirmation(),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildPetConfirmation() {
    print('PetConfirmationScreen: _buildPetConfirmation called, _pet: $_pet');
    
    if (_pet == null) {
      print('PetConfirmationScreen: _pet is null, showing empty state');
      return _buildEmptyState();
    }
    
    final currentPet = _pet!;
    print('PetConfirmationScreen: Building pet confirmation with data: $currentPet');
    
    return SingleChildScrollView(
      child: Column(
        children: [
          // 반려동물 이미지 (전체 너비)
          Container(
            width: double.infinity,
            height: 300,
            child: currentPet['imageUrl'] != null && currentPet['imageUrl'].isNotEmpty
                ? Image.network(
                    currentPet['imageUrl'],
                    width: double.infinity,
                    height: 300,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      print('PetConfirmationScreen: Image loading error: $error');
                      return Container(
                        color: Colors.grey[200],
                        child: const Center(
                          child: Icon(
                            Icons.pets,
                            size: 80,
                            color: Colors.grey,
                          ),
                        ),
                      );
                    },
                  )
                : Container(
                    color: Colors.grey[200],
                    child: const Center(
                      child: Icon(
                        Icons.pets,
                        size: 80,
                        color: Colors.grey,
                      ),
                    ),
                  ),
          ),
          
          // 반려동물 정보 섹션
          Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // 이름
                _buildInfoField('이름', currentPet['name'] ?? '이름 없음'),
                
                // 품종
                _buildInfoField('품종', currentPet['breed'] ?? '정보 없음'),
                
                // 생년월일
                _buildInfoField('생년월일', _formatBirthDate(currentPet['birthDate'])),
                
                // 성별
                _buildInfoField('성별', currentPet['gender'] == 'male' ? '수컷' : (currentPet['gender'] == 'female' ? '암컷' : '정보 없음')),
                
                // 몸무게
                _buildInfoField('몸무게', '${currentPet['weight'] ?? '정보 없음'}kg'),
                
                // 중성화 여부
                _buildInfoField('중성화 여부', currentPet['isNeutered'] == true ? '완료' : (currentPet['isNeutered'] == false ? '안됨' : '정보 없음')),
              ],
            ),
          ),
          
          const SizedBox(height: 30),
          
          // 산책기록 확인 버튼
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  // 키보드 내리기
                  FocusScope.of(context).unfocus();
                  
                  final petId = currentPet['id'];
                  print('PetConfirmationScreen: Button pressed, petId: $petId');
                  if (petId != null && petId.isNotEmpty) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => WalkHistoryScreen(),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('반려동물 정보를 찾을 수 없습니다.')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF233554),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  '산책기록 확인',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildWalkInfoRow(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.pets_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            '등록된 반려동물이 없습니다',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '마이페이지에서 반려동물을 등록해주세요',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'PetId: ${widget.petId}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoField(String label, String value) {
    final isRepresentative = _pet?['isRepresentative'] == true;
    final showRepresentativeBadge = label == '이름' && isRepresentative;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 라벨
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          // 값
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                ),
                if (showRepresentativeBadge) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF233554),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      '대표',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoColumn(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 라벨
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF233554),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // 값
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          // 라벨
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF233554),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // 구분선
          Container(
            width: 1,
            height: 20,
            color: Colors.grey[300],
          ),
          const SizedBox(width: 16),
          // 값
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
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
