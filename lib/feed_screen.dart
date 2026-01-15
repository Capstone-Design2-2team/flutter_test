import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_service.dart';
import 'package:share_plus/share_plus.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Map<String, dynamic>> _walkRecords = []; // 피드에 없는 산책 기록들

  @override
  void initState() {
    super.initState();
    _loadWalkRecords();
  }

  Future<void> _loadWalkRecords() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // 현재 사용자의 산책 기록만 가져오기
      final walkSnapshot = await _firestore
          .collection('walks')
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .get();

      // 피드에 있는 기록 ID들 가져오기
      final feedSnapshot = await _firestore
          .collection('feeds')
          .where('userId', isEqualTo: user.uid)
          .get();

      final feedIds = feedSnapshot.docs.map((doc) => doc.id).toSet();

      // 피드에 없는 산책 기록만 필터링
      final availableWalks = walkSnapshot.docs
          .where((walkDoc) {
            return !feedIds.contains(walkDoc.id);
          })
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();

      setState(() {
        _walkRecords = availableWalks;
      });
    } catch (e) {
      print('산책 기록 로드 오류: $e');
    }
  }

  void _showWalkRecordsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('산책 기록 선택'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: ListView.builder(
              itemCount: _walkRecords.length,
              itemBuilder: (context, index) {
                final walk = _walkRecords[index];
                final createdAt = walk['createdAt'] as Timestamp?;
                final distanceKm = walk['distanceKm'] as double? ?? 0.0;
                final durationMinutes = walk['durationMinutes'] as int? ?? 0;

                return ListTile(
                  title: Text(
                    createdAt != null
                        ? '${createdAt.toDate().month}/${createdAt.toDate().day} 산책'
                        : '산책 기록',
                  ),
                  subtitle: Text(
                    '거리: ${distanceKm.toStringAsFixed(1)}km, 시간: ${durationMinutes}분',
                  ),
                  onTap: () {
                    Navigator.pop(context); // 다이얼로그 닫기
                    _addWalkToFeed(walk);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addWalkToFeed(Map<String, dynamic> walkData) async {
    try {
      await _firestore.collection('feeds').add({
        'userId': walkData['userId'],
        'content': walkData['content'] ?? '산책 기록',
        'images': walkData['images'] ?? [],
        'petInfo': walkData['petInfo'] ?? [],
        'createdAt': FieldValue.serverTimestamp(),
        'distanceKm': walkData['distanceKm'] ?? 0.0,
        'durationMinutes': walkData['durationMinutes'] ?? 0,
        'moodEmoji': walkData['moodEmoji'] ?? '😊',
        'likes': 0,
        'comments': 0,
        'isPublic': true, // 피드에 공개
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('피드에 추가되었습니다.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('피드 추가 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('피드 추가에 실패했습니다.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF233554),
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: user == null
          ? const Center(child: Text('로그인이 필요합니다.'))
          : StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('feeds')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        const Text('피드를 불러오는 중 오류가 발생했습니다.'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {}); // 다시 시도
                          },
                          child: const Text('다시 시도'),
                        ),
                      ],
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                // isPublic이 true인 피드만 필터링
                final publicDocs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>?;
                  if (data == null) return false;
                  final isPublic = data['isPublic'] as bool? ?? false;
                  return isPublic;
                }).toList();

                if (publicDocs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.feed_outlined, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('피드가 없습니다.'),
                        SizedBox(height: 8),
                        Text('산책 기록을 공유해보세요!'),
                        SizedBox(height: 20),
                        if (_walkRecords.isNotEmpty) ...[
                          SizedBox(
                            width: 200,
                            height: 50,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF233554),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () {
                                _showWalkRecordsDialog();
                              },
                              child: const Text(
                                '산책 기록 피드에 추가',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ],
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
                  itemCount: publicDocs.length,
                  itemBuilder: (context, index) {
                    final doc = publicDocs[index];
                    final data = doc.data() as Map<String, dynamic>?;
                    if (data == null) return const SizedBox.shrink();

                    final feedId = doc.id;
                    final images = data['images'] as List<dynamic>? ?? [];
                    final content = data['content'] as String? ?? '';
                    final petInfo = data['petInfo'] as List<dynamic>? ?? [];
                    final createdAt = data['createdAt'] as Timestamp?;
                    final distanceKm = data['distanceKm'] as double? ?? 0.0;
                    final durationMinutes =
                        data['durationMinutes'] as int? ?? 0;

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                FeedDetailScreen(feedId: feedId, data: data),
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
                            // 이미지만 표시
                            Expanded(
                              child: Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  image: images.isNotEmpty
                                      ? DecorationImage(
                                          image: NetworkImage(images.first),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: images.isEmpty
                                    ? const Center(
                                        child: Icon(
                                          Icons.image,
                                          size: 40,
                                          color: Colors.grey,
                                        ),
                                      )
                                    : null,
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
    );
  }
}

class FeedDetailScreen extends StatefulWidget {
  final String feedId;
  final Map<String, dynamic>? data;

  const FeedDetailScreen({super.key, required this.feedId, this.data});

  @override
  State<FeedDetailScreen> createState() => _FeedDetailScreenState();
}

class _FeedDetailScreenState extends State<FeedDetailScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _userInfo;
  bool _isLoading = true;
  bool _isLiked = false;
  int _likesCount = 0;
  late AnimationController _heartController;
  late Animation<double> _heartScale;
  bool _showBigHeart = false;

  void _shareFeed() {
    final images = widget.data?['images'] as List<dynamic>? ?? [];
    final content = widget.data?['content'] as String? ?? '산책 기록';
    final distanceKm = widget.data?['distanceKm'] as double?;
    final durationMinutes = widget.data?['durationMinutes'] as int?;
    final lines = <String>[];
    lines.add(content);
    if (distanceKm != null) {
      lines.add('거리: ${distanceKm.toStringAsFixed(1)}km');
    }
    if (durationMinutes != null) {
      lines.add('시간: ${durationMinutes}분');
    }
    final url = images.isNotEmpty ? images.first.toString() : '';
    if (url.isNotEmpty) {
      lines.add(url);
    }
    Share.share(lines.join('\n'));
  }

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
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
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;
    try {
      final feedDoc = await FirebaseFirestore.instance
          .collection('feeds')
          .doc(widget.feedId)
          .get();
      final data = feedDoc.data();
      if (data != null) {
        final likedBy = data['likedBy'] as List<dynamic>? ?? [];
        final currentLikes = data['likes'] as int? ?? 0;
        setState(() {
          _isLiked = likedBy.contains(currentUserId);
          _likesCount = currentLikes;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadUserInfo() async {
    final userId = widget.data?['userId'] as String?;
    if (userId != null) {
      final userInfo = await UserService.getUserInfo(userId);
      setState(() {
        _userInfo = userInfo;
        _isLoading = false;
        _likesCount = widget.data?['likes'] as int? ?? 0;
      });
    } else {
      setState(() {
        _isLoading = false;
        _likesCount = widget.data?['likes'] as int? ?? 0;
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

  Future<void> _toggleLike() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    setState(() {
      _isLiked = !_isLiked;
      if (_isLiked) {
        _likesCount++;
      } else {
        _likesCount--;
      }
    });

    try {
      final feedRef = FirebaseFirestore.instance
          .collection('feeds')
          .doc(widget.feedId);
      final notificationsRef = FirebaseFirestore.instance.collection(
        'like_notifications',
      );
      final ownerId = widget.data?['userId'] as String?;
      final images = widget.data?['images'] as List<dynamic>? ?? [];
      final feedImage = images.isNotEmpty ? images.first.toString() : null;
      final notifId = '${widget.feedId}_$currentUserId';

      if (_isLiked) {
        // 좋아요 추가
        await feedRef.update({
          'likes': FieldValue.increment(1),
          'likedBy': FieldValue.arrayUnion([currentUserId]),
        });
        if (ownerId != null) {
          await notificationsRef.doc(notifId).set({
            'ownerId': ownerId,
            'likerId': currentUserId,
            'feedId': widget.feedId,
            'feedImage': feedImage,
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      } else {
        // 좋아요 취소
        await feedRef.update({
          'likes': FieldValue.increment(-1),
          'likedBy': FieldValue.arrayRemove([currentUserId]),
        });
        // 알림 제거 (좋아요 취소 시)
        await notificationsRef.doc(notifId).delete().catchError((_) {});
      }
    } catch (e) {
      print('좋아요 업데이트 오류: $e');
      // 실패 시 원래 상태로 복원
      setState(() {
        _isLiked = !_isLiked;
        if (_isLiked) {
          _likesCount--;
        } else {
          _likesCount++;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.data?['images'] as List<dynamic>? ?? [];
    final content = widget.data?['content'] as String? ?? '';
    final petInfo = widget.data?['petInfo'] as List<dynamic>? ?? [];
    final createdAt = widget.data?['createdAt'] as Timestamp?;
    final distanceKm = widget.data?['distanceKm'] as double? ?? 0.0;
    final durationMinutes = widget.data?['durationMinutes'] as int? ?? 0;
    final moodEmoji = widget.data?['moodEmoji'] as String? ?? '';
    final likes = widget.data?['likes'] as int? ?? 0;
    final userId = widget.data?['userId'] as String?;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF233554),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: _shareFeed,
          ),
        ],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 사용자 정보
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        // 프로필 이미지
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey[300],
                            image:
                                _userInfo?['profileImageUrl'] != null &&
                                    _userInfo!['profileImageUrl'].isNotEmpty
                                ? DecorationImage(
                                    image: NetworkImage(
                                      _userInfo!['profileImageUrl'],
                                    ),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child:
                              _userInfo?['profileImageUrl'] == null ||
                                  _userInfo!['profileImageUrl'].isEmpty
                              ? const Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 25,
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        // 사용자 정보
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _userInfo?['nickname'] ?? '닉네임',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _userInfo?['introduction'] ?? '한줄 소개',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 이미지 표시
                  if (images.isNotEmpty)
                    GestureDetector(
                      onDoubleTap: _onDoubleTapLike,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: double.infinity,
                            height: 300,
                            decoration: BoxDecoration(
                              image: DecorationImage(
                                image: NetworkImage(images.first),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
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
                                    Shadow(
                                      color: Colors.black54,
                                      blurRadius: 12,
                                    ),
                                  ],
                                ),
                              ),
                            ),
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
                                    ScaleTransition(
                                      scale: animation,
                                      child: child,
                                    ),
                                child: Icon(
                                  _isLiked
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  key: ValueKey<bool>(_isLiked),
                                  size: 24,
                                  color: _isLiked
                                      ? Colors.red
                                      : Colors.grey[700],
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
                        if (content.isNotEmpty) ...[
                          Text(
                            content,
                            style: const TextStyle(fontSize: 16, height: 1.4),
                          ),
                          const SizedBox(height: 16),
                        ],

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
                        if (createdAt != null)
                          _buildInfoRow('날짜 : ${_formatDate(createdAt)}'),
                        if (durationMinutes != null)
                          _buildInfoRow('산책시간 : ${durationMinutes}분'),
                        if (distanceKm != null)
                          _buildInfoRow(
                            '총 거리 : ${distanceKm.toStringAsFixed(1)}km',
                          ),
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

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
