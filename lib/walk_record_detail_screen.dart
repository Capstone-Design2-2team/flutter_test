import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'walk_record_service.dart';
import 'pet_edit_screen.dart';
import 'walk/walk_screen.dart';
import 'pet_update_service.dart';
import 'walk_record_detail_screen.dart';
import 'walk_record_edit_screen.dart';
import 'walk_route_screen.dart';
import 'walk_statistics_screen.dart';

class WalkRecordDetailScreen extends StatefulWidget {
  final String recordId;

  const WalkRecordDetailScreen({super.key, required this.recordId});

  @override
  State<WalkRecordDetailScreen> createState() => _WalkRecordDetailScreenState();
}

class _WalkRecordDetailScreenState extends State<WalkRecordDetailScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Map<String, dynamic>? _recordData;
  Map<String, dynamic>? _petData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecordData();
  }

  Future<void> _loadRecordData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // 1. 산책 기록 데이터 가져오기
      final recordDoc = await _firestore
          .collection('walk_records')
          .doc(widget.recordId)
          .get();

      if (recordDoc.exists) {
        final record = recordDoc.data() as Map<String, dynamic>;
        record['id'] = recordDoc.id;

        print('DEBUG: Raw record data: ${record.keys.toList()}');
        print('DEBUG: postImages field: ${record['postImages']}');
        print('DEBUG: images field: ${record['images']}');
        print('DEBUG: post_images field: ${record['post_images']}');

        // 2. 반려동물 정보 가져오기
        String? petId;

        // 다양한 pet 필드명에서 petId 찾기
        if (record['pet_ids'] != null &&
            (record['pet_ids'] as List).isNotEmpty) {
          petId = (record['pet_ids'] as List).first;
        } else if (record['pet_id'] != null) {
          petId = record['pet_id'];
        } else if (record['petId'] != null) {
          petId = record['petId'];
        }

        print('DEBUG: Found petId: $petId');

        if (petId != null) {
          final petDoc = await _firestore.collection('pets').doc(petId).get();

          if (petDoc.exists) {
            setState(() {
              _petData = petDoc.data() as Map<String, dynamic>;
              _petData!['id'] = petDoc.id;
              _recordData = record;
              _isLoading = false;
            });
            return;
          }
        }

        // 반려동물 정보가 없어도 기록은 표시
        setState(() {
          _recordData = record;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading record data: $e');
      setState(() => _isLoading = false);
    }
  }

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatTime(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
          : _recordData == null
          ? const Center(
              child: Text(
                '산책 기록을 찾을 수 없습니다',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  // 반려동물 프로필 섹션
                  if (_petData != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // 반려동물 프로필
                          Row(
                            children: [
                              // 반려동물 이미지
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  shape: BoxShape.circle,
                                ),
                                child:
                                    _petData!['imageUrl'] != null &&
                                        _petData!['imageUrl'].isNotEmpty
                                    ? ClipOval(
                                        child: Image.network(
                                          _petData!['imageUrl'],
                                          width: 80,
                                          height: 80,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                                return const Icon(
                                                  Icons.pets,
                                                  size: 40,
                                                  color: Colors.grey,
                                                );
                                              },
                                        ),
                                      )
                                    : const Icon(
                                        Icons.pets,
                                        size: 40,
                                        color: Colors.grey,
                                      ),
                              ),

                              const SizedBox(width: 16),

                              // 반려동물 이름만 표시
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _petData!['name'] ?? '반려동물',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                  // 산책 이미지 섹션
                  Container(
                    width: double.infinity,
                    height: 200,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Stack(
                      children: [
                        // 산책기록 텍스트 (수정 버튼과 동일한 색상)
                        Positioned(
                          top: 12,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF233554),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              '산책기록',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        // 이미지 표시
                        _buildWalkImages(),
                      ],
                    ),
                  ),

                  // 산책 정보 합친 섹션
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
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
                        // 날짜와 시간
                        Text(
                          _formatDate(_recordData!['date'] as Timestamp),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF233554),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _recordData!['startTime'] != null &&
                                  _recordData!['endTime'] != null
                              ? '${_formatTime(_recordData!['startTime'] as Timestamp)} - ${_formatTime(_recordData!['endTime'] as Timestamp)}'
                              : '시간 정보 없음',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),

                        const SizedBox(height: 16),

                        // 산책 정보
                        _buildInfoItem(
                          '총 거리',
                          '${(_recordData!['distance_km'] ?? 0.0).toStringAsFixed(1)}km',
                        ),
                        _buildInfoItem(
                          '산책 시간',
                          '${_recordData!['duration_minutes'] ?? 0}분',
                        ),
                        if (_recordData!['calories'] != null)
                          _buildInfoItem(
                            '소모 칼로리',
                            '${_recordData!['calories']}kcal',
                          ),
                        if (_recordData!['steps'] != null)
                          _buildInfoItem('걸음 수', '${_recordData!['steps']}걸음'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 기능 버튼 섹션
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        // 버튼 행 1
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 45,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: ElevatedButton(
                                  onPressed: () {
                                    _showRouteDialog();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    padding: EdgeInsets.zero,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.directions_walk,
                                        size: 18,
                                        color: const Color(0xFF233554),
                                      ),
                                      const SizedBox(width: 6),
                                      const Text(
                                        '이동 경로 보기',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF233554),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                height: 45,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: ElevatedButton(
                                  onPressed: () {
                                    _showStatisticsDialog();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    padding: EdgeInsets.zero,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.insert_chart,
                                        size: 18,
                                        color: const Color(0xFF233554),
                                      ),
                                      const SizedBox(width: 6),
                                      const Text(
                                        '산책거리/시간 통계',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF233554),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // 버튼 행 2
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 45,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: ElevatedButton(
                                  onPressed: () {
                                    _addToFeed();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    padding: EdgeInsets.zero,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.share,
                                        size: 18,
                                        color: const Color(0xFF233554),
                                      ),
                                      const SizedBox(width: 6),
                                      const Text(
                                        '피드에 추가',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF233554),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                height: 45,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF233554),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: ElevatedButton(
                                  onPressed: () {
                                    _showEditDialog();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    padding: EdgeInsets.zero,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.edit,
                                        size: 18,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 6),
                                      const Text(
                                        '산책기록 정보 수정',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 기분 표현 섹션
                  if (_recordData!['moodEmoji'] != null)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
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
                            '오늘의 기분',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Text(
                                _recordData!['moodEmoji'],
                                style: const TextStyle(fontSize: 32),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _getMoodText(_recordData!['moodEmoji']),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  void _showRouteDialog() {
    if (_recordData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('산책 기록 데이터를 불러올 수 없습니다.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WalkRouteScreen(
          recordId: widget.recordId,
          recordData: _recordData!,
        ),
      ),
    );
  }

  void _showStatisticsDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const WalkStatisticsScreen()),
    );
  }

  void _showEditDialog() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WalkRecordEditScreen(
          recordId: widget.recordId,
          recordData: _recordData!,
        ),
      ),
    );

    if (result == true) {
      // 수정 성공 시 데이터 다시 로드
      _loadRecordData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('산책기록이 수정되었습니다.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _addToFeed() async {
    if (_recordData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('산책 기록 데이터를 불러올 수 없습니다.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('로그인이 필요합니다.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 이미 피드에 추가되었는지 확인
    try {
      final existingFeed = await _firestore
          .collection('feeds')
          .where('walkId', isEqualTo: widget.recordId)
          .where('userId', isEqualTo: user.uid)
          .get();

      if (existingFeed.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('이미 피드에 추가된 산책 기록입니다.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    } catch (e) {
      print('Error checking existing feed: $e');
    }

    // 로딩 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('피드에 추가 중...'),
          ],
        ),
      ),
    );

    try {
      // 반려동물 정보 가져오기
      List<Map<String, dynamic>> petInfo = [];
      final petIds = _recordData!['pet_ids'] as List<dynamic>? ?? [];

      for (final petId in petIds) {
        final petDoc = await _firestore.collection('pets').doc(petId).get();
        if (petDoc.exists) {
          final petData = petDoc.data() as Map<String, dynamic>?;
          if (petData != null) {
            petInfo.add({
              'id': petId,
              'name': petData['name'] ?? petData['pet_name'] ?? '이름 없음',
              'breed': petData['breed'] ?? petData['pet_breed'] ?? '품종 정보 없음',
              'imageUrl':
                  petData['imageUrl'] ??
                  petData['photo_url'] ??
                  petData['image_url'] ??
                  '',
            });
          }
        }
      }

      // 이미지 URL 가져오기 (다양한 필드명 시도)
      List<String> images = [];
      List<String> imageFields = [
        'postImages',
        'post_images',
        'images',
        'photos',
      ];

      for (String field in imageFields) {
        if (_recordData![field] != null) {
          final fieldImages = _recordData![field] as List<dynamic>?;
          if (fieldImages != null && fieldImages.isNotEmpty) {
            images = fieldImages.map((img) => img.toString()).toList();
            break;
          }
        }
      }

      // 피드에 추가
      final feedRef = _firestore.collection('feeds').doc();

      await feedRef.set({
        'userId': user.uid,
        'walkId': widget.recordId, // walk_records 참조
        'type': 'walk',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'content': _recordData!['memo'] ?? '산책 기록',
        'moodEmoji': _recordData!['moodEmoji'] ?? '😊',
        'images': images,
        'distanceKm': _recordData!['distance_km'] ?? 0.0,
        'durationMinutes': _recordData!['duration_minutes'] ?? 0,
        'startTime': _recordData!['start_time'],
        'endTime': _recordData!['end_time'],
        'route': _recordData!['route'] ?? [],
        'petIds': petIds,
        'petInfo': petInfo,
        'likes': 0,
        'likedBy': [],
        'likeCount': 0,
        'commentCount': 0,
        'isPublic': true,
      });

      // 다이얼로그 닫기
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('피드에 추가되었습니다.'),
          backgroundColor: Colors.green,
        ),
      );

      // 현재 화면 닫기 (이전 피드 화면으로 돌아가기)
      Navigator.pop(context);
    } catch (e) {
      // 다이얼로그 닫기
      Navigator.pop(context);

      print('Error adding to feed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('피드 추가 실패: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildWalkImages() {
    // 다양한 이미지 필드명 시도
    List<String> imageFields = [
      'postImages',
      'post_images',
      'images',
      'photos',
      'walk_images',
      'walkImages',
    ];
    List<dynamic>? images = null;

    for (String field in imageFields) {
      if (_recordData![field] != null) {
        final fieldImages = _recordData![field] as List<dynamic>?;
        if (fieldImages != null && fieldImages.isNotEmpty) {
          images = fieldImages;
          print('DEBUG: Found images in field $field: ${images.length}');
          break;
        }
      }
    }

    if (images != null && images.isNotEmpty) {
      final imageList = List<dynamic>.from(images);
      return PageView.builder(
        itemCount: imageList.length,
        itemBuilder: (context, index) {
          if (index >= imageList.length) {
            return Container(
              width: double.infinity,
              height: 200,
              color: Colors.grey[300],
              child: const Center(child: Text('인덱스 오류')),
            );
          }

          final imageItem = imageList[index];
          final imageUrl = imageItem?.toString();

          if (imageUrl == null || imageUrl.isEmpty) {
            return Container(
              width: double.infinity,
              height: 200,
              color: Colors.grey[300],
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.image_not_supported,
                      size: 50,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 8),
                    Text(
                      '이미지 URL이 없습니다',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }

          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              imageUrl,
              width: double.infinity,
              height: 200,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                print('DEBUG: Error loading image $index: $error');
                return Container(
                  width: double.infinity,
                  height: 200,
                  color: Colors.grey[300],
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.image_not_supported,
                        size: 50,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 8),
                      Text(
                        '이미지 로딩 실패',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      );
    }

    // 이미지가 없을 때
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image, size: 80, color: Colors.grey),
          SizedBox(height: 8),
          Text(
            '산책 사진이 없습니다',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  String _getMoodText(String emoji) {
    switch (emoji) {
      case '😊':
        return '행복해요';
      case '🥰':
        return '사랑스러워요';
      case '😎':
        return '멋져요';
      case '🤗':
        return '포근해요';
      case '😌':
        return '편안해요';
      case '😄':
        return '즐거워요';
      case '🐕':
        return '산책이 좋아요';
      case '🏃':
        return '활기차요';
      case '🌞':
        return '날씨가 좋아요';
      case '🌙':
        return '조용한 밤이에요';
      case '🌸':
        return '꽃처럼 예뻐요';
      case '🍃':
        return '상쾌해요';
      case '⭐':
        return '별처럼 빛나요';
      case '🎉':
        return '축하할 일이 있어요';
      default:
        return '좋아요';
    }
  }
}
