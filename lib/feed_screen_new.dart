import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Map<String, dynamic>> _feeds = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFeeds();
    
    // 파이어베이스 실시간 감지 설정
    _setupRealtimeListeners();
  }

  void _setupRealtimeListeners() {
    final user = _auth.currentUser;
    if (user == null) return;
    
    // 피드 실시간 감지
    _firestore
        .collection('feeds')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
          if (mounted) {
            // 데이터 변경 시 전체 목록 다시 로드
            _loadFeeds();
          }
        });
  }

  Future<void> _loadFeeds() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // 피드 목록 가져오기
      final feedsSnapshot = await _firestore
          .collection('feeds')
          .orderBy('createdAt', descending: true)
          .get();

      List<Map<String, dynamic>> feeds = [];

      for (var doc in feedsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null) {
          feeds.add({
            'id': doc.id,
            'userId': data['userId'],
            'title': data['title'] ?? '산책 기록',
            'imageUrl': data['imageUrl'] ?? '',
            'petName': data['petName'] ?? '반려동물',
            'walkDate': data['walkDate'],
            'walkTime': data['walkTime'],
            'distance': data['distance'],
            'createdAt': data['createdAt'],
            'likes': data['likes'] ?? 0,
          });
        }
      }

      setState(() {
        _feeds = feeds;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading feeds: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _feeds.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.photo_library_outlined,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        '피드가 없습니다',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '산책을 시작하고 피드를 남겨보세요',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: _feeds.length,
                  itemBuilder: (context, index) {
                    final feed = _feeds[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FeedDetailScreen(feed: feed),
                          ),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: feed['imageUrl'] != null && feed['imageUrl'].isNotEmpty
                              ? DecorationImage(
                                  image: NetworkImage(feed['imageUrl']),
                                  fit: BoxFit.cover,
                                )
                              : null,
                          color: feed['imageUrl'] == null || feed['imageUrl'].isEmpty
                              ? Colors.grey[200]
                              : null,
                        ),
                        child: feed['imageUrl'] == null || feed['imageUrl'].isEmpty
                            ? const Icon(
                                Icons.pets,
                                size: 40,
                                color: Colors.grey,
                              )
                            : null,
                      ),
                    );
                  },
                ),
    );
  }
}

class FeedDetailScreen extends StatelessWidget {
  final Map<String, dynamic> feed;

  const FeedDetailScreen({super.key, required this.feed});

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
            // 피드 이미지
            if (feed['imageUrl'] != null && feed['imageUrl'].isNotEmpty)
              Container(
                width: double.infinity,
                height: 300,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: NetworkImage(feed['imageUrl']),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            
            // 사용자 정보
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
                    children: [
                      Text(
                        feed['petName'] ?? '반려동물',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        '산책 기록',
                        style: const TextStyle(color: Colors.grey, fontSize: 14),
                      ),
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
            
            // 피드 정보
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.favorite_border, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        '${feed['likes'] ?? 0}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '산책 기록',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF233554)),
                  ),
                  const SizedBox(height: 12),
                  if (feed['walkDate'] != null)
                    _buildInfoRow('날짜 : ${feed['walkDate']}'),
                  if (feed['walkTime'] != null)
                    _buildInfoRow('시간 : ${feed['walkTime']}'),
                  if (feed['distance'] != null)
                    _buildInfoRow('거리 : ${feed['distance']}km'),
                  if (feed['title'] != null)
                    _buildInfoRow('제목 : ${feed['title']}'),
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
      child: Text(
        text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
    );
  }
}
