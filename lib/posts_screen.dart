import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_service.dart';
import 'feed_screen.dart';

class PostsScreen extends StatefulWidget {
  const PostsScreen({super.key});

  @override
  State<PostsScreen> createState() => _PostsScreenState();
}

class _PostsScreenState extends State<PostsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Map<String, dynamic>? _userInfo;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final userInfo = await UserService.getCurrentUserInfo();
    setState(() {
      _userInfo = userInfo;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF233554),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
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
                  print('PostsScreen Error: ${snapshot.error}');
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        const Text('게시글을 불러오는 중 오류가 발생했습니다.'),
                        const SizedBox(height: 8),
                        Text(
                          '오류: ${snapshot.error}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
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

                // 현재 사용자의 게시글만 필터링
                final userDocs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>?;
                  if (data == null) return false;
                  final userId = data['userId'] as String? ?? '';
                  return userId == user.uid;
                }).toList();

                if (userDocs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.feed_outlined, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('게시글이 없습니다.'),
                        SizedBox(height: 8),
                        Text('산책 기록을 공유해보세요!'),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: userDocs.length,
                  itemBuilder: (context, index) {
                    final doc = userDocs[index];
                    final data = doc.data() as Map<String, dynamic>?;
                    if (data == null) return const SizedBox.shrink();

                    final feedId = doc.id;
                    final images = data['images'] as List<dynamic>? ?? [];
                    final content = data['content'] as String? ?? '';
                    final createdAt = data['createdAt'] as Timestamp?;
                    final moodEmoji = data['moodEmoji'] as String? ?? '';
                    final likes = data['likes'] as int? ?? 0;
                    final comments = data['comments'] as int? ?? 0;
                    final petInfo = data['petInfo'] as List<dynamic>? ?? [];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 사용자 정보 헤더
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                // 프로필 이미지
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.grey[300],
                                    image: _userInfo?['profileImageUrl'] != null && _userInfo!['profileImageUrl'].isNotEmpty
                                        ? DecorationImage(
                                            image: NetworkImage(_userInfo!['profileImageUrl']),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                  ),
                                  child: _userInfo?['profileImageUrl'] == null || _userInfo!['profileImageUrl'].isEmpty
                                      ? const Icon(Icons.person, size: 20, color: Colors.grey)
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
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        createdAt != null ? _formatDate(createdAt) : '',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // 더보기 버튼
                                IconButton(
                                  icon: const Icon(Icons.more_horiz, color: Colors.grey),
                                  onPressed: () {
                                    _showMoreOptions(context, feedId);
                                  },
                                ),
                              ],
                            ),
                          ),
                          
                          // 이미지
                          if (images.isNotEmpty)
                            GestureDetector(
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
                                width: double.infinity,
                                height: 300,
                                decoration: BoxDecoration(
                                  image: DecorationImage(
                                    image: NetworkImage(images.first),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                          
                          // 무드 이모지 - 제거됨
                          
                          // 내용
                          if (content.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                content,
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          
                          const SizedBox(height: 12),
                          
                          // 좋아요, 댓글 버튼
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                // 좋아요
                                Row(
                                  children: [
                                    Icon(Icons.favorite_border, size: 24, color: Colors.grey[700]),
                                    const SizedBox(width: 8),
                                    Text(
                                      likes.toString(),
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 24),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}일 전';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}시간 전';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}분 전';
    } else {
      return '방금 전';
    }
  }

  void _showMoreOptions(BuildContext context, String feedId) {
    final currentUserId = _auth.currentUser?.uid;
    
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '게시글 옵션',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  '게시글 삭제',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context); // 바텀 시트 닫기
                  _showDeleteConfirmation(context, feedId);
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  void _showDeleteConfirmation(BuildContext context, String feedId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('게시글 삭제'),
          content: const Text('정말로 이 게시글을 삭제하시겠습니까?\n삭제된 게시글은 복구할 수 없습니다.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // 다이얼로그 닫기
              },
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context); // 다이얼로그 닫기
                _deletePost(feedId);
              },
              child: const Text(
                '삭제',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deletePost(String feedId) async {
    try {
      await _firestore.collection('feeds').doc(feedId).delete();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('게시글이 삭제되었습니다.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('게시글 삭제 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('게시글 삭제에 실패했습니다.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
