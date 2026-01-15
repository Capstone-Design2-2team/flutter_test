import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'friend_detail_page.dart';
import 'user_service.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchKeyword = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF233554),
        elevation: 0,
        toolbarHeight: 40,
        automaticallyImplyLeading: false,
        title: const Text(
          '친구',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 1. 검색창 영역 (이미지의 닉네임 검색 부분)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 15, 20, 15),
            child: SizedBox(
              height: 45,
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchKeyword = value;
                  });
                },
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

          // 이미지와 동일한 얇은 구분선
          const Divider(thickness: 1, color: Color(0xFFD1D1D1), height: 1),

          // 2. 친구 목록 리스트 (Firebase 연동)
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              // Firebase의 'users' 컬렉션에서 데이터를 가져옵니다.
              stream: FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Center(child: Text("오류가 발생했습니다."));
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                // 검색어 필터링 (닉네임 기준)
                final users = snapshot.data!.docs.where((doc) {
                  String nickname = doc['nickname'] ?? "";
                  return nickname.contains(_searchKeyword);
                }).toList();

                if (users.isEmpty) {
                  return const Center(child: Text("검색 결과가 없습니다."));
                }

                return ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    var userData = users[index].data() as Map<String, dynamic>;
                    // UniqueKey를 추가하여 위젯이 다시 생성될 때마다 리스너가 재설정되도록 함
                    return UserListItem(
                      key: ValueKey(userData['uid']),
                      user: userData,
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
}

class UserListItem extends StatefulWidget {
  final Map<String, dynamic> user;

  const UserListItem({super.key, required this.user});

  @override
  State<UserListItem> createState() => _UserListItemState();
}

class _UserListItemState extends State<UserListItem> {
  bool _isFollowed = false;
  bool _isLoading = false;
  bool _isBlocked = false;
  bool _isOwnProfile = false;
  StreamSubscription<QuerySnapshot>? _followSubscription;
  StreamSubscription<QuerySnapshot>? _blockSubscription;

  @override
  void initState() {
    super.initState();
    _checkFollowStatus();
  }

  Future<void> _checkFollowStatus() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final followingDoc = await FirebaseFirestore.instance
          .collection('following')
          .where('userId', isEqualTo: currentUser.uid)
          .where('followingId', isEqualTo: widget.user['uid'])
          .get();

      setState(() {
        _isFollowed = followingDoc.docs.isNotEmpty;
      });
    } catch (e) {
      print('Error checking follow status: $e');
    }
    _checkIfOwnProfile();
    _setupRealtimeListeners();
  }

  @override
  void didUpdateWidget(UserListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 사용자 데이터가 변경되면 리스너 재설정
    if (oldWidget.user['uid'] != widget.user['uid']) {
      _disposeListeners();
      _checkIfOwnProfile();
      _setupRealtimeListeners();
    }
  }

  @override
  void dispose() {
    _disposeListeners();
    super.dispose();
  }

  void _disposeListeners() {
    _followSubscription?.cancel();
    _blockSubscription?.cancel();
    _followSubscription = null;
    _blockSubscription = null;
  }

  void _checkIfOwnProfile() {
    final currentUserId = UserService.getCurrentUserId();
    final targetUserId = widget.user['uid'];
    setState(() {
      _isOwnProfile = currentUserId == targetUserId;
    });
  }

  void _setupRealtimeListeners() {
    final currentUserId = UserService.getCurrentUserId();
    final targetUserId = widget.user['uid'];
    
    // 기존 리스너 정리
    _disposeListeners();
    
    if (currentUserId != null && targetUserId != null && !_isOwnProfile) {
      // 팔로우 상태 실시간 감지
      _followSubscription = FirebaseFirestore.instance
          .collection('following')
          .where('userId', isEqualTo: currentUserId)
          .where('followingId', isEqualTo: targetUserId)
          .snapshots()
          .listen((snapshot) {
        if (mounted) {
          setState(() {
            _isFollowed = snapshot.docs.isNotEmpty;
          });
        }
      });

      // 차단 상태 실시간 감지
      _blockSubscription = FirebaseFirestore.instance
          .collection('blocked_users')
          .where('userId', isEqualTo: currentUserId)
          .where('blockedUserId', isEqualTo: targetUserId)
          .snapshots()
          .listen((snapshot) {
        if (mounted) {
          setState(() {
            _isBlocked = snapshot.docs.isNotEmpty;
          });
        }
      });
    }
  }

  Future<void> _toggleFollow() async {
    if (_isLoading) return;
    
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    setState(() => _isLoading = true);

    try {
      if (_isFollowed) {
        // 언팔로우
        await FirebaseFirestore.instance
            .collection('following')
            .where('userId', isEqualTo: currentUser.uid)
            .where('followingId', isEqualTo: widget.user['uid'])
            .get()
            .then((snapshot) {
          for (var doc in snapshot.docs) {
            doc.reference.delete();
          }
        });

        await FirebaseFirestore.instance
            .collection('followers')
            .where('userId', isEqualTo: widget.user['uid'])
            .where('followerId', isEqualTo: currentUser.uid)
            .get()
            .then((snapshot) {
          for (var doc in snapshot.docs) {
            doc.reference.delete();
          }
        });
      } else {
        // 팔로우
        await FirebaseFirestore.instance.collection('following').add({
          'userId': currentUser.uid,
          'followingId': widget.user['uid'],
          'createdAt': FieldValue.serverTimestamp(),
        });

        await FirebaseFirestore.instance.collection('followers').add({
          'userId': widget.user['uid'],
          'followerId': currentUser.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      setState(() {
        _isFollowed = !_isFollowed;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isFollowed ? '팔로우를 취소했습니다.' : '팔로우했습니다.'),
          backgroundColor: const Color(0xFF233554),
        ),
      );
    } catch (e) {
      print('Error toggling follow: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('오류가 발생했습니다.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 프로필 이미지
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              shape: BoxShape.circle,
            ),
            child: widget.user['profileImageUrl'] != null && widget.user['profileImageUrl'].isNotEmpty
                ? ClipOval(
                    child: Image.network(
                      widget.user['profileImageUrl'],
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.person, color: Colors.grey);
                      },
                    ),
                  )
                : const Icon(Icons.person, color: Colors.grey),
          ),
          const SizedBox(width: 12),
          
          // 사용자 정보
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.user['nickname'] ?? '닉네임 없음',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.user['statusMessage'] ?? '상태 메시지 없음',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          
          // 팔로우/차단 버튼
          if (!_isOwnProfile)
            Row(
              children: [
                if (_isBlocked)
                  ElevatedButton(
                    onPressed: null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: const Text('차단됨', style: TextStyle(fontSize: 12)),
                  )
                else
                  ElevatedButton(
                    onPressed: _isLoading ? null : _toggleFollow,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isFollowed ? Colors.grey : const Color(0xFF233554),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : Text(_isFollowed ? '팔로잉' : '팔로우', style: const TextStyle(fontSize: 12)),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
