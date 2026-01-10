import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RepresentativePetScreen extends StatefulWidget {
  const RepresentativePetScreen({super.key});

  @override
  State<RepresentativePetScreen> createState() => _RepresentativePetScreenState();
}

class _RepresentativePetScreenState extends State<RepresentativePetScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Map<String, dynamic>> _pets = [];
  String? _selectedPetId;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadPets();
  }

  Future<void> _loadPets() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('No authenticated user found');
        setState(() => _isLoading = false);
        return;
      }

      print('Loading pets for user: ${user.uid}');

      // 사용자의 반려동물 목록 가져오기
      final petsSnapshot = await _firestore
          .collection('pets')
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: false)
          .get();

      print('Found ${petsSnapshot.docs.length} pets');

      // 모든 pets 문서 확인
      for (var doc in petsSnapshot.docs) {
        print('Document ID: ${doc.id}, Data: ${doc.data()}');
      }

      List<Map<String, dynamic>> pets = [];
      String? selectedPetId;

      for (var doc in petsSnapshot.docs) {
        final petData = doc.data();
        print('Processing pet: ${petData}');
        
        pets.add({
          'id': doc.id,
          'name': petData['name'] ?? petData['pet_name'] ?? '펫',
          'breed': petData['breed'] ?? '품종 정보 없음',
          'imageUrl': petData['imageUrl'] ?? petData['photo_url'] ?? petData['image_url'] ?? '',
          'isRepresentative': petData['isRepresentative'] ?? false,
        });

        // 현재 대표 반려동물 ID 찾기
        if (petData['isRepresentative'] == true) {
          selectedPetId = doc.id;
          print('Found representative pet: $selectedPetId');
        }
      }

      setState(() {
        _pets = pets;
        _selectedPetId = selectedPetId;
        _isLoading = false;
      });

      print('Final pets list: $_pets');
      print('Loaded ${pets.length} pets, selected: $selectedPetId');
    } catch (e) {
      print('Error loading pets: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveRepresentativePet() async {
    if (_selectedPetId == null) return;

    setState(() => _isSaving = true);

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      print('Saving representative pet: $_selectedPetId');

      // 모든 반려동물의 isRepresentative를 false로 초기화
      for (var pet in _pets) {
        print('Updating pet ${pet['id']} to isRepresentative: false');
        await _firestore.collection('pets').doc(pet['id']).update({
          'isRepresentative': false,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // 선택된 반려동물을 대표로 설정
      print('Setting pet $_selectedPetId as representative');
      await _firestore.collection('pets').doc(_selectedPetId).update({
        'isRepresentative': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('대표 반려동물이 설정되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context, true);
      }
    } catch (e) {
      print('Error saving representative pet: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('대표 반려동물 설정에 실패했습니다.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
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
          '대표 반려동물 선택',
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
          : _pets.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.pets,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        '등록된 반려동물이 없습니다',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
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
                  children: [
                    SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100]!,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Debug Info:',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text('User ID: ${_auth.currentUser?.uid ?? "null"}'),
                          Text('Pets Found: ${_pets.length}'),
                          Text('Selected Pet: $_selectedPetId'),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _pets.length,
                        itemBuilder: (context, index) {
                          final pet = _pets[index];
                          return _buildPetCard(pet);
                        },
                      ),
                    ),
                    _buildSaveButton(),
                  ],
                ),
    );
  }

  Widget _buildPetCard(Map<String, dynamic> pet) {
    final isSelected = _selectedPetId == pet['id'];
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF233554).withOpacity(0.1) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? const Color(0xFF233554) : const Color(0xFFE0E0E0),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedPetId = pet['id'];
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            // 반려동물 이미지
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[300],
              ),
              child: pet['imageUrl'] != null && pet['imageUrl'].isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: Image.network(
                        pet['imageUrl'],
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.pets,
                            size: 30,
                            color: Colors.grey,
                          );
                        },
                      ),
                    )
                  : const Icon(
                      Icons.pets,
                      size: 30,
                      color: Colors.grey,
                    ),
            ),
            const SizedBox(width: 16),

            // 반려동물 정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        pet['name'],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? const Color(0xFF233554) : Colors.black,
                        ),
                      ),
                      if (pet['isRepresentative'] == true) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF233554),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            '대표',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    pet['breed'],
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

            // 선택 표시
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? const Color(0xFF233554) : Colors.white,
                border: Border.all(
                  color: isSelected ? const Color(0xFF233554) : Colors.grey,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      size: 16,
                      color: Colors.white,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: _isSaving ? null : _saveRepresentativePet,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF233554),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text(
                  '대표 반려동물로 설정',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
        ),
      ),
    );
  }
}
