import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'friend_detail_page.dart';

class LikeNotificationScreen extends StatefulWidget {
  const LikeNotificationScreen({super.key});

  @override
  State<LikeNotificationScreen> createState() => _LikeNotificationScreenState();
}

class _LikeNotificationScreenState extends State<LikeNotificationScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Map<String, dynamic>> _likeNotifications = [];
  bool _isLoading = true;
  String _searchQuery = '';
  Set<String> _followingSet = {};

  @override
  void initState() {
    super.initState();
    _loadLikeNotifications();
  }

  Future<void> _loadLikeNotifications() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('No user logged in');
        setState(() => _isLoading = false);
        return;
      }

      print('Loading like notifications for owner: ${user.uid}');

      Query baseQuery = _firestore
          .collection('like_notifications')
          .where('ownerId', isEqualTo: user.uid);

      QuerySnapshot<Map<String, dynamic>> snapshot;
      try {
        snapshot =
            await baseQuery.orderBy('createdAt', descending: true).get()
                as QuerySnapshot<Map<String, dynamic>>;
      } catch (e) {
        print(
          'Primary query with orderBy failed, falling back without orderBy: $e',
        );
        snapshot = await baseQuery.get() as QuerySnapshot<Map<String, dynamic>>;
      }

      final notifications = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final likerId = data['likerId']?.toString();
        final feedId = data['feedId']?.toString();
        final feedImage = data['feedImage']?.toString();
        final createdAt = data['createdAt'] ?? Timestamp.now();

        if (likerId == null || feedId == null) continue;

        try {
          Map<String, dynamic>? userData;
          final directDoc = await _firestore
              .collection('users')
              .doc(likerId)
              .get();
          if (directDoc.exists) {
            userData = directDoc.data() as Map<String, dynamic>;
          } else {
            final query = await _firestore
                .collection('users')
                .where('uid', isEqualTo: likerId)
                .limit(1)
                .get();
            if (query.docs.isNotEmpty) {
              userData = query.docs.first.data() as Map<String, dynamic>;
            }
          }

          notifications.add({
            'id': doc.id,
            'feedId': feedId,
            'feedImage': feedImage,
            'likerId': likerId,
            'likerNickname': userData?['nickname'] ?? '사용자',
            'likerIntroduction': userData?['introduction'] ?? '',
            'likerImageUrl': userData?['imageUrl'],
            'createdAt': createdAt,
          });
        } catch (e) {
          print('Error resolving liker $likerId: $e');
        }
      }

      // Fallback for legacy field names if no results found
      if (notifications.isEmpty) {
        print('No notifications found via ownerId. Trying legacy fields...');
        final legacyOwnerIdFields = ['owner_id', 'owner'];
        for (final field in legacyOwnerIdFields) {
          try {
            final legacySnap = await _firestore
                .collection('like_notifications')
                .where(field, isEqualTo: user.uid)
                .get();
            for (final doc in legacySnap.docs) {
              final data = doc.data();
              final likerId =
                  data['likerId']?.toString() ?? data['liker_uid']?.toString();
              final feedId =
                  data['feedId']?.toString() ?? data['feed_id']?.toString();
              final feedImage =
                  data['feedImage']?.toString() ?? data['image']?.toString();
              final createdAt =
                  data['createdAt'] ?? data['timestamp'] ?? Timestamp.now();
              if (likerId == null || feedId == null) continue;
              Map<String, dynamic>? userData;
              final directDoc = await _firestore
                  .collection('users')
                  .doc(likerId)
                  .get();
              if (directDoc.exists) {
                userData = directDoc.data() as Map<String, dynamic>;
              } else {
                final query = await _firestore
                    .collection('users')
                    .where('uid', isEqualTo: likerId)
                    .limit(1)
                    .get();
                if (query.docs.isNotEmpty) {
                  userData = query.docs.first.data() as Map<String, dynamic>;
                }
              }
              notifications.add({
                'id': doc.id,
                'feedId': feedId,
                'feedImage': feedImage,
                'likerId': likerId,
                'likerNickname': userData?['nickname'] ?? '사용자',
                'likerIntroduction': userData?['introduction'] ?? '',
                'likerImageUrl': userData?['imageUrl'],
                'createdAt': createdAt,
              });
            }
            if (notifications.isNotEmpty) break;
          } catch (e) {
            print('Legacy query failed on $field: $e');
          }
        }
      }

      await _loadFollowingSet();
      setState(() {
        _likeNotifications = notifications;
        _isLoading = false;
      });
      notifications.sort((a, b) {
        final aTime = a['createdAt'] is Timestamp
            ? (a['createdAt'] as Timestamp)
            : Timestamp.now();
        final bTime = b['createdAt'] is Timestamp
            ? (b['createdAt'] as Timestamp)
            : Timestamp.now();
        return bTime.compareTo(aTime);
      });
    } catch (e) {
      print('Error loading like notifications: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadFollowingSet() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      final snapshot = await _firestore
          .collection('following')
          .where('userId', isEqualTo: user.uid)
          .get();
      final set = <String>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final followingId = data['followingId']?.toString();
        if (followingId != null) set.add(followingId);
      }
      _followingSet = set;
    } catch (e) {
      print('Error loading following set: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: const Color(0xFF233554),
        elevation: 0,
        automaticallyImplyLeading: true,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: null,
      ),
      body: Column(
        children: [
          // 검색창 (friends_screen 스타일)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 15, 20, 15),
            child: SizedBox(
              height: 45,
              child: TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText: '닉네임 검색',
                  hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                  suffixIcon: const Icon(Icons.search, color: Color(0xFF233554)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: const BorderSide(color: Color(0xFF233554), width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: const BorderSide(color: Color(0xFF233554), width: 1.5),
                  ),
                ),
              ),
            ),
          ),

          // 구분선
          const Divider(thickness: 1, color: Color(0xFFD1D1D1), height: 1),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _likeNotifications.isEmpty
                ? _buildEmptyState()
                : _buildNotificationList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite_border, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            '좋아요 알림이 없습니다.',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            '다른 사용자들이 당신의 게시물에 좋아요를 누르면 여기에 표시됩니다.',
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationList() {
    final list = _searchQuery.isEmpty
        ? _likeNotifications
        : _likeNotifications.where((n) {
            final name = (n['likerNickname'] ?? '') as String;
            return name.contains(_searchQuery);
          }).toList();
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final notification = list[index];
        return _buildNotificationItem(notification);
      },
    );
  }

  Widget _buildNotificationItem(Map<String, dynamic> notification) {
    final likerId = notification['likerId'] as String?;
    final likerData = {
      'uid': likerId,
      'nickname': notification['likerNickname'] ?? '사용자',
      'introduction': notification['likerIntroduction'] ?? '',
      'imageUrl': notification['likerImageUrl'],
    };
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // 프로필 아이콘 (friends_screen 스타일)
            Container(
              width: 65,
              height: 65,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF233554),
              ),
              child: (notification['likerImageUrl'] != null &&
                      (notification['likerImageUrl'] as String).isNotEmpty)
                  ? ClipOval(
                      child: Image.network(
                        notification['likerImageUrl'] as String,
                        width: 65,
                        height: 65,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.person_outline,
                            color: Colors.white,
                            size: 40,
                          );
                        },
                      ),
                    )
                  : const Icon(
                      Icons.person_outline,
                      color: Colors.white,
                      size: 40,
                    ),
            ),
            const SizedBox(width: 15),
            
            // 닉네임 및 한 줄 소개 (클릭 가능)
            Expanded(
              child: GestureDetector(
                onTap: () {
                  if (likerId != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FriendDetailPage(user: likerData),
                      ),
                    );
                  }
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification['likerNickname'] ?? '사용자',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      notification['likerIntroduction'] ?? '한 줄 소개',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            
            // 팔로우 버튼
            if (likerId != null && likerId != _auth.currentUser?.uid)
              _buildFollowButton(likerId),
          ],
        ),
      ),
    );
  }

  Widget _buildFollowButton(String likerId) {
    final isFollowed = _followingSet.contains(likerId);
    return ElevatedButton(
      onPressed: () => _toggleFollow(likerId, isFollowed),
      style: ElevatedButton.styleFrom(
        backgroundColor: isFollowed ? Colors.grey : const Color(0xFF233554),
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25),
        ),
      ),
      child: Text(
        isFollowed ? '팔로잉' : '팔로우',
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
      ),
    );
  }

  Future<void> _toggleFollow(String targetUserId, bool isFollowed) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;
    try {
      if (isFollowed) {
        final followingDocs = await _firestore
            .collection('following')
            .where('userId', isEqualTo: currentUser.uid)
            .where('followingId', isEqualTo: targetUserId)
            .get();
        for (var doc in followingDocs.docs) {
          await doc.reference.delete();
        }
        final followersDocs = await _firestore
            .collection('followers')
            .where('userId', isEqualTo: targetUserId)
            .where('followerId', isEqualTo: currentUser.uid)
            .get();
        for (var doc in followersDocs.docs) {
          await doc.reference.delete();
        }
        _followingSet.remove(targetUserId);
      } else {
        await _firestore.collection('following').add({
          'userId': currentUser.uid,
          'followingId': targetUserId,
          'createdAt': FieldValue.serverTimestamp(),
        });
        await _firestore.collection('followers').add({
          'userId': targetUserId,
          'followerId': currentUser.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
        _followingSet.add(targetUserId);
      }
      setState(() {});
    } catch (e) {
      print('Error toggling follow: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('팔로우 처리 중 오류가 발생했습니다.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '알 수 없음';

    try {
      if (timestamp is Timestamp) {
        final date = timestamp.toDate();
        final now = DateTime.now();
        final difference = now.difference(date);

        if (difference.inMinutes < 1) {
          return '방금 전';
        } else if (difference.inHours < 1) {
          return '${difference.inMinutes}분 전';
        } else if (difference.inDays < 1) {
          return '${difference.inHours}시간 전';
        } else if (difference.inDays < 7) {
          return '${difference.inDays}일 전';
        } else {
          return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        }
      }
    } catch (e) {
      return '알 수 없음';
    }

    return '알 수 없음';
  }
}
