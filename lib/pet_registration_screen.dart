import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';

class PetRegistrationScreen extends StatefulWidget {
  const PetRegistrationScreen({super.key});

  @override
  State<PetRegistrationScreen> createState() => _PetRegistrationScreenState();
}

class _PetRegistrationScreenState extends State<PetRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  File? _petImage;
  Uint8List? _webImage;
  String _petName = '';
  String _breed = '';
  DateTime? _birthDate;
  String _gender = '';
  String _weight = '';
  bool _isNeutered = false;
  bool _isLoading = false;
  bool _isWeightUnknown = false;
  bool _showBreedTextField = false;
  String _customBreed = '';
  final _breedTextFieldController = TextEditingController();

  final List<String> _breeds = [
    '진돗개', '삽살개', '포메라니안', '치와와', '말티즈', '비글', '시츄', '코기',
    '푸들', '닥스훈트', '골든리트리버', '래브라도리트리버', '비숑프리제', '셰퍼드',
    '도베르만', '로트와일러', '기타', '모르겠음'
  ];

  @override
  void initState() {
    super.initState();
    _birthDate = DateTime.now();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        if (pickedFile.path.startsWith('http')) {
          // Web case
          final bytes = await pickedFile.readAsBytes();
          setState(() {
            _webImage = bytes;
            _petImage = null;
          });
        } else {
          // Mobile case
          setState(() {
            _petImage = File(pickedFile.path);
            _webImage = null;
          });
        }
      }
    } catch (e) {
      _showErrorDialog('이미지를 선택하는 중 오류가 발생했습니다: $e');
    }
  }

  Future<String?> _uploadImage() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      String fileName = 'pet_${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference ref = _storage.ref().child('pet_images').child(fileName);

      UploadTask uploadTask;
      if (_petImage != null) {
        uploadTask = ref.putFile(_petImage!);
      } else if (_webImage != null) {
        uploadTask = ref.putData(_webImage!);
      } else {
        return null;
      }

      TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('Image upload error: $e');
      return null;
    }
  }

  Future<void> _registerPet() async {
    // 순차적 예외처리
    if (_petImage == null && _webImage == null) {
      _showErrorDialog('반려동물 사진을 추가해주세요.');
      return;
    }
    if (_petName.isEmpty) {
      _showErrorDialog('반려동물 이름을 입력해주세요.');
      return;
    }
    if (_breed.isEmpty) {
      _showErrorDialog('품종을 선택해주세요.');
      return;
    }
    if (_breed == '기타(모름)' && _customBreed.isEmpty) {
      _showErrorDialog('품종을 직접 입력해주세요.');
      return;
    }
    if (_gender.isEmpty) {
      _showErrorDialog('성별을 선택해주세요.');
      return;
    }
    if (_weight.isEmpty && !_isWeightUnknown) {
      _showErrorDialog('몸무게를 입력해주세요.');
      return;
    }
    if (_weight.isNotEmpty && !_isWeightUnknown) {
      try {
        double weight = double.parse(_weight);
        if (weight <= 0 || weight > 200) {
          _showErrorDialog('올바른 몸무게를 입력해주세요 (0.1kg ~ 200kg).');
          return;
        }
      } catch (e) {
        _showErrorDialog('올바른 숫자 형식의 몸무게를 입력해주세요.');
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) {
        _showErrorDialog('로그인이 필요합니다.');
        return;
      }

      String? imageUrl;
      if (_petImage != null || _webImage != null) {
        imageUrl = await _uploadImage();
      }

      String finalBreed = _breed;
      if (_breed == '기타(모름)' && _customBreed.isNotEmpty) {
        finalBreed = _customBreed;
      }

      Map<String, dynamic> petData = {
        'userId': user.uid,
        'name': _petName,
        'breed': finalBreed,
        'birthDate': _birthDate != null ? Timestamp.fromDate(_birthDate!) : null,
        'gender': _gender,
        'weight': _isWeightUnknown ? '모르겠음' : _weight,
        'isNeutered': _isNeutered,
        'imageUrl': imageUrl,
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      };

      await _firestore.collection('pets').add(petData);

      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      _showErrorDialog('반려동물 등록 중 오류가 발생했습니다: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('오류'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('성공'),
        content: const Text('반려동물 정보가 성공적으로 등록되었습니다.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime.now(),
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _birthDate) {
      setState(() {
        _birthDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF233554),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '반려동물 정보 등록',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 반려동물 사진
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: _petImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              _petImage!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                          )
                        : _webImage != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.memory(
                                  _webImage!,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                ),
                              )
                            : const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add, size: 40, color: Colors.grey),
                                  Text('사진 추가', style: TextStyle(color: Colors.grey)),
                                ],
                              ),
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // 반려동물 이름
              _buildLabel('반려동물 이름'),
              _buildTextField(
                '이름을 입력하세요',
                (value) => _petName = value,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '이름을 입력해주세요.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // 품종
              _buildLabel('품종'),
              _buildDropdown(),
              if (_showBreedTextField) ...[
                const SizedBox(height: 10),
                _buildTextField(
                  '직접 품종을 입력하세요',
                  (value) => _customBreed = value,
                  validator: (value) {
                    if (_breed == '기타' && (value == null || value.isEmpty)) {
                      return '품종을 입력해주세요.';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 20),

              // 생년월일
              _buildLabel('생년월일'),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _selectDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, color: Colors.grey),
                            const SizedBox(width: 10),
                            Text(
                              _birthDate != null
                                  ? '${_birthDate!.year}-${_birthDate!.month.toString().padLeft(2, '0')}-${_birthDate!.day.toString().padLeft(2, '0')}'
                                  : '날짜를 선택하세요',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () => setState(() => _birthDate = null),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _birthDate == null ? const Color(0xFF233554) : Colors.grey[200],
                      foregroundColor: _birthDate == null ? Colors.white : Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                    ),
                    child: const Text('모르겠음'),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 성별
              _buildLabel('성별'),
              Row(
                children: [
                  Expanded(
                    child: _buildGenderButton('남아', 'male'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildGenderButton('여아', 'female'),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 몸무게
              _buildLabel('몸무게'),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      '몸무게를 입력하세요 (kg)',
                      (value) => _weight = value,
                      keyboardType: TextInputType.number,
                      enabled: !_isWeightUnknown,
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () => setState(() => _isWeightUnknown = !_isWeightUnknown),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isWeightUnknown ? const Color(0xFF233554) : Colors.grey[200],
                      foregroundColor: _isWeightUnknown ? Colors.white : Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                    ),
                    child: const Text('모르겠음'),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 중성화 여부
              _buildLabel('중성화 여부'),
              Row(
                children: [
                  Expanded(
                    child: _buildNeuteredButton('했음', true),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildNeuteredButton('안했음', false),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              // 등록 버튼
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _registerPet,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF233554),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          '등록',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTextField(
    String hint,
    Function(String) onChanged, {
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool? enabled,
  }) {
    return TextFormField(
      decoration: InputDecoration(
        hintText: hint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF233554)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      ),
      onChanged: onChanged,
      validator: validator,
      keyboardType: keyboardType,
      enabled: enabled ?? true,
    );
  }

  Widget _buildDropdown() {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        hintText: '품종을 선택하세요',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF233554)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      ),
      items: _breeds.map((String breed) {
        return DropdownMenuItem<String>(
          value: breed,
          child: Text(breed),
        );
      }).toList(),
      onChanged: (String? value) {
        if (value != null) {
          setState(() {
            _breed = value;
            if (value == '기타') {
              _showBreedTextField = true;
            } else if (value == '모르겠음') {
              _showBreedTextField = false;
              _customBreed = '모르겠음';
            } else {
              _showBreedTextField = false;
              _customBreed = '';
            }
          });
        }
      },
    );
  }

  Widget _buildGenderButton(String label, String value) {
    return ElevatedButton(
      onPressed: () => setState(() => _gender = value),
      style: ElevatedButton.styleFrom(
        backgroundColor: _gender == value ? const Color(0xFF233554) : Colors.grey[200],
        foregroundColor: _gender == value ? Colors.white : Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(label),
    );
  }

  Widget _buildNeuteredButton(String label, bool value) {
    return ElevatedButton(
      onPressed: () => setState(() => _isNeutered = value),
      style: ElevatedButton.styleFrom(
        backgroundColor: _isNeutered == value ? const Color(0xFF233554) : Colors.grey[200],
        foregroundColor: _isNeutered == value ? Colors.white : Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(label),
    );
  }
}
