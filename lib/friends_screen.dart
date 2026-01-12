import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  bool _isBlocked = false;
  bool _isOwnProfile = false;
  StreamSubscription<QuerySnapshot>? _followSubscription;
  StreamSubscription<QuerySnapshot>? _blockSubscription;

  @override
  void initState() {
    super.initState();
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
    final currentUserId = UserService.getCurrentUserId();
    final targetUserId = widget.user['uid'];
    
    if (currentUserId != null && targetUserId != null) {
      if (_isFollowed) {
        // 팔로우 취소
        final followingDocs = await FirebaseFirestore.instance
            .collection('following')
            .where('userId', isEqualTo: currentUserId)
            .where('followingId', isEqualTo: targetUserId)
            .get();
        
        for (var doc in followingDocs.docs) {
          await doc.reference.delete();
        }
        
        final followersDocs = await FirebaseFirestore.instance
            .collection('followers')
            .where('userId', isEqualTo: targetUserId)
            .where('followerId', isEqualTo: currentUserId)
            .get();
        
        for (var doc in followersDocs.docs) {
          await doc.reference.delete();
        }
      } else {
        // 팔로우 - 중복 체크 후 추가
        final existingFollowing = await FirebaseFirestore.instance
            .collection('following')
            .where('userId', isEqualTo: currentUserId)
            .where('followingId', isEqualTo: targetUserId)
            .get();
        
        if (existingFollowing.docs.isEmpty) {
          // 팔로우 관계가 없을 때만 추가
          await FirebaseFirestore.instance
              .collection('following')
              .add({
            'userId': currentUserId,
            'followingId': targetUserId,
            'timestamp': FieldValue.serverTimestamp(),
          });
          
          await FirebaseFirestore.instance
              .collection('followers')
              .add({
            'userId': targetUserId,
            'followerId': currentUserId,
            'timestamp': FieldValue.serverTimestamp(),
          });
        }
      }
      
      // 상태는 실시간 리스너가 업데이트하므로 setState 불필요
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          child: Row(
            children: [
              // 프로필 아이콘 (이미지의 원형 아이콘)
              Container(
                width: 65,
                height: 65,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF233554),
                ),
                child: const Icon(
                  Icons.person_outline, // 이미지의 사람 실루엣 아이콘
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(width: 15),

              // 닉네임 및 한 줄 소개
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FriendDetailPage(user: widget.user),
                      ),
                    );
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.user['nickname'] ?? '닉네임',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.user['introduction'] ?? '한 줄 소개',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 팔로우 버튼 (이미지의 짙은 남색 버튼)
              if (!_isOwnProfile)
                _isBlocked
                    ? ElevatedButton(
                        onPressed: null,  // friend_detail_page와 동일하게 null로 설정
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        child: const Text(
                          '차단됨',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      )
                    : ElevatedButton(
                        onPressed: _toggleFollow,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isFollowed ? Colors.grey : const Color(0xFF233554),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        child: Text(
                          _isFollowed ? '팔로잉' : '팔로우',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
            ],
          ),
        ),
        // 리스트 아이템 사이의 구분선 (선택 사항)
        const Divider(height: 1, thickness: 0.5, indent: 20, endIndent: 20),
      ],
    );
  }
}