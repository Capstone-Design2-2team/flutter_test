import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class WalkRecordEditSimpleScreen extends StatefulWidget {
  final String walkRecordId;

  const WalkRecordEditSimpleScreen({super.key, required this.walkRecordId});

  @override
  State<WalkRecordEditSimpleScreen> createState() => _WalkRecordEditSimpleScreenState();
}

class _WalkRecordEditSimpleScreenState extends State<WalkRecordEditSimpleScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _picker = ImagePicker();
  
  Map<String, dynamic>? _walkRecord;
  bool _isLoading = true;
  bool _isSaving = false;
  
  late TextEditingController _memoController;
  String? _walkImageUrl;
  File? _newImage;
  List<String> _images = [];

  @override
  void initState() {
    super.initState();
    _loadWalkRecord();
  }

  Future<void> _loadWalkRecord() async {
    try {
      final walkDoc = await _firestore.collection('walk_records').doc(widget.walkRecordId).get();
      
      if (!walkDoc.exists) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final walkData = walkDoc.data()!;
      
      // 메모 텍스트 가져오기
      String memoText = '';
      if (walkData['post_memo'] != null) {
        memoText = walkData['post_memo'].toString();
      } else if (walkData['memo'] != null) {
        memoText = walkData['memo'].toString();
      }
      
      // 이미지 URL 가져오기
      _images.clear();
      if (walkData['post_images'] != null) {
        _images = List<String>.from(walkData['post_images']);
      } else if (walkData['images'] != null) {
        _images = List<String>.from(walkData['images']);
      }
      
      if (_images.isNotEmpty) {
        _walkImageUrl = _images.first;
      }

      setState(() {
        _walkRecord = walkData;
        _memoController = TextEditingController(text: memoText);
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading walk record: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _newImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      print('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('이미지 선택에 실패했습니다: $e')),
      );
    }
  }

  Future<void> _saveWalkRecord() async {
    setState(() => _isSaving = true);

    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('사용자 정보를 찾을 수 없습니다.');
      }

      Map<String, dynamic> updateData = {
        'post_memo': _memoController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // 이미지가 변경된 경우 처리
      if (_newImage != null) {
        // TODO: 실제 이미지 업로드 로직이 필요합니다.
        // 지금은 임시로 새 이미지가 선택되었다는 표시만 합니다.
        // 실제 프로덕션에서는 Firebase Storage에 이미지를 업로드해야 합니다.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이미지 업로드 기능은 준비 중입니다.')),
        );
      }

      await _firestore.collection('walk_records').doc(widget.walkRecordId).update(updateData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('산책 기록이 수정되었습니다.')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      print('Error saving walk record: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('수정에 실패했습니다: ${e.toString()}')),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _memoController.dispose();
    super.dispose();
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
          '산책기록 정보 수정',
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
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 페이지 제목
                      const Center(
                        child: Text(
                          '산책기록 정보 수정',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF233554),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 40),
                      
                      // 산책 사진 섹션
                      const Text(
                        '산책 사진',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // 사진 박스
                      GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          width: double.infinity,
                          height: 200,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!, width: 2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: _newImage != null
                                ? Image.file(
                                    _newImage!,
                                    width: double.infinity,
                                    height: 200,
                                    fit: BoxFit.cover,
                                  )
                                : _walkImageUrl != null && _walkImageUrl!.isNotEmpty
                                    ? Image.network(
                                        _walkImageUrl!,
                                        width: double.infinity,
                                        height: 200,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return _buildEmptyPhotoBox();
                                        },
                                      )
                                    : _buildEmptyPhotoBox(),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 40),
                      
                      // 메모 작성 섹션
                      const Text(
                        '메모 작성',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // 메모 입력 박스
                      Container(
                        width: double.infinity,
                        height: 120,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!, width: 2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: TextField(
                          controller: _memoController,
                          maxLines: 5,
                          decoration: const InputDecoration(
                            hintText: '메모를 입력하세요...',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.all(16),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 40),
                      
                      // 수정 버튼
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveWalkRecord,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF233554),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
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
                ),
    );
  }

  Widget _buildEmptyPhotoBox() {
    return Container(
      color: Colors.grey[100],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.camera_alt,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 8),
            const Text(
              '사진을 선택하세요',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '클릭하여 이미지 선택',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
