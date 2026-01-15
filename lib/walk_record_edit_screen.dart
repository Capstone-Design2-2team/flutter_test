import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class WalkRecordEditScreen extends StatefulWidget {
  final String recordId;
  final Map<String, dynamic> recordData;

  const WalkRecordEditScreen({
    super.key,
    required this.recordId,
    required this.recordData,
  });

  @override
  State<WalkRecordEditScreen> createState() => _WalkRecordEditScreenState();
}

class _WalkRecordEditScreenState extends State<WalkRecordEditScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _imagePicker = ImagePicker();

  late TextEditingController _memoController;
  bool _isLoading = false;
  List<String> _imageUrls = [];
  String? _selectedImageUrl; // 현재 선택된 이미지 URL

  @override
  void initState() {
    super.initState();
    _memoController = TextEditingController(
      text: widget.recordData['memo'] ?? '',
    );
    _initializeImages();
  }

  void _initializeImages() {
    // 다양한 이미지 필드명에서 이미지 가져오기
    List<String> imageFields = ['postImages', 'post_images', 'images', 'photos', 'walk_images', 'walkImages'];
    
    for (String field in imageFields) {
      if (widget.recordData[field] != null) {
        final images = widget.recordData[field] as List<dynamic>?;
        if (images != null && images.isNotEmpty) {
          _imageUrls = images.map((e) => e.toString()).toList();
          print('DEBUG: Found images in field $field: ${_imageUrls.length}');
          break;
        }
      }
    }
    
    print('DEBUG: Final image URLs: $_imageUrls');
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 600,
        imageQuality: 80,
      );

      if (image != null) {
        // TODO: Firebase Storage에 이미지 업로드 로직 추가
        // 지금은 임시로 로컬 이미지를 표시만 함
        setState(() {
          _selectedImageUrl = image.path;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('이미지가 선택되었습니다. Firebase 업로드 기능은 준비 중입니다.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('이미지 선택 중 오류가 발생했습니다.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showImagePickerOptions() async {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '사진 선택',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('갤러리에서 선택'),
              onTap: () {
                Navigator.pop(context);
                _pickImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('카메라로 촬영'),
              onTap: () {
                Navigator.pop(context);
                _pickImageFromCamera();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImageFromCamera() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800,
        maxHeight: 600,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _selectedImageUrl = image.path;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('이미지가 촬영되었습니다. Firebase 업로드 기능은 준비 중입니다.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('Error taking picture: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('사진 촬영 중 오류가 발생했습니다.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _saveRecord() async {
    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // 메모만 업데이트
      await _firestore.collection('walk_records').doc(widget.recordId).update({
        'memo': _memoController.text,
        'updatedAt': Timestamp.now(),
      });

      // 수정 성공 시 true 반환
      Navigator.pop(context, true);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('산책기록이 수정되었습니다.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error updating record: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('수정 중 오류가 발생했습니다.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: const Color(0xFF233554),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: 16,
                        right: 16,
                        top: 16,
                        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 산책 사진 섹션
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '산책 사진',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // 사진 표시 및 수정 영역
                          Container(
                            width: double.infinity,
                            height: 200,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Stack(
                              children: [
                                // 기존 사진 또는 선택된 사진 표시
                                GestureDetector(
                                  onTap: _showImagePickerOptions,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: _buildImageDisplay(),
                                  ),
                                ),
                                
                                // 사진 수정 안내 텍스트
                                if (_imageUrls.isEmpty && _selectedImageUrl == null)
                                  Positioned.fill(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        color: Colors.black.withOpacity(0.3),
                                      ),
                                      child: const Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.add_photo_alternate,
                                              size: 50,
                                              color: Colors.white,
                                            ),
                                            SizedBox(height: 8),
                                            Text(
                                              '클릭하여 사진 추가',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.white,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                
                                // 이미지 개수 표시 (여러 장일 경우)
                                if (_imageUrls.isNotEmpty && _imageUrls.length > 1)
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.7),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${_imageUrls.length}장',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // 메모 섹션
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '메모',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          TextField(
                            controller: _memoController,
                            decoration: const InputDecoration(
                              hintText: '산책에 대한 메모를 남겨주세요',
                              border: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.grey),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Color(0xFF233554)),
                              ),
                              contentPadding: EdgeInsets.all(12),
                            ),
                            maxLines: 4,
                            keyboardType: TextInputType.multiline,
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // 저장 버튼
                    Container(
                      width: double.infinity,
                      height: 50,
                      decoration: BoxDecoration(
                        color: const Color(0xFF233554),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveRecord,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isLoading
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    '수정 중...',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              )
                            : const Text(
                                '산책기록 정보 수정',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
                    ),
                  );
                },
              ),
          );
  }

  Widget _buildImageDisplay() {
    // 선택된 로컬 이미지가 있으면 표시
    if (_selectedImageUrl != null) {
      return Image.file(
        File(_selectedImageUrl!),
        width: double.infinity,
        height: 200,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return const Center(
            child: Icon(
              Icons.image_not_supported,
              size: 50,
              color: Colors.grey,
            ),
          );
        },
      );
    }
    
    // 기존 이미지가 있으면 첫 번째 이미지 표시 (PageView로 여러 장 지원)
    if (_imageUrls.isNotEmpty) {
      if (_imageUrls.length == 1) {
        // 단일 이미지
        return Image.network(
          _imageUrls.first,
          width: double.infinity,
          height: 200,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const Center(
              child: Icon(
                Icons.image_not_supported,
                size: 50,
                color: Colors.grey,
              ),
            );
          },
        );
      } else {
        // 여러 이미지 - PageView로 슬라이드
        return PageView.builder(
          itemCount: _imageUrls.length,
          itemBuilder: (context, index) {
            return Image.network(
              _imageUrls[index],
              width: double.infinity,
              height: 200,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const Center(
                  child: Icon(
                    Icons.image_not_supported,
                    size: 50,
                    color: Colors.grey,
                  ),
                );
              },
            );
          },
        );
      }
    }
    
    // 이미지가 없을 때 기본 아이콘 표시
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_photo_alternate,
            size: 50,
            color: Colors.grey,
          ),
          SizedBox(height: 8),
          Text(
            '산책 사진을 추가하세요',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
