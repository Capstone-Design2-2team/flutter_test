import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class WalkRecordEditScreen extends StatefulWidget {
  final String walkId;
  const WalkRecordEditScreen({super.key, required this.walkId});

  @override
  State<WalkRecordEditScreen> createState() => _WalkRecordEditScreenState();
}

class _WalkRecordEditScreenState extends State<WalkRecordEditScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _picker = ImagePicker();
  
  Map<String, dynamic>? _walkRecord;
  bool _isLoading = true;
  bool _isSaving = false;
  
  // Form controllers and variables
  late TextEditingController _memoController;
  String? _walkImageUrl;
  File? _newImage;
  List<String> _images = [];

  @override
  void initState() {
    super.initState();
    _loadWalkRecord();
  }

  String _formatDateWithDay(DateTime date) {
    const List<String> weekdays = ['월요일', '화요일', '수요일', '목요일', '금요일', '토요일', '일요일'];
    final weekday = weekdays[date.weekday - 1];
    return '${date.year}년 ${date.month}월 ${date.day}일 $weekday';
  }

  String _formatTimeRange(DateTime startTime, DateTime endTime) {
    String formatTime(DateTime time) {
      final hour = time.hour;
      final period = hour >= 12 ? '오후' : '오전';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return '$period ${displayHour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
    
    return '${formatTime(startTime)} - ${formatTime(endTime)}';
  }

  Future<void> _loadWalkRecord() async {
    try {
      print('WalkRecordEditScreen: Loading walk record with ID: ${widget.walkId}');
      final user = _auth.currentUser;
      if (user == null) {
        print('WalkRecordEditScreen: No user logged in');
        setState(() => _isLoading = false);
        return;
      }
      print('WalkRecordEditScreen: User logged in: ${user.uid}');

      final walkDoc = await _firestore.collection('walk_records').doc(widget.walkId).get();
      print('WalkRecordEditScreen: Walk document exists: ${walkDoc.exists}');
      
      if (!walkDoc.exists) {
        print('WalkRecordEditScreen: Walk record not found with ID: ${widget.walkId}');
        setState(() {
          _walkRecord = null;
          _isLoading = false;
        });
        return;
      }

      final walkData = walkDoc.data()!;
      print('WalkRecordEditScreen: Raw walk data: $walkData');
      print('WalkRecordEditScreen: Available fields: ${walkData.keys.toList()}');
      
      setState(() {
        _walkRecord = {'id': walkDoc.id, ...walkData};
        
        // 메모 처리 - 여러 필드명 시도
        String memoText = '';
        if (walkData['post_memo'] != null) {
          memoText = walkData['post_memo'].toString();
          print('WalkRecordEditScreen: Found post_memo: $memoText');
        } else if (walkData['memo'] != null) {
          memoText = walkData['memo'].toString();
          print('WalkRecordEditScreen: Found memo: $memoText');
        } else if (walkData['description'] != null) {
          memoText = walkData['description'].toString();
          print('WalkRecordEditScreen: Found description: $memoText');
        } else {
          print('WalkRecordEditScreen: No memo field found');
        }
        
        _memoController = TextEditingController(text: memoText);
        
        // 이미지 처리 - 여러 필드명 시도
        _images.clear();
        if (walkData['post_images'] != null) {
          _images = List<String>.from(walkData['post_images']);
          print('WalkRecordEditScreen: Found post_images: $_images');
        } else if (walkData['images'] != null) {
          _images = List<String>.from(walkData['images']);
          print('WalkRecordEditScreen: Found images: $_images');
        } else {
          print('WalkRecordEditScreen: No images field found');
        }
        
        if (_images.isNotEmpty) {
          _walkImageUrl = _images.first;
        }
        
        // 시간 정보 확인
        if (walkData['start_time'] != null) {
          print('WalkRecordEditScreen: start_time: ${walkData['start_time']}');
        }
        if (walkData['end_time'] != null) {
          print('WalkRecordEditScreen: end_time: ${walkData['end_time']}');
        }
        if (walkData['distance_km'] != null) {
          print('WalkRecordEditScreen: distance_km: ${walkData['distance_km']}');
        }
        
        print('WalkRecordEditScreen: Final memo: "${_memoController.text}"');
        print('WalkRecordEditScreen: Final images count: ${_images.length}');
        print('WalkRecordEditScreen: Final first image: $_walkImageUrl');
        
        _isLoading = false;
      });
    } catch (e) {
      print('WalkRecordEditScreen: Error loading walk record: $e');
      print('WalkRecordEditScreen: Stack trace: ${StackTrace.current}');
      setState(() {
        _walkRecord = null;
        _isLoading = false;
      });
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

  Future<void> _saveWalkRecord() async {
    if (_memoController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('메모를 입력해주세요.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('사용자 정보를 찾을 수 없습니다.');
      }

      print('WalkRecordEditScreen: Saving walk record with ID: ${widget.walkId}');
      
      Map<String, dynamic> updateData = {
        'post_memo': _memoController.text.trim(), // post_memo 필드 사용
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // TODO: 이미지 업로드 로직 추가 필요
      // if (_newImage != null) {
      //   String imageUrl = await _uploadImage(_newImage);
      //   if (imageUrl.isNotEmpty) {
      //     if (_images.isNotEmpty) {
      //       _images[0] = imageUrl; // 첫 번째 이미지 교체
      //     } else {
      //       _images.add(imageUrl);
      //     }
      //     updateData['post_images'] = _images; // post_images 필드 사용
      //   }
      // }

      await _firestore.collection('walk_records').doc(widget.walkId).update(updateData);
      print('WalkRecordEditScreen: Walk record updated successfully');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('산책 기록이 수정되었습니다.')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      print('WalkRecordEditScreen: Error saving walk record: $e');
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
              ? _buildEmptyState()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 페이지 제목
                      Center(
                        child: const Text(
                          '산책기록 정보 수정',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF233554),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 산책 정보 카드
                      _buildWalkInfoCard(),
                      const SizedBox(height: 24),

                      // 산책 사진 섹션
                      _buildPhotoSection(),
                      const SizedBox(height: 24),

                      // 메모 작성 섹션
                      _buildMemoSection(),
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
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildWalkInfoCard() {
    if (_walkRecord == null) {
      print('WalkRecordEditScreen: _walkRecord is null in _buildWalkInfoCard');
      return const SizedBox.shrink();
    }
    
    final data = _walkRecord!;
    print('WalkRecordEditScreen: Building walk info card with data keys: ${data.keys.toList()}');
    
    // 날짜와 시간 정보 가져오기
    DateTime? startTime;
    DateTime? endTime;
    double distance = 0.0;
    
    try {
      if (data['start_time'] != null) {
        if (data['start_time'] is Timestamp) {
          startTime = (data['start_time'] as Timestamp).toDate();
          print('WalkRecordEditScreen: Parsed start_time: $startTime');
        } else {
          print('WalkRecordEditScreen: start_time is not Timestamp: ${data['start_time'].runtimeType}');
        }
      } else {
        print('WalkRecordEditScreen: start_time is null');
      }
      
      if (data['end_time'] != null) {
        if (data['end_time'] is Timestamp) {
          endTime = (data['end_time'] as Timestamp).toDate();
          print('WalkRecordEditScreen: Parsed end_time: $endTime');
        } else {
          print('WalkRecordEditScreen: end_time is not Timestamp: ${data['end_time'].runtimeType}');
        }
      } else {
        print('WalkRecordEditScreen: end_time is null');
      }
      
      if (data['distance_km'] != null) {
        distance = (data['distance_km'] as num?)?.toDouble() ?? 0.0;
        print('WalkRecordEditScreen: Parsed distance_km: $distance');
      } else {
        print('WalkRecordEditScreen: distance_km is null');
      }
    } catch (e) {
      print('WalkRecordEditScreen: Error parsing walk data: $e');
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 날짜 정보
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 24,
                  color: Color(0xFF233554),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    startTime != null 
                        ? _formatDateWithDay(startTime)
                        : '날짜 정보 없음',
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          // 시간 정보
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 24,
                  color: Color(0xFF233554),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    startTime != null && endTime != null
                        ? _formatTimeRange(startTime, endTime)
                        : '시간 정보 없음',
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          // 거리 정보
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.directions_walk,
                  size: 24,
                  color: Color(0xFF233554),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    distance > 0 ? '${distance.toStringAsFixed(1)}km' : '거리 정보 없음',
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWalkInfo() {
    if (_walkRecord == null) {
      print('WalkRecordEditScreen: _walkRecord is null in _buildWalkInfo');
      return const SizedBox.shrink();
    }
    
    final data = _walkRecord!;
    print('WalkRecordEditScreen: Building walk info with data keys: ${data.keys.toList()}');
    
    // 날짜와 시간 정보 가져오기
    DateTime? startTime;
    DateTime? endTime;
    double distance = 0.0;
    
    try {
      if (data['start_time'] != null) {
        if (data['start_time'] is Timestamp) {
          startTime = (data['start_time'] as Timestamp).toDate();
          print('WalkRecordEditScreen: Parsed start_time: $startTime');
        } else {
          print('WalkRecordEditScreen: start_time is not Timestamp: ${data['start_time'].runtimeType}');
        }
      } else {
        print('WalkRecordEditScreen: start_time is null');
      }
      
      if (data['end_time'] != null) {
        if (data['end_time'] is Timestamp) {
          endTime = (data['end_time'] as Timestamp).toDate();
          print('WalkRecordEditScreen: Parsed end_time: $endTime');
        } else {
          print('WalkRecordEditScreen: end_time is not Timestamp: ${data['end_time'].runtimeType}');
        }
      } else {
        print('WalkRecordEditScreen: end_time is null');
      }
      
      if (data['distance_km'] != null) {
        distance = (data['distance_km'] as num?)?.toDouble() ?? 0.0;
        print('WalkRecordEditScreen: Parsed distance_km: $distance');
      } else {
        print('WalkRecordEditScreen: distance_km is null');
      }
    } catch (e) {
      print('WalkRecordEditScreen: Error parsing walk data: $e');
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '산책 정보',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF233554),
            ),
          ),
          const SizedBox(height: 12),
          
          Row(
            children: [
              Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text(
                startTime != null 
                    ? '${startTime.year}-${startTime.month.toString().padLeft(2, '0')}-${startTime.day.toString().padLeft(2, '0')}'
                    : '날짜 정보 없음',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          Row(
            children: [
              Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text(
                startTime != null && endTime != null
                    ? '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')} - ${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}'
                    : '시간 정보 없음',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          Row(
            children: [
              Icon(Icons.directions_walk, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text(
                distance > 0 ? '${distance.toStringAsFixed(1)}km' : '거리 정보 없음',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            '산책 기록을 찾을 수 없습니다',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '다시 시도해주세요',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF233554),
              foregroundColor: Colors.white,
            ),
            child: const Text('돌아가기'),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '산책 사진',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
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
                            return _buildEmptyPhotoPlaceholder();
                          },
                        )
                      : _buildEmptyPhotoPlaceholder(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '사진을 클릭하여 새로운 이미지를 선택하세요',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildEmptyPhotoPlaceholder() {
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
            Text(
              '사진을 선택하세요',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '메모 작성',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _memoController,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: '산책에 대한 메모를 작성하세요...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF233554)),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }
}
