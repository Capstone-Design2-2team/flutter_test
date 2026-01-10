import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'feed_screen.dart';

class PostsScreen extends StatefulWidget {
  const PostsScreen({super.key});

  @override
  State<PostsScreen> createState() => _PostsScreenState();
}

class _PostsScreenState extends State<PostsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Map<String, dynamic>> _userPosts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserPosts();
  }

  Future<void> _loadUserPosts() async {
    final user = _auth.currentUser;
    if (user == null) {
      print('No authenticated user found');
      setState(() => _isLoading = false);
      return;
    }

    print('Loading posts for user: ${user.uid}');

    try {
      QuerySnapshot snapshot = await _firestore
          .collection('feeds')
          .where('userId', isEqualTo: user.uid)
          .get();

      print('Found ${snapshot.docs.length} posts for user ${user.uid}');

      List<Map<String, dynamic>> posts = [];
      for (var doc in snapshot.docs) {
        Map<String, dynamic> postData = doc.data() as Map<String, dynamic>;
        postData['id'] = doc.id;
        print('Processing post: ${doc.id}, data: ${postData.keys.toList()}');

        // Get user info
        DocumentSnapshot userDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          postData['userInfo'] = userDoc.data() as Map<String, dynamic>;
          print('User info loaded: ${postData['userInfo']['nickname']}');
        } else {
          postData['userInfo'] = {
            'nickname': '알 수 없는 사용자',
            'profileImageUrl': '',
          };
          print('User info not found, using fallback');
        }

        // 추가 정보 로드 (좋아요, 댓글 수)
        postData['likes'] = postData['likes'] ?? 0;
        postData['comments'] = postData['comments'] ?? 0;
        
        // 좋아요 상태 확인
        try {
          DocumentSnapshot likeDoc = await _firestore
              .collection('feeds')
              .doc(doc.id)
              .collection('likes')
              .doc(user.uid)
              .get();
          postData['isLiked'] = likeDoc.exists;
        } catch (e) {
          postData['isLiked'] = false;
        }

        posts.add(postData);
      }

      // createdAt으로 정렬 (메모리에서)
      posts.sort((a, b) {
        final aTime = a['createdAt'] as Timestamp?;
        final bTime = b['createdAt'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime); // 내림차순
      });

      setState(() {
        _userPosts = posts;
        _isLoading = false;
      });

      print('Final posts list loaded: ${posts.length} posts');
    } catch (e) {
      print('Error loading user posts: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleLike(String postId, bool isCurrentlyLiked) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      DocumentReference likeRef = _firestore
          .collection('feeds')
          .doc(postId)
          .collection('likes')
          .doc(user.uid);

      DocumentReference feedRef = _firestore.collection('feeds').doc(postId);

      if (isCurrentlyLiked) {
        // 좋아요 취소
        await likeRef.delete();
        await feedRef.update({
          'likes': FieldValue.increment(-1),
        });
      } else {
        // 좋아요 추가
        await likeRef.set({
          'userId': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
        await feedRef.update({
          'likes': FieldValue.increment(1),
        });
      }

      // 게시글 목록 새로고침
      _loadUserPosts();
    } catch (e) {
      print('Error toggling like: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('좋아요 처리에 실패했습니다.')),
      );
    }
  }

  Future<void> _deletePost(String postId) async {
    try {
      await _firestore.collection('feeds').doc(postId).delete();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('게시글이 삭제되었습니다.'),
          backgroundColor: Colors.green,
        ),
      );
      
      // 게시글 목록 새로고침
      _loadUserPosts();
    } catch (e) {
      print('Error deleting post: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('게시글 삭제에 실패했습니다.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showDeleteDialog(String postId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('게시글 삭제'),
        content: const Text('이 게시글을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deletePost(postId);
            },
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
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
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '내 게시글',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _userPosts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.article_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '작성한 게시글이 없습니다',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '첫 번째 게시글을 작성해보세요!',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadUserPosts,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _userPosts.length,
                    itemBuilder: (context, index) {
                      final post = _userPosts[index];
                      return _buildPostCard(post);
                    },
                  ),
                ),
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post) {
    final userInfo = post['userInfo'] as Map<String, dynamic>?;
    final nickname = userInfo?['nickname'] ?? '알 수 없는 사용자';
    final profileImageUrl = userInfo?['profileImageUrl'] ?? '';
    final content = post['content'] ?? '';
    final imageUrl = post['imageUrl'] ?? '';
    final createdAt = post['createdAt'] as Timestamp?;
    final postId = post['id'] as String;
    final likes = post['likes'] as int? ?? 0;
    final comments = post['comments'] as int? ?? 0;
    final isLiked = post['isLiked'] as bool? ?? false;

    String timeAgo = '';
    if (createdAt != null) {
      final now = DateTime.now();
      final postTime = createdAt.toDate();
      final difference = now.difference(postTime);
      
      if (difference.inDays > 0) {
        timeAgo = '${difference.inDays}일 전';
      } else if (difference.inHours > 0) {
        timeAgo = '${difference.inHours}시간 전';
      } else if (difference.inMinutes > 0) {
        timeAgo = '${difference.inMinutes}분 전';
      } else {
        timeAgo = '방금 전';
      }
    }

    return GestureDetector(
      onTap: () {
        // 게시글 상세 화면으로 이동
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FeedDetailScreen(feedData: post),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 사용자 정보
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: profileImageUrl.isNotEmpty
                        ? NetworkImage(profileImageUrl)
                        : null,
                    child: profileImageUrl.isEmpty
                        ? const Icon(Icons.person, color: Colors.white, size: 20)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nickname,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          timeAgo,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'delete') {
                        _showDeleteDialog(postId);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red, size: 18),
                            SizedBox(width: 8),
                            Text('삭제'),
                          ],
                        ),
                      ),
                    ],
                    child: const Icon(Icons.more_vert, color: Colors.grey, size: 18),
                  ),
                ],
              ),
            ),
            
            // 내용
            if (content.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Text(
                  content,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.3,
                    color: Colors.black87,
                  ),
                ),
              ),
            
            // 이미지
            if (imageUrl.isNotEmpty)
              Container(
                width: double.infinity,
                height: 200,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[200],
                      child: const Center(
                        child: Icon(Icons.broken_image, color: Colors.grey, size: 32),
                      ),
                    );
                  },
                ),
              ),
            
            // 좋아요 수
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // 좋아요 버튼
                  GestureDetector(
                    onTap: () => _toggleLike(postId, isLiked),
                    child: Row(
                      children: [
                        Icon(
                          isLiked ? Icons.favorite : Icons.favorite_border,
                          color: isLiked ? Colors.red : Colors.grey[600],
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          likes.toString(),
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
