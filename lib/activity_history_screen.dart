import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityHistoryScreen extends StatefulWidget {
  const ActivityHistoryScreen({super.key});

  @override
  State<ActivityHistoryScreen> createState() => _ActivityHistoryScreenState();
}

class _ActivityHistoryScreenState extends State<ActivityHistoryScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Map<String, dynamic>> _activities = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadActivityHistory();
  }

  Future<void> _loadActivityHistory() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('No user logged in');
        setState(() => _isLoading = false);
        return;
      }

      print('Loading activity history for user: ${user.uid}');

      // 1. 먼저 walk_records 컬렉션의 모든 데이터 확인 (테스트용)
      final allWalks = await _firestore.collection('walk_records').get();
      print('Total walk records in database: ${allWalks.docs.length}');
      
      // 2. 현재 사용자의 데이터만 필터링
      final walksSnapshot = await _firestore
          .collection('walk_records')
          .where('user_id', isEqualTo: user.uid)
          .get();

      print('Found ${walksSnapshot.docs.length} walk records for current user');

      // 3. 모든 walk_records 데이터 출력 (디버깅용)
      for (var doc in allWalks.docs) {
        final data = doc.data();
        print('All walk record - ID: ${doc.id}, user_id: ${data['user_id']}, current_user: ${user.uid}');
      }

      // 4. feeds 컬렉션도 확인
      final allFeeds = await _firestore.collection('feeds').get();
      print('Total feed records in database: ${allFeeds.docs.length}');
      
      final feedsSnapshot = await _firestore
          .collection('feeds')
          .where('userId', isEqualTo: user.uid)
          .get();

      print('Found ${feedsSnapshot.docs.length} feed records for current user');

      // 5. 실제 데이터만 추가 (테스트 데이터 제거)
      List<Map<String, dynamic>> activities = [];

      // 실제 산책 기록 추가
      for (var doc in walksSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null) {
          print('Adding walk record: $data');
          
          // 날짜 정보 확인
          Timestamp walkDate = data['date'] ?? Timestamp.now();
          
          activities.add({
            'id': doc.id,
            'type': 'walk',
            'title': '산책',
            'date': walkDate,
            'distance': data['distance_km'] != null ? '${(data['distance_km'] as double).toStringAsFixed(2)}km' : null,
            'duration': data['duration_minutes'] != null ? '${data['duration_minutes']}분' : null,
            'createdAt': walkDate,
          });
        }
      }

      print('Total activities to display: ${activities.length}');

      setState(() {
        _activities = activities;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading activity history: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours > 0) {
      return '${hours}시간 ${minutes}분';
    } else {
      return '${minutes}분';
    }
  }

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return '오늘';
    } else if (difference.inDays == 1) {
      return '어제';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}일 전';
    } else {
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
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
          : _activities.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        '활동 이력이 없습니다',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '산책을 시작하고 기록을 남겨보세요',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _activities.length,
                  itemBuilder: (context, index) {
                    final activity = _activities[index];
                    return _buildActivityCard(activity);
                  },
                ),
    );
  }

  Widget _buildActivityCard(Map<String, dynamic> activity) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
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
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: activity['type'] == 'walk' 
                      ? const Color(0xFF233554) 
                      : const Color(0xFF4CAF50),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  activity['type'] == 'walk' ? Icons.directions_walk : Icons.photo_camera,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity['title'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    Text(
                      _formatDate(activity['createdAt']),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (activity['type'] == 'walk' && (activity['distance'] != null || activity['duration'] != null))
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  if (activity['distance'] != null) ...[
                    Icon(Icons.straighten, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      activity['distance'],
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  if (activity['duration'] != null) ...[
                    Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      activity['duration'],
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          if (activity['type'] == 'feed' && activity['description'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                activity['description'],
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
