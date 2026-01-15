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
  List<String> _debugInfo = [];

  @override
  void initState() {
    super.initState();
    _loadPets();
    
    // 파이어베이스 실시간 감지 설정
    _setupRealtimeListeners();
  }

  void _setupRealtimeListeners() {
    final user = _auth.currentUser;
    if (user == null) return;
    
    print('Setting up realtime listener for user: ${user.uid}');
    
    // 반려동물 실시간 감지 - 추가, 수정, 삭제 모두 감지
    _firestore
        .collection('pets')
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .listen((snapshot) {
          if (mounted) {
            print('Realtime update detected: ${snapshot.docChanges.length} changes');
            
            for (var change in snapshot.docChanges) {
              print('  - Doc: ${change.doc.id}, Type: ${change.type}');
              
              if (change.type == DocumentChangeType.added) {
                print('  → New pet added: ${change.doc.id}');
              } else if (change.type == DocumentChangeType.modified) {
                print('  → Pet modified: ${change.doc.id}');
              } else if (change.type == DocumentChangeType.removed) {
                print('  → Pet removed: ${change.doc.id}');
              }
            }
            
            // 데이터 변경 시 전체 목록 다시 로드
            _loadPets();
          }
        });
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
      
      // 간단한 쿼리로 pets 가져오기
      print('=== DEBUG: Simple query approach ===');
      final petsSnapshot = await _firestore
          .collection('pets')
          .where('userId', isEqualTo: user.uid)
          .get();

      print('Query result: ${petsSnapshot.docs.length} pets found');
      
      List<String> debugInfo = [];
      debugInfo.add('Query result: ${petsSnapshot.docs.length} pets');
      
      // 모든 문서 직접 처리
      List<Map<String, dynamic>> pets = [];
      String? selectedPetId;

      for (var doc in petsSnapshot.docs) {
        try {
          final petData = doc.data() as Map<String, dynamic>;
          print('Processing document: ${doc.id}');
          
          pets.add({
            'id': doc.id,
            'name': petData['name'] ?? petData['pet_name'] ?? '펫',
            'breed': petData['breed'] ?? petData['pet_breed'] ?? '품종 정보 없음',
            'imageUrl': petData['imageUrl'] ?? petData['photo_url'] ?? petData['image_url'] ?? '',
            'isRepresentative': petData['isRepresentative'] ?? petData['is_representative'] ?? false,
          });
          
          debugInfo.add('Pet: ${petData['name'] ?? petData['pet_name']}');
          
          // 현재 대표 반려동물 ID 찾기
          if ((petData['isRepresentative'] ?? petData['is_representative'] ?? false) == true) {
            selectedPetId = doc.id;
            debugInfo.add('Found representative: $selectedPetId');
          }
        } catch (e) {
          print('Error processing document ${doc.id}: $e');
          debugInfo.add('Error processing ${doc.id}: $e');
          continue;
        }
      }
      
      print('Final result: ${pets.length} pets processed');
      
      setState(() {
        _debugInfo = debugInfo;
        _pets = pets;
        _selectedPetId = selectedPetId;
        _isLoading = false;
      });
      
      print('State updated successfully');
      
    } catch (e) {
      print('Error loading pets: $e');
      print('Stack trace: ${StackTrace.current}');
      setState(() {
        _debugInfo = ['Error: $e'];
        _pets = [];
        _selectedPetId = null;
        _isLoading = false;
      });
    }
  }

  Future<void> _processPetData(List<QueryDocumentSnapshot> docs, String userUid) async {
    try {
      List<Map<String, dynamic>> pets = [];
      String? selectedPetId;

      print('Processing ${docs.length} pet documents...');

      // 데이터 처리 로직
      for (var doc in docs) {
        try {
          final petData = doc.data() as Map<String, dynamic>;
          if (petData.isEmpty) {
            print('Warning: Document ${doc.id} has empty data');
            continue;
          }
          
          print('Processing pet: ${doc.id}, name: ${petData['name'] ?? petData['pet_name']}');
          
          pets.add({
            'id': doc.id,
            'name': petData['name'] ?? petData['pet_name'] ?? '펫',
            'breed': petData['breed'] ?? petData['pet_breed'] ?? '품종 정보 없음',
            'imageUrl': petData['imageUrl'] ?? petData['photo_url'] ?? petData['image_url'] ?? '',
            'isRepresentative': petData['isRepresentative'] ?? petData['is_representative'] ?? false,
          });
          
          // 현재 대표 반려동물 ID 찾기
          if ((petData['isRepresentative'] ?? petData['is_representative'] ?? false) == true) {
            selectedPetId = doc.id;
            print('Found representative pet: $selectedPetId');
          }
        } catch (e) {
          print('Error processing document ${doc.id}: $e');
          continue;
        }
      }
      
      print('Final pets list length: ${pets.length}');
      print('Selected pet ID: $selectedPetId');
      
      setState(() {
        _pets = pets;
        _selectedPetId = selectedPetId;
        _isLoading = false;
      });
      
      print('State updated. Pets: ${_pets.length}, Selected: $_selectedPetId');
    } catch (e) {
      print('Error in _processPetData: $e');
      print('Stack trace: ${StackTrace.current}');
      setState(() {
        _pets = [];
        _selectedPetId = null;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveRepresentativePet() async {
    print('Save button clicked. SelectedPetId: $_selectedPetId');
    print('Total pets available: ${_pets.length}');
    
    if (_selectedPetId == null) {
      print('No pet selected - showing warning');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('대표 반려동물을 선택해주세요.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    print('Pet selected: $_selectedPetId - proceeding with save');
    setState(() => _isSaving = true);

    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('No authenticated user found');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('사용자 인증에 실패했습니다.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      print('Saving representative pet: $_selectedPetId for user: ${user.uid}');

      // 선택된 반려동물만 대표로 설정 (다른 반려동물은 그대로 둠)
      print('Step 1: Setting pet $_selectedPetId as representative');
      try {
        Map<String, dynamic> updateData = {
          'isRepresentative': true,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        
        print('Updating document $_selectedPetId with data: $updateData');
        
        await _firestore.collection('pets').doc(_selectedPetId).update(updateData);
        print('✓ Successfully set pet $_selectedPetId as representative');
        
      } catch (e) {
        print('✗ Error setting representative pet: $e');
        print('Document ID: $_selectedPetId');
        print('Collection: pets');
        
        // 문서가 존재하는지 확인
        try {
          final docSnapshot = await _firestore.collection('pets').doc(_selectedPetId).get();
          if (docSnapshot.exists) {
            print('Document exists, data: ${docSnapshot.data()}');
          } else {
            print('Document does not exist!');
          }
        } catch (docError) {
          print('Error checking document existence: $docError');
        }
        
        throw e;
      }

      print('Save operation completed successfully');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('대표 반려동물이 설정되었습니다.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        print('Navigating back to previous screen');
        Navigator.pop(context, true);
      }
    } catch (e) {
      print('Error saving representative pet: $e');
      print('Stack trace: ${StackTrace.current}');
      
      String errorMessage = '대표 반려동물 설정에 실패했습니다';
      
      // 더 구체적인 에러 메시지 제공
      if (e.toString().contains('permission-denied')) {
        errorMessage = '권한이 없습니다. 다시 로그인해주세요.';
      } else if (e.toString().contains('not-found')) {
        errorMessage = '반려동물 정보를 찾을 수 없습니다.';
      } else if (e.toString().contains('unavailable')) {
        errorMessage = '네트워크 연결을 확인해주세요.';
      } else {
        errorMessage = '오류가 발생했습니다: ${e.toString()}';
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
            action: SnackBarAction(
              label: '재시도',
              textColor: Colors.white,
              onPressed: () {
                _saveRepresentativePet(); // 재시도
              },
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
        print('Save process completed, isSaving reset to false');
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        '등록된 반려동물 (${_pets.length})',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF233554),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
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
    
    print('Building pet card for: ${pet['name']} (ID: ${pet['id']}), Selected: $isSelected');
    
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
          print('Tapped pet: ${pet['name']} (ID: ${pet['id']})');
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
                          print('Image load error for ${pet['name']}: $error');
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
                        pet['name']?.toString() ?? '이름 없음',
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
                    pet['breed']?.toString() ?? '품종 정보 없음',
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
