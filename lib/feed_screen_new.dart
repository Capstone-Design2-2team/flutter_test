import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';

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

    print('DEBUG: Setting up realtime listeners for user: ${user.uid}');

    // 피드 실시간 감지 (현재 사용자의 피드만)
    _firestore
        .collection('feeds')
        .where('userId', isEqualTo: user.uid)  // 현재 사용자의 피드만 필터링
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
          if (mounted) {
            print('DEBUG: ===== FEED SNAPSHOT UPDATE =====');
            print('DEBUG: Feed snapshot updated with ${snapshot.docs.length} documents');
            
            // 데이터 변경 시 즉시 UI 업데이트
            if (snapshot.docs.isNotEmpty) {
              print('DEBUG: Changes detected, updating UI immediately');
              
              List<Map<String, dynamic>> updatedFeeds = [];
              for (var doc in snapshot.docs) {
                final data = doc.data() as Map<String, dynamic>?;
                if (data != null) {
                  updatedFeeds.add({
                    'id': data['id'] ?? doc.id, // Firestore에 저장된 id 필드 우선 사용
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
                _feeds = updatedFeeds;
                _isLoading = false;
              });
              
              print('DEBUG: UI updated with ${updatedFeeds.length} feeds');
            }
          }
        });
  }

  Future<void> _loadFeeds() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // 피드 목록 가져오기 (현재 사용자의 피드만)
      final feedsSnapshot = await _firestore
          .collection('feeds')
          .where('userId', isEqualTo: user.uid)  // 현재 사용자의 피드만 필터링
          .orderBy('createdAt', descending: true)
          .get();

      print('DEBUG: Loaded ${feedsSnapshot.docs.length} feeds for user ${user.uid}');

      List<Map<String, dynamic>> feeds = [];

      for (var doc in feedsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null) {
          print('DEBUG: Processing feed document:');
          print('  Document ID: ${doc.id}');
          print('  Data ID: ${data['id']}');
          print('  Title: ${data['title']}');
          print('  Image URL: ${data['imageUrl']}');
          print('  Pet Name: ${data['petName']}');
          
          feeds.add({
            'id': data['id'] ?? doc.id, // Firestore에 저장된 id 필드 우선 사용
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
      
      print('DEBUG: ===== FEED LOADING COMPLETED =====');
      print('DEBUG: Total feeds loaded: ${feeds.length}');
      for (int i = 0; i < feeds.length; i++) {
        print('DEBUG: Feed $i: ID=${feeds[i]['id']}, Title=${feeds[i]['title']}, Pet=${feeds[i]['petName']}');
      }
      print('DEBUG: ===== END FEED LOADING =====');
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              print('DEBUG: Manual refresh triggered');
              _loadFeeds();
            },
            tooltip: '새로고침',
          ),
        ],
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
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '산책을 시작하고 피드를 남겨보세요',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
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
                      image:
                          feed['imageUrl'] != null &&
                              feed['imageUrl'].isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(feed['imageUrl']),
                              fit: BoxFit.cover,
                            )
                          : null,
                      color:
                          feed['imageUrl'] == null || feed['imageUrl'].isEmpty
                          ? Colors.grey[200]
                          : null,
                    ),
                    child: feed['imageUrl'] == null || feed['imageUrl'].isEmpty
                        ? const Icon(Icons.pets, size: 40, color: Colors.grey)
                        : null,
                  ),
                );
              },
            ),
    );
  }
}

class FeedDetailScreen extends StatefulWidget {
  final Map<String, dynamic> feed;

  const FeedDetailScreen({super.key, required this.feed});

  @override
  State<FeedDetailScreen> createState() => _FeedDetailScreenState();
}

class _FeedDetailScreenState extends State<FeedDetailScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLiked = false;
  int _likesCount = 0;
  late AnimationController _heartController;
  late Animation<double> _heartScale;
  bool _showBigHeart = false;

  @override
  void initState() {
    super.initState();
    _checkIfLiked();
    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _heartScale = Tween<double>(begin: 0.8, end: 1.4).animate(
      CurvedAnimation(parent: _heartController, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _heartController.dispose();
    super.dispose();
  }

  Future<void> _checkIfLiked() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final feedDoc = await _firestore
          .collection('feeds')
          .doc(widget.feed['id'])
          .get();

      final data = feedDoc.data();
      if (data != null) {
        final likedBy = data['likedBy'] as List<dynamic>? ?? [];
        final currentLikes = data['likes'] as int? ?? 0;
        setState(() {
          _isLiked = likedBy.contains(user.uid);
          _likesCount = currentLikes;
        });
      }
    } catch (e) {
      print('Error checking like status: $e');
    }
  }

  Future<void> _toggleLike() async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() {
      _isLiked = !_isLiked;
      if (_isLiked) {
        _likesCount++;
      } else {
        _likesCount--;
      }
    });

    try {
      final feedRef = _firestore.collection('feeds').doc(widget.feed['id']);
      final notificationsRef = _firestore.collection('like_notifications');
      final ownerId = widget.feed['userId']?.toString();
      final feedImage = widget.feed['imageUrl']?.toString();
      final currentUserId = user.uid;
      final notifId = '${widget.feed['id']}_$currentUserId';

      if (_isLiked) {
        await feedRef.update({
          'likes': FieldValue.increment(1),
          'likedBy': FieldValue.arrayUnion([user.uid]),
        });
        if (ownerId != null && ownerId.isNotEmpty) {
          await notificationsRef.doc(notifId).set({
            'ownerId': ownerId,
            'likerId': currentUserId,
            'feedId': widget.feed['id'],
            'feedImage': feedImage,
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      } else {
        await feedRef.update({
          'likes': FieldValue.increment(-1),
          'likedBy': FieldValue.arrayRemove([user.uid]),
        });
        await notificationsRef.doc(notifId).delete().catchError((_) {});
      }
    } catch (e) {
      print('Error toggling like: $e');
      setState(() {
        _isLiked = !_isLiked;
        if (_isLiked) {
          _likesCount++;
        } else {
          _likesCount--;
        }
      });
    }
  }

  void _onDoubleTapLike() {
    if (!_isLiked) {
      _toggleLike();
    }
    setState(() {
      _showBigHeart = true;
    });
    _heartController.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() {
        _showBigHeart = false;
      });
      _heartController.reset();
    });
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
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 피드 이미지
            if (widget.feed['imageUrl'] != null &&
                widget.feed['imageUrl'].isNotEmpty)
              GestureDetector(
                onDoubleTap: _onDoubleTapLike,
                child: Container(
                  width: double.infinity,
                  height: 300,
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: NetworkImage(widget.feed['imageUrl']),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Stack(
                    children: [
                      // 이미지 전체를 덮는 반투명 레이어
                      Container(
                        width: double.infinity,
                        height: double.infinity,
                        color: Colors.black.withOpacity(0.3),
                      ),
                      // 하트 모양 아이콘 표시
                      Positioned(
                        top: 10,
                        right: 10,
                        child: GestureDetector(
                          onTap: _toggleLike,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              transitionBuilder: (child, animation) =>
                                  ScaleTransition(
                                    scale: animation,
                                    child: child,
                                  ),
                              child: Icon(
                                _isLiked
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                key: ValueKey<bool>(_isLiked),
                                color: _isLiked ? Colors.red : Colors.grey[700],
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // 더블탭 시 나타나는 큰 하트
                      IgnorePointer(
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: _showBigHeart ? 1.0 : 0.0,
                          child: ScaleTransition(
                            scale: _heartScale,
                            child: const Icon(
                              Icons.favorite,
                              color: Colors.white,
                              size: 120,
                              shadows: [
                                Shadow(color: Colors.black54, blurRadius: 12),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
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
                        widget.feed['petName'] ?? '반려동물',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '산책 기록',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.share, color: Colors.grey[700]),
                    onPressed: () {
                      _shareFeed(widget.feed);
                    },
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
                  // 좋아요
                  GestureDetector(
                    onTap: _toggleLike,
                    child: Row(
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          transitionBuilder: (child, animation) =>
                              ScaleTransition(scale: animation, child: child),
                          child: Icon(
                            _isLiked ? Icons.favorite : Icons.favorite_border,
                            key: ValueKey<bool>(_isLiked),
                            size: 24,
                            color: _isLiked ? Colors.red : Colors.grey[700],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _likesCount.toString(),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 내용
                  if (widget.feed['content'] != null &&
                      widget.feed['content'].isNotEmpty)
                    Text(
                      widget.feed['content'],
                      style: const TextStyle(fontSize: 16, height: 1.4),
                    ),
                  const SizedBox(height: 16),

                  // 산책 기록 제목
                  const Text(
                    '산책 기록',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF233554),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 산책 정보
                  if (widget.feed['walkDate'] != null)
                    _buildInfoRow('날짜 : ${widget.feed['walkDate']}'),
                  if (widget.feed['walkTime'] != null)
                    _buildInfoRow('시간 : ${widget.feed['walkTime']}'),
                  if (widget.feed['distance'] != null)
                    _buildInfoRow('거리 : ${widget.feed['distance']}km'),
                  if (widget.feed['title'] != null)
                    _buildInfoRow('제목 : ${widget.feed['title']}'),
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

  // 이미지 모달 표시 함수
  void _showImageModal(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            child: Stack(
              children: [
                // 반투명 레이어
                Container(
                  width: double.infinity,
                  height: double.infinity,
                  color: Colors.black.withOpacity(0.5),
                ),
                // 이미지
                Center(
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.9,
                    height: MediaQuery.of(context).size.height * 0.8,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 닫기 버튼
                        Align(
                          alignment: Alignment.topRight,
                          child: GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // 이미지
                        Expanded(
                          child: InteractiveViewer(
                            child: Image.network(imageUrl, fit: BoxFit.contain),
                          ),
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
  }

  // 피드 공유 기능
  void _shareFeed(Map<String, dynamic> feed, {bool isPublic = false}) {
    final images = feed['images'] as List<dynamic>? ?? [];
    final content = feed['content'] as String? ?? '산책 기록';
    final distance = (feed['distance'] as double?);
    final duration = (feed['duration'] as int?);
    final lines = <String>[];
    lines.add(content);
    if (distance != null) {
      lines.add('거리: ${distance.toStringAsFixed(1)}km');
    }
    if (duration != null) {
      lines.add('시간: ${duration}분');
    }
    final url = images.isNotEmpty ? images.first.toString() : '';
    if (url.isNotEmpty) {
      lines.add(url);
    }
    Share.share(lines.join('\n'));
  }

  // 피드에 내용 추가 기능
  void _addToFeed(Map<String, dynamic> feed) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final feedRef = FirebaseFirestore.instance.collection('feeds').doc();
      final images = feed['images'] as List<dynamic>? ?? [];

      await feedRef.set({
        'feedId': feedRef.id,
        'userId': user.uid,
        'type': 'walk',
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
        'content': feed['content'] ?? '산책 기록',
        'moodEmoji': feed['moodEmoji'] ?? '😊',
        'images': images,
        'distanceKm': feed['distance'],
        'durationMinutes': feed['duration'],
        'startTime': feed['startTime'],
        'endTime': feed['endTime'],
        'route': feed['route'],
        'petIds': feed['petIds'] ?? [],
        'petInfo': feed['petInfo'] ?? [],
        'likeCount': 0,
        'commentCount': 0,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('피드에 추가되었습니다.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('피드 추가 오류: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('피드 추가 실패: $e')));
    }
  }

  // 산책 완료 시 피드에 공유하기 체크박스 선택 기능
  void _showShareDialog(BuildContext context, Map<String, dynamic> feed) {
    _addToFeed(feed);
  }
}
