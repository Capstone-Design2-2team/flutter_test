import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _lastError;

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    
    print('FeedScreen: Building UI, user: ${user?.uid}');
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF233554),
        title: const Text(
          '피드',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: user == null 
          ? const Center(child: Text('로그인이 필요합니다.'))
          : Column(
              children: [
                // 디버깅 정보 표시
                Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.grey[100],
                  child: Text(
                    '디버깅: 사용자 ID=${user.uid}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('feeds')
                        .where('isPublic', isEqualTo: true)
                        .orderBy('createdAt', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      print('FeedScreen: StreamBuilder state: ${snapshot.connectionState}');
                      print('FeedScreen: Has error: ${snapshot.hasError}');
                      if (snapshot.hasError) {
                        print('FeedScreen: Error details: ${snapshot.error}');
                        _lastError = snapshot.error.toString();
                      }
                      
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        print('FeedScreen Error: ${snapshot.error}');
                        print('FeedScreen StackTrace: ${snapshot.stackTrace}');
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, size: 64, color: Colors.red),
                              const SizedBox(height: 16),
                              const Text('피드를 불러오는 중 오류가 발생했습니다.'),
                              const SizedBox(height: 8),
                              Text(
                                '오류: $_lastError',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '사용자 ID: ${user.uid}',
                                style: const TextStyle(fontSize: 10, color: Colors.blue),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {}); // 다시 시도
                                },
                                child: const Text('다시 시도'),
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: () {
                                  // 간단한 테스트: users 컬렉션 테스트
                                  _testFirebaseConnection();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                ),
                                child: const Text('Firebase 연결 테스트'),
                              ),
                            ],
                          ),
                        );
                      }

                      final docs = snapshot.data?.docs ?? [];
                      print('FeedScreen: Loaded ${docs.length} feeds');

                      if (docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.feed_outlined, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text('피드가 없습니다.'),
                              SizedBox(height: 8),
                              Text('산책 기록을 공유해보세요!'),
                              SizedBox(height: 8),
                              Text('디버깅: docs.length=$docs'),
                            ],
                          ),
                        );
                      }

                      return GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final data = doc.data() as Map<String, dynamic>?;
                          if (data == null) return const SizedBox.shrink();

                          final feedId = doc.id;
                          final images = data['images'] as List<dynamic>? ?? [];
                          final content = data['content'] as String? ?? '';
                          final moodEmoji = data['moodEmoji'] as String? ?? '';
                          final petInfo = data['petInfo'] as List<dynamic>? ?? [];
                          final createdAt = data['createdAt'] as Timestamp?;
                          final distanceKm = data['distanceKm'] as double? ?? 0.0;
                          final durationMinutes = data['durationMinutes'] as int? ?? 0;

                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => FeedDetailScreen(
                                    feedId: feedId,
                                    data: data,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.white,
                                border: Border.all(color: Colors.grey[300]!),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 이미지
                                  Expanded(
                                    flex: 3,
                                    child: Container(
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                                        image: images.isNotEmpty
                                            ? DecorationImage(
                                                image: NetworkImage(images.first),
                                                fit: BoxFit.cover,
                                              )
                                            : null,
                                      ),
                                      child: images.isEmpty
                                          ? const Center(
                                              child: Icon(Icons.image, size: 40, color: Colors.grey),
                                            )
                                          : null,
                                    ),
                                  ),
                                  // 정보
                                  Expanded(
                                    flex: 2,
                                    child: Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // 반려동물 정보
                                          if (petInfo.isNotEmpty)
                                            Wrap(
                                              spacing: 4,
                                              children: petInfo.take(2).map((pet) {
                                                final petData = pet as Map<String, dynamic>?;
                                                if (petData == null) return const SizedBox.shrink();
                                                final name = petData['name'] as String? ?? '펫';
                                                return Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF233554).withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                  child: Text(
                                                    name,
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      color: Color(0xFF233554),
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                          const SizedBox(height: 4),
                                          // 내용
                                          Text(
                                            content.isNotEmpty ? content : '산책 기록',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const Spacer(),
                                          // 산책 정보
                                          Row(
                                            children: [
                                              Icon(Icons.directions_walk, size: 12, color: Colors.grey[600]),
                                              Text(
                                                '${distanceKm.toStringAsFixed(1)}km',
                                                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                                              ),
                                              const SizedBox(width: 8),
                                              Icon(Icons.access_time, size: 12, color: Colors.grey[600]),
                                              Text(
                                                '${durationMinutes}분',
                                                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _testFirebaseConnection() async {
    try {
      print('FeedScreen: Testing Firebase connection...');
      
      // 1. 사용자 확인
      final user = _auth.currentUser;
      if (user == null) {
        print('FeedScreen: No user logged in');
        return;
      }
      print('FeedScreen: User authenticated: ${user.uid}');
      
      // 2. users 컬렉션 테스트
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      print('FeedScreen: User doc exists: ${userDoc.exists}');
      
      // 3. pets 컬렉션 테스트
      final petsQuery = await _firestore
          .collection('pets')
          .where('userId', isEqualTo: user.uid)
          .limit(1)
          .get();
      print('FeedScreen: Pets query result: ${petsQuery.docs.length} docs');
      
      // 4. feeds 컬렉션 테스트
      final feedsQuery = await _firestore
          .collection('feeds')
          .limit(1)
          .get();
      print('FeedScreen: Feeds query result: ${feedsQuery.docs.length} docs');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Firebase 연결 테스트 완료'),
          backgroundColor: Colors.green,
        ),
      );
      
    } catch (e) {
      print('FeedScreen: Firebase connection test failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Firebase 연결 실패: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class FeedDetailScreen extends StatelessWidget {
  final String feedId;
  final Map<String, dynamic>? data;

  const FeedDetailScreen({super.key, required this.feedId, this.data});

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
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 25,
                    backgroundColor: Color(0xFF233554),
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('닉네임', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('한줄 소개', style: TextStyle(color: Colors.grey, fontSize: 14)),
                    ],
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF233554),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Text('팔로우', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
            Image.network(
              'https://picsum.photos/400/300',
              width: double.infinity,
              height: 300,
              fit: BoxFit.cover,
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.favorite_border, size: 24),
                      SizedBox(width: 8),
                      Text('10', style: TextStyle(fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('산책 기록', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF233554))),
                  const SizedBox(height: 12),
                  _buildInfoRow('2025-11-28'),
                  _buildInfoRow('산책시간 : 09:00 ~ 10:00'),
                  _buildInfoRow('총 거리 : 5km'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
    );
  }
}