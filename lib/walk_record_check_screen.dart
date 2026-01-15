import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'walk_record_service.dart';
import 'pet_edit_screen.dart';
import 'walk/walk_from_record_screen.dart';
import 'pet_update_service.dart';
import 'walk_record_detail_screen.dart';
import 'feed_screen.dart';

class WalkRecordCheckScreen extends StatefulWidget {
  final String petId;

  const WalkRecordCheckScreen({super.key, required this.petId});

  @override
  State<WalkRecordCheckScreen> createState() => _WalkRecordCheckScreenState();
}

class _WalkRecordCheckScreenState extends State<WalkRecordCheckScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Map<String, dynamic>? _petData;
  List<Map<String, dynamic>> _walkRecords = [];
  Set<String> _feedAddedRecords = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final petDoc = await _firestore
          .collection('pets')
          .doc(widget.petId)
          .get();
      if (petDoc.exists) {
        final petData = petDoc.data() as Map<String, dynamic>;
        petData['id'] = petDoc.id;
        _petData = petData;
      }

      final user = _auth.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      final feedSnap = await _firestore
          .collection('feeds')
          .where('userId', isEqualTo: user.uid)
          .get();
      final feedWalkIds = feedSnap.docs
          .map((d) => (d.data() as Map<String, dynamic>)['walkId'] as String?)
          .where((id) => id != null)
          .cast<String>()
          .toSet();

      QuerySnapshot walkSnap;
      try {
        walkSnap = await _firestore
            .collection('walk_records')
            .where('pet_ids', arrayContains: widget.petId)
            .get();
      } catch (_) {
        walkSnap = await _firestore
            .collection('walk_records')
            .where('pet_id', isEqualTo: widget.petId)
            .get();
      }

      final records = walkSnap.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();

      DateTime _toDate(Map<String, dynamic> r) {
        final v = r['date'] ?? r['createdAt'] ?? r['start_time'];
        if (v is Timestamp) return v.toDate();
        if (v is DateTime) return v;
        return DateTime.fromMillisecondsSinceEpoch(0);
      }

      records.sort((a, b) => _toDate(b).compareTo(_toDate(a)));

      final added = <String>{};
      for (final r in records) {
        final id = r['id'] as String?;
        if (id != null && feedWalkIds.contains(id)) added.add(id);
      }

      setState(() {
        _walkRecords = records;
        _feedAddedRecords = added;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('데이터 로드 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _addToFeed(Map<String, dynamic> record) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final walkId = record['id'] as String?;
      if (walkId == null) return;

      // Check if already in feed
      if (_feedAddedRecords.contains(walkId)) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('이미 피드에 추가된 산책 기록입니다.')));
        return;
      }

      // Get pet info
      List<Map<String, dynamic>> petInfo = [];
      final petIds = record['pet_ids'] as List<dynamic>? ?? [];

      for (final petId in petIds) {
        final petDoc = await _firestore.collection('pets').doc(petId).get();
        if (petDoc.exists) {
          final petData = petDoc.data() as Map<String, dynamic>?;
          if (petData != null) {
            petInfo.add({
              'id': petId,
              'name': petData['name'] ?? petData['pet_name'] ?? '이름 없음',
              'breed': petData['breed'] ?? petData['pet_breed'] ?? '품종 정보 없음',
              'imageUrl': petData['imageUrl'] ?? petData['photo_url'] ?? '',
            });
          }
        }
      }

      // Add to feed
      await _firestore.collection('feeds').add({
        'userId': user.uid,
        'walkId': walkId,
        'type': 'walk',
        'createdAt': Timestamp.now(),
        'content': record['memo'] ?? '산책 기록',
        'moodEmoji': record['mood_emoji'] ?? '😊',
        'images': record['post_images'] ?? [],
        'distanceKm': record['distance_km'] ?? 0.0,
        'durationMinutes': record['duration_minutes'] ?? 0,
        'startTime': record['start_time'],
        'endTime': record['end_time'],
        'route': record['route'] ?? [],
        'petIds': petIds,
        'petInfo': petInfo,
        'likeCount': 0,
        'commentCount': 0,
        'isPublic': true,
      });

      setState(() {
        _feedAddedRecords.add(walkId);
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('피드에 추가되었습니다.')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('피드 추가 중 오류 발생: $e')));
    }
  }

  void _navigateToFeedScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const FeedScreen(),
        settings: const RouteSettings(name: 'FeedScreen'),
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
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '산책기록 확인',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPetProfileCard(),
                    const SizedBox(height: 20),
                    const Text(
                      '산책 기록',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF233554),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildWalkRecordsList(),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => WalkFromRecordScreen(
                        onBackToHome: () {
                          Navigator.popUntil(context, (route) => route.isFirst);
                        },
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF233554),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  '산책하기',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPetProfileCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Pet Image with Checkmark
          Stack(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  shape: BoxShape.circle,
                ),
                child:
                    _petData?['imageUrl'] != null &&
                        _petData!['imageUrl'].isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: Image.network(
                          _petData!['imageUrl'],
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
                    : const Icon(Icons.pets, size: 30, color: Colors.grey),
              ),
              // Red checkmark overlay
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          // Pet Name
          Expanded(
            child: Text(
              _petData?['name'] ?? '반려동물 이름',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF233554),
              ),
            ),
          ),
          // Edit Button
          IconButton(
            icon: const Icon(
              Icons.edit,
              color: Color(0xFF233554),
              size: 20,
            ),
            onPressed: () {
              if (_petData != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PetEditScreen(
                      petId: _petData!['id'],
                      onPetUpdated: () {
                        _loadData();
                      },
                    ),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWalkRecordsList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_walkRecords.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: const Center(
          child: Text(
            '산책 기록이 없습니다',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ),
      );
    }

    return Column(
      children: _walkRecords.map((record) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey[300]!),
            ),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => WalkRecordDetailScreen(
                      recordId: record['id'],
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Walk Photo placeholder
                    Container(
                      width: double.infinity,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _getRecordImages(record).isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                _getRecordImages(record).first,
                                width: double.infinity,
                                height: 120,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Center(
                                    child: Icon(
                                      Icons.image,
                                      size: 40,
                                      color: Colors.grey,
                                    ),
                                  );
                                },
                              ),
                            )
                          : const Center(
                              child: Text(
                                '산책 사진',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(height: 12),
                    // Date
                    Text(
                      _formatDate(record['date']),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF233554),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Walk Time
                    _buildInfoRow(
                      '산책 시간',
                      _formatWalkTime(record),
                    ),
                    const SizedBox(height: 4),
                    // Total Distance
                    _buildInfoRow(
                      '총 거리',
                      '${(record['distance_km'] ?? 0.0).toStringAsFixed(1)}km',
                    ),
                    const SizedBox(height: 12),
                    // Add to Feed Button
                    _buildFeedAddButton(record),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFeedAddButton(Map<String, dynamic> record) {
    final recordId = record['id'] as String?;
    final isAlreadyInFeed =
        recordId != null && _feedAddedRecords.contains(recordId);

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isAlreadyInFeed ? null : () => _addToFeed(record),
        style: ElevatedButton.styleFrom(
          backgroundColor: isAlreadyInFeed
              ? Colors.grey[300]
              : const Color(0xFF233554),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(
          isAlreadyInFeed ? '피드에 추가됨' : '피드에 추가',
          style: TextStyle(
            fontSize: 14,
            color: isAlreadyInFeed ? Colors.grey : Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
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
    );
  }

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  List<dynamic> _getRecordImages(Map<String, dynamic> record) {
    final List<dynamic> images = [];
    if (record['post_images'] != null) {
      images.addAll(List.from(record['post_images']));
    } else if (record['postImages'] != null) {
      images.addAll(List.from(record['postImages']));
    }
    return images;
  }

  String _formatWalkTime(Map<String, dynamic> record) {
    if (record['start_time'] != null && record['end_time'] != null) {
      final startTime = (record['start_time'] as Timestamp).toDate();
      final endTime = (record['end_time'] as Timestamp).toDate();
      return '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')} ~ ${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';
    } else if (record['duration_minutes'] != null) {
      return '${record['duration_minutes']}분';
    }
    return '시간 정보 없음';
  }

  Widget _buildNavItem(IconData icon, String label, bool isActive) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 24,
          color: isActive ? const Color(0xFF233554) : Colors.grey,
        ),
        if (label.isNotEmpty)
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isActive ? const Color(0xFF233554) : Colors.grey,
            ),
          ),
      ],
    );
  }
}
