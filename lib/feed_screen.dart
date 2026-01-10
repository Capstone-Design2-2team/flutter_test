import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'friend_detail_page.dart';

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
  }

  Future<void> _loadFeeds() async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('feeds')
          .orderBy('createdAt', descending: true)
          .get();

      List<Map<String, dynamic>> feeds = [];
      for (var doc in snapshot.docs) {
        Map<String, dynamic> feedData = doc.data() as Map<String, dynamic>;
        feedData['id'] = doc.id;

        // Get user info from users collection
        DocumentSnapshot userDoc = await _firestore
            .collection('users')
            .doc(feedData['userId'])
            .get();

        if (userDoc.exists) {
          feedData['userInfo'] = userDoc.data() as Map<String, dynamic>;
          print('User info loaded for ${feedData['userId']}: ${feedData['userInfo']['nickname']}');
        } else {
          // Fallback: create basic user info
          print('User info not found for ${feedData['userId']}, using fallback');
          feedData['userInfo'] = {
            'nickname': '알 수 없는 사용자',
            'bio': '산책을 즐기는 분',
          };
        }

        feeds.add(feedData);
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
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              setState(() {
                _isLoading = true;
                _feeds.clear();
              });
              _loadFeeds();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _feeds.isEmpty
          ? const Center(
        child: Text(
          '등록된 피드가 없습니다.',
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      )
          : RefreshIndicator(
        onRefresh: _loadFeeds,
        child: Column(
          children: [
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: _feeds.length,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FeedDetailScreen(feedData: _feeds[index]),
                        ),
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: NetworkImage(
                            _feeds[index]['imageUrl'] ?? 'https://picsum.photos/200/200?random=$index',
                          ),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FeedDetailScreen extends StatefulWidget {
  final Map<String, dynamic> feedData;

  const FeedDetailScreen({super.key, required this.feedData});

  @override
  State<FeedDetailScreen> createState() => _FeedDetailScreenState();
}

class _FeedDetailScreenState extends State<FeedDetailScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLiked = false;
  bool _isFollowing = false;
  int _likeCount = 0;
  bool _isLoading = true;
  bool _isOwnPost = false;

  @override
  void initState() {
    super.initState();
    _loadInteractionStatus();
  }

  Future<void> _loadInteractionStatus() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Check if this is own post
      _isOwnPost = widget.feedData['userId'] == user.uid;

      // Check if user liked this feed
      DocumentSnapshot likeDoc = await _firestore
          .collection('feeds')
          .doc(widget.feedData['id'])
          .collection('likes')
          .doc(user.uid)
          .get();

      // Check if user follows this feed owner (only if not own post)
      DocumentSnapshot followDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('following')
          .doc(widget.feedData['userId'])
          .get();

      // Get like count
      QuerySnapshot likesSnapshot = await _firestore
          .collection('feeds')
          .doc(widget.feedData['id'])
          .collection('likes')
          .get();

      setState(() {
        _isLiked = likeDoc.exists;
        _isFollowing = followDoc.exists;
        _likeCount = likesSnapshot.docs.length;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading interaction status: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleLike() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인이 필요합니다.')),
        );
        return;
      }

      DocumentReference likeRef = _firestore
          .collection('feeds')
          .doc(widget.feedData['id'])
          .collection('likes')
          .doc(user.uid);

      if (_isLiked) {
        await likeRef.delete();
        setState(() {
          _isLiked = false;
          _likeCount--;
        });
        print('Like removed from feed ${widget.feedData['id']}');
      } else {
        await likeRef.set({
          'userId': user.uid,
          'createdAt': Timestamp.now(),
        });
        setState(() {
          _isLiked = true;
          _likeCount++;
        });
        print('Like added to feed ${widget.feedData['id']}');
      }
    } catch (e) {
      print('Error toggling like: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류가 발생했습니다: $e')),
      );
    }
  }

  Future<void> _toggleFollow() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인이 필요합니다.')),
        );
        return;
      }

      final targetUserId = widget.feedData['userId'];
      DocumentReference followRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('following')
          .doc(targetUserId);

      if (_isFollowing) {
        await followRef.delete();
        setState(() => _isFollowing = false);
        print('Unfollowed user: $targetUserId');
      } else {
        await followRef.set({
          'followingUserId': targetUserId,
          'createdAt': Timestamp.now(),
        });
        setState(() => _isFollowing = true);
        print('Followed user: $targetUserId');
      }
    } catch (e) {
      print('Error toggling follow: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류가 발생했습니다: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
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
        body: const Center(child: CircularProgressIndicator()),
      );
    }

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
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FriendDetailPage(
                            user: widget.feedData['userInfo'] ?? {},
                          ),
                        ),
                      );
                    },
                    child: CircleAvatar(
                      radius: 25,
                      backgroundColor: const Color(0xFF233554),
                      backgroundImage: widget.feedData['userInfo']?['profileImage'] != null
                          ? NetworkImage(widget.feedData['userInfo']['profileImage'])
                          : null,
                      child: widget.feedData['userInfo']?['profileImage'] == null
                          ? const Icon(Icons.person, color: Colors.white)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FriendDetailPage(
                              user: widget.feedData['userInfo'] ?? {},
                            ),
                          ),
                        );
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.feedData['userInfo']?['nickname'] ?? '닉네임',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            widget.feedData['userInfo']?['bio'] ?? '한줄 소개',
                            style: const TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!_isOwnPost)
                    ElevatedButton(
                      onPressed: _toggleFollow,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isFollowing ? Colors.grey : const Color(0xFF233554),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: Text(
                        _isFollowing ? '팔로잉' : '팔로우',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
            Image.network(
              widget.feedData['imageUrl'] ?? 'https://picsum.photos/400/300',
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
                    children: [
                      GestureDetector(
                        onTap: _toggleLike,
                        child: Icon(
                          _isLiked ? Icons.favorite : Icons.favorite_border,
                          size: 24,
                          color: _isLiked ? Colors.red : Colors.black,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$_likeCount',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.feedData['title'] ?? '산책 기록',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF233554)),
                  ),
                  const SizedBox(height: 12),
                  if (widget.feedData['walkDate'] != null)
                    _buildInfoRow(widget.feedData['walkDate']),
                  if (widget.feedData['walkTime'] != null)
                    _buildInfoRow('산책시간 : ${widget.feedData['walkTime']}'),
                  if (widget.feedData['distance'] != null)
                    _buildInfoRow('총 거리 : ${widget.feedData['distance']}km'),
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