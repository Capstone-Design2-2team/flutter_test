import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:teamproject/user_service.dart';
import 'package:teamproject/pet_update_service.dart';

class PetEditScreen extends StatefulWidget {
  final String petId;
  final VoidCallback? onPetUpdated;
  
  const PetEditScreen({super.key, required this.petId, this.onPetUpdated});

  @override
  State<PetEditScreen> createState() => _PetEditScreenState();
}

class _PetEditScreenState extends State<PetEditScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _picker = ImagePicker();
  
  Map<String, dynamic>? _pet;
  bool _isLoading = true;
  bool _isSaving = false;
  
  // Form controllers
  late TextEditingController _nameController;
  late TextEditingController _breedController;
  late TextEditingController _weightController;
  late TextEditingController _customBreedController;
  DateTime? _birthDate;
  String? _gender;
  bool? _isNeutered;
  String? _imageUrl;
  File? _newImage;
  bool _showCustomBreedInput = false;
  bool _weightUnknown = false;

  @override
  void initState() {
    super.initState();
    _loadPetData();
  }

  Future<void> _loadPetData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      final petDoc = await _firestore.collection('pets').doc(widget.petId).get();
      if (!petDoc.exists) {
        setState(() => _isLoading = false);
        return;
      }

      final petData = petDoc.data()!;
      setState(() {
        _pet = {'id': petDoc.id, ...petData};
        _nameController = TextEditingController(text: petData['name']?.toString() ?? '');
        _breedController = TextEditingController(text: petData['breed']?.toString() ?? '');
        _weightController = TextEditingController(text: petData['weight']?.toString() ?? '');
        _customBreedController = TextEditingController();
        
        // 몸무게 처리
        final weight = petData['weight']?.toString() ?? '';
        if (weight.isEmpty || weight == '모르겠음' || weight == '0') {
          _weightUnknown = true;
          _weightController.text = '';
        } else {
          _weightUnknown = false;
          _weightController.text = weight;
        }
        
        // 생년월일 처리
        if (petData['birthDate'] != null && petData['birthDate'] is Timestamp) {
          _birthDate = (petData['birthDate'] as Timestamp).toDate();
        }
        
        _gender = petData['gender']?.toString();
        _isNeutered = petData['isNeutered'] as bool?;
        _imageUrl = petData['imageUrl']?.toString();
        
        // 품종이 기타(직접입력)인 경우 커스텀 입력 필드 표시
        final breed = petData['breed']?.toString() ?? '';
        final predefinedBreeds = ['골든 리트리버', '진돗', '치와와', '포메라니안', '믹스견', '모르겠음'];
        
        if (breed == '기타(직접입력)' || !predefinedBreeds.contains(breed)) {
          _showCustomBreedInput = true;
          _customBreedController.text = breed;
          _breedController.text = '기타(직접입력)';
        } else {
          _showCustomBreedInput = false;
          _breedController.text = breed;
        }
        
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading pet data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _newImage = File(pickedFile!.path);
        });
      }
    } catch (e) {
      print('Error picking image: $e');
    }
  }

  Future<void> _savePet() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('반려동물 이름을 입력해주세요.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      Map<String, dynamic> updateData = {
        'name': _nameController.text.trim(),
        'breed': _breedController.text.trim(),
        'weight': _weightUnknown ? '모르겠음' : (double.tryParse(_weightController.text) ?? 0.0),
        'gender': _gender,
        'isNeutered': _isNeutered,
        'birthDate': _birthDate != null ? Timestamp.fromDate(_birthDate!) : null,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // TODO: 이미지 업로드 로직 추가 필요
      // if (_newImage != null) {
      //   String imageUrl = await _uploadImage(_newImage);
      //   updateData['imageUrl'] = imageUrl;
      // }

      await _firestore.collection('pets').doc(widget.petId).update(updateData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('반려동물 정보가 수정되었습니다.')),
        );
        // Call the callback to notify other screens
        widget.onPetUpdated?.call();
        // Notify global listeners
        PetUpdateService().notifyPetUpdated();
        Navigator.pop(context);
      }
    } catch (e) {
      print('Error saving pet: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('정보 수정에 실패했습니다.')),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _deletePet() async {
    bool? confirm = await _showDeleteConfirmDialog();
    if (confirm != true) return;

    setState(() => _isSaving = true);

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore.collection('pets').doc(widget.petId).delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('반려동물 정보가 삭제되었습니다.')),
        );
        // Call the callback to notify other screens
        widget.onPetUpdated?.call();
        // Notify global listeners
        PetUpdateService().notifyPetUpdated();
        Navigator.pop(context);
      }
    } catch (e) {
      print('Error deleting pet: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('삭제에 실패했습니다.')),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<bool?> _showDeleteConfirmDialog() async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('반려동물 삭제'),
        content: const Text('정말로 이 반려동물 정보를 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
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
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 섹션 제목
                  const Text(
                    '반려동물 정보 수정',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF233554),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 반려동물 사진
                  _buildPhotoSection(),
                  const SizedBox(height: 20),

                  // 반려동물 이름
                  _buildTextField('반려동물 이름', _nameController),
                  const SizedBox(height: 20),

                  // 품종
                  _buildBreedField(),
                  const SizedBox(height: 20),

                  // 생년월일
                  _buildBirthDateField(),
                  const SizedBox(height: 20),

                  // 성별
                  _buildGenderField(),
                  const SizedBox(height: 20),

                  // 몸무게
                  _buildWeightField(),
                  const SizedBox(height: 20),

                  // 중성화 여부
                  _buildNeuteredField(),
                  const SizedBox(height: 40),

                  // 버튼들
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _savePet,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF233554),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
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
                                  '수정',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isSaving ? null : _deletePet,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF233554),
                            side: const BorderSide(color: Color(0xFF233554)),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            '삭제',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '반려동물 사진',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _newImage != null
                  ? Image.file(
                      _newImage!,
                      width: 120,
                      height: 120,
                      fit: BoxFit.cover,
                    )
                  : _imageUrl != null && _imageUrl!.isNotEmpty
                      ? Image.network(
                          _imageUrl!,
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[200],
                              child: const Center(
                                child: Icon(
                                  Icons.pets,
                                  size: 40,
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
                              Icons.camera_alt,
                              size: 40,
                              color: Colors.grey,
                            ),
                          ),
                        ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {TextInputType? keyboardType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF233554)),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildBreedField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '품종',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _showCustomBreedInput ? '기타(직접입력)' : 
                     (_breedController.text.isNotEmpty && 
                      ['골든 리트리버', '진돗', '치와와', '포메라니안', '믹스견', '모르겠음', '기타(직접입력)'].contains(_breedController.text)) 
                      ? _breedController.text : null,
              hint: const Text('품종을 선택하세요'),
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: '골든 리트리버', child: Text('골든 리트리버')),
                DropdownMenuItem(value: '진돗', child: Text('진돗')),
                DropdownMenuItem(value: '치와와', child: Text('치와와')),
                DropdownMenuItem(value: '포메라니안', child: Text('포메라니안')),
                DropdownMenuItem(value: '믹스견', child: Text('믹스견')),
                DropdownMenuItem(value: '기타(직접입력)', child: Text('기타(직접입력)')),
                DropdownMenuItem(value: '모르겠음', child: Text('모르겠음')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _breedController.text = value;
                    if (value == '기타(직접입력)') {
                      _showCustomBreedInput = true;
                    } else {
                      _showCustomBreedInput = false;
                      _customBreedController.clear();
                    }
                  });
                }
              },
            ),
          ),
        ),
        
        // 커스텀 품종 입력 필드
        if (_showCustomBreedInput) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextField(
              controller: _customBreedController,
              style: const TextStyle(
                overflow: TextOverflow.ellipsis,
              ),
              decoration: const InputDecoration(
                hintText: '품종을 직접 입력하세요',
                border: InputBorder.none,
                hintStyle: TextStyle(
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              onChanged: (value) {
                _breedController.text = value;
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBirthDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '생년월일',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _birthDate ?? DateTime.now(),
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    setState(() {
                      _birthDate = date;
                    });
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Text(
                        _birthDate != null
                            ? '${_birthDate!.year}-${_birthDate!.month.toString().padLeft(2, '0')}-${_birthDate!.day.toString().padLeft(2, '0')}'
                            : '생년월일을 선택하세요',
                        style: TextStyle(
                          fontSize: 16,
                          color: _birthDate != null ? Colors.black87 : Colors.grey,
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.calendar_today, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: () {
                setState(() {
                  _birthDate = null;
                });
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF233554),
                side: const BorderSide(color: Color(0xFF233554)),
              ),
              child: const Text('모르겠음'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWeightField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '몸무게',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _weightController,
                keyboardType: TextInputType.number,
                enabled: !_weightUnknown,
                style: const TextStyle(
                  overflow: TextOverflow.ellipsis,
                ),
                decoration: InputDecoration(
                  hintText: '몸무게를 입력하세요 (kg)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: _weightUnknown ? Colors.grey[300]! : Colors.grey[300]!,
                    ),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  hintStyle: const TextStyle(
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: () {
                setState(() {
                  _weightUnknown = !_weightUnknown;
                  if (_weightUnknown) {
                    _weightController.text = '';
                  }
                });
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: _weightUnknown ? Colors.white : const Color(0xFF233554),
                backgroundColor: _weightUnknown ? const Color(0xFF233554) : Colors.transparent,
                side: const BorderSide(color: Color(0xFF233554)),
              ),
              child: const Text('모르겠음'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGenderField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '성별',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _gender = 'male';
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _gender == 'male' ? const Color(0xFF233554) : Colors.transparent,
                    border: Border.all(color: const Color(0xFF233554)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '남아',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _gender == 'male' ? Colors.white : const Color(0xFF233554),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _gender = 'female';
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _gender == 'female' ? const Color(0xFF233554) : Colors.transparent,
                    border: Border.all(color: const Color(0xFF233554)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '여아',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _gender == 'female' ? Colors.white : const Color(0xFF233554),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNeuteredField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '중성화 여부',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _isNeutered = true;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _isNeutered == true ? const Color(0xFF233554) : Colors.transparent,
                    border: Border.all(color: const Color(0xFF233554)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '했음',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _isNeutered == true ? Colors.white : const Color(0xFF233554),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _isNeutered = false;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _isNeutered == false ? const Color(0xFF233554) : Colors.transparent,
                    border: Border.all(color: const Color(0xFF233554)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '안했음',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _isNeutered == false ? Colors.white : const Color(0xFF233554),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    _weightController.dispose();
    _customBreedController.dispose();
    super.dispose();
  }
}
