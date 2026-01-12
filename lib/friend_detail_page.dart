import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'posts_screen.dart';
import 'following_screen.dart';
import 'followers_screen.dart';
import 'user_service.dart';

class FriendDetailPage extends StatefulWidget {
  final Map<String, dynamic> user;

  const FriendDetailPage({super.key, required this.user});

  @override
  State<FriendDetailPage> createState() => _FriendDetailPageState();
}

class _FriendDetailPageState extends State<FriendDetailPage> {
  int _postsCount = 0;
  int _followingCount = 0;
  int _followersCount = 0;
  bool _isFollowing = false;
  bool _isBlocked = false;
  bool _hasPet = true;  // 사용하지 않는 변수지만 UI에서 필요할 수 있어 유지
  bool _isOwnProfile = false;
  List<Map<String, dynamic>> _pets = [];
  
  // 실시간 감지를 위한 StreamSubscription
  StreamSubscription<QuerySnapshot>? _followSubscription;
  StreamSubscription<QuerySnapshot>? _blockSubscription;
  StreamSubscription<QuerySnapshot>? _followingCountSubscription;
  StreamSubscription<QuerySnapshot>? _followersCountSubscription;
  StreamSubscription<QuerySnapshot>? _postsCountSubscription;

  @override
  void initState() {
    super.initState();
    _checkIfOwnProfile();
    _loadUserStats();
    _loadUserPets();
    _setupRealtimeListeners();
  }

  @override
  void dispose() {
    _disposeListeners();
    super.dispose();
  }

  void _disposeListeners() {
    _followSubscription?.cancel();
    _blockSubscription?.cancel();
    _followingCountSubscription?.cancel();
    _followersCountSubscription?.cancel();
    _postsCountSubscription?.cancel();
    _followSubscription = null;
    _blockSubscription = null;
    _followingCountSubscription = null;
    _followersCountSubscription = null;
    _postsCountSubscription = null;
  }

  void _checkIfOwnProfile() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final targetUserId = widget.user['uid'];
    setState(() {
      _isOwnProfile = currentUserId == targetUserId;
    });
  }

  Future<void> _loadUserPets() async {
    final targetUserId = widget.user['uid'];
    if (targetUserId != null) {
      try {
        // my_page_screen과 동일하게 UserService 사용
        final pets = await UserService.getUserPets(targetUserId);
        
        setState(() {
          _pets = pets;
        });
      } catch (e) {
        // 개발 중 디버깅용, 프로덕션에서는 제거 권장
        print('반려동물 데이터 로드 오류: $e');
      }
    }
  }

  Future<void> _loadUserStats() async {
    final targetUserId = widget.user['uid'];
    if (targetUserId != null) {
      try {
        // my_page_screen과 동일하게 UserService 사용
        final postsCount = await UserService.getUserPostsCount(targetUserId);
        final followingCount = await UserService.getUserFollowingCount(targetUserId);
        final followersCount = await UserService.getUserFollowersCount(targetUserId);
        
        setState(() {
          _postsCount = postsCount;
          _followingCount = followingCount;
          _followersCount = followersCount;
        });
      } catch (e) {
        // 개발 중 디버깅용, 프로덕션에서는 제거 권장
        print('사용자 통계 로드 오류: $e');
      }
    }
  }

  void _setupRealtimeListeners() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
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
            _isFollowing = snapshot.docs.isNotEmpty;
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

      // 팔로잉 수 실시간 감지
      _followingCountSubscription = FirebaseFirestore.instance
          .collection('following')
          .where('userId', isEqualTo: targetUserId)
          .snapshots()
          .listen((snapshot) {
        if (mounted) {
          setState(() {
            _followingCount = snapshot.docs.length;
          });
        }
      });

      // 팔로워 수 실시간 감지
      _followersCountSubscription = FirebaseFirestore.instance
          .collection('followers')
          .where('userId', isEqualTo: targetUserId)
          .snapshots()
          .listen((snapshot) {
        if (mounted) {
          setState(() {
            _followersCount = snapshot.docs.length;
          });
        }
      });

      // 게시물 수 실시간 감지
      _postsCountSubscription = FirebaseFirestore.instance
          .collection('posts')
          .where('userId', isEqualTo: targetUserId)
          .snapshots()
          .listen((snapshot) {
        if (mounted) {
          setState(() {
            _postsCount = snapshot.docs.length;
          });
        }
      });
    }
  }

  Future<void> _toggleFollow() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final targetUserId = widget.user['uid'];
    
    if (currentUserId != null && targetUserId != null) {
      if (_isFollowing) {
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

  Future<void> _toggleBlock() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final targetUserId = widget.user['uid'];
    
    if (currentUserId != null && targetUserId != null) {
      if (_isBlocked) {
        // 차단 해제
        final blockedDocs = await FirebaseFirestore.instance
            .collection('blocked_users')
            .where('userId', isEqualTo: currentUserId)
            .where('blockedUserId', isEqualTo: targetUserId)
            .get();
        
        for (var doc in blockedDocs.docs) {
          await doc.reference.delete();
        }
      } else {
        // 차단
        await FirebaseFirestore.instance
            .collection('blocked_users')
            .add({
          'userId': currentUserId,
          'blockedUserId': targetUserId,
          'timestamp': FieldValue.serverTimestamp(),
        });
        
        // 차단 시 팔로우 관계도 제거
        if (_isFollowing) {
          await _toggleFollow();
        }
      }
      
      // 상태는 실시간 리스너가 업데이트하므로 setState 불필요
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF233554),
        elevation: 0,
        toolbarHeight: 40,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildProfileSection(),
            _buildTabsSection(),
            _buildCheckPetSection(),
            if (!_isOwnProfile) ...[
              const SizedBox(height: 20),
              _buildBlockButton(),
            ],
            const SizedBox(height: 20), // 하단 여백
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person,
              size: 40,
              color: Colors.grey,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.user['nickname'] ?? '친구 닉네임',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  widget.user['bio'] ?? '친구 소개글입니다.',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          if (!_isOwnProfile)
            ElevatedButton(
              onPressed: _isBlocked ? null : _toggleFollow,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isBlocked ? Colors.grey : (_isFollowing ? Colors.grey[300] : const Color(0xFF233554)),
                foregroundColor: _isFollowing ? Colors.black : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              ),
              child: Text(
                _isBlocked ? '차단됨' : (_isFollowing ? '팔로잉' : '팔로우'),
                style: const TextStyle(fontSize: 14),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTabsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTabButton('게시글', 0, _postsCount),
                _buildTabButton('팔로잉', 1, _followingCount),
                _buildTabButton('팔로워', 2, _followersCount),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String title, int index, int count) {
    return GestureDetector(
      onTap: () {
        // 해당 화면으로 이동
        switch (index) {
          case 0:
            Navigator.push(context, MaterialPageRoute(builder: (context) => const PostsScreen()));
            break;
          case 1:
            Navigator.push(context, MaterialPageRoute(builder: (context) => const FollowingScreen()));
            break;
          case 2:
            Navigator.push(context, MaterialPageRoute(builder: (context) => const FollowersScreen()));
            break;
        }
      },
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.normal,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            count.toString(),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildCheckPetSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '반려동물 확인',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 15),
            _pets.isEmpty
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '등록된 반려동물이 없습니다',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                : Column(
                    children: _pets.map((pet) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.pets, color: Colors.grey),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    pet['name'] ?? '이름 없음',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    pet['breed'] ?? '품종 정보 없음',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (pet['isRepresentative'] == true)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF233554),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  '대표',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlockButton() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF233554),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: _showBlockDialog,
          child: Text(
            _isBlocked ? '차단 해제' : '차단',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  void _showBlockDialog() {
    if (_isBlocked) {
      // 차단 해제 확인창
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('차단 해제'),
            content: Text('${widget.user['nickname'] ?? '이 사용자'}의 차단을 해제하시겠습니까?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('아니요'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _toggleBlock();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${widget.user['nickname'] ?? '사용자'}를 차단 해제했습니다.')),
                  );
                },
                child: const Text('예', style: TextStyle(color: Colors.red)),
              ),
            ],
          );
        },
      );
    } else {
      // 차단 확인창 (팔로우 해제 안내 포함)
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('사용자 차단'),
            content: _isFollowing 
                ? Text('${widget.user['nickname'] ?? '이 사용자'}는 현재 팔로우 중입니다.\n팔로우된 계정을 차단 시 팔로우는 자동으로 해제 됩니다. 차단 하시겠습니까?')
                : Text('${widget.user['nickname'] ?? '이 사용자'}를 차단하시겠습니까?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('아니요'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _toggleBlock();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${widget.user['nickname'] ?? '사용자'}를 차단했습니다.')),
                  );
                },
                child: const Text('예', style: TextStyle(color: Colors.red)),
              ),
            ],
          );
        },
      );
    }
  }
}
