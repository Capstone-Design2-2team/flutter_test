import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_service.dart';

class FollowersScreen extends StatefulWidget {
  const FollowersScreen({super.key});

  @override
  State<FollowersScreen> createState() => _FollowersScreenState();
}

class _FollowersScreenState extends State<FollowersScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Map<String, dynamic>> _followersUsers = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadFollowersUsers();
  }

  Future<void> _loadFollowersUsers() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('No user logged in');
        setState(() => _isLoading = false);
        return;
      }

      print('Loading followers users for user: ${user.uid}');

      // 1. 먼저 followers 컬렉션의 모든 데이터 확인 (테스트용)
      final allFollows = await _firestore.collection('followers').get();
      print('Total follow records in database: ${allFollows.docs.length}');
      
      // 2. 현재 사용자의 팔로워 데이터만 필터링
      final followersSnapshot = await _firestore
          .collection('followers')
          .where('userId', isEqualTo: user.uid)
          .get();

      print('Found ${followersSnapshot.docs.length} followers records for current user');

      // 3. 모든 followers 데이터 출력 (디버깅용)
      for (var doc in allFollows.docs) {
        final data = doc.data();
        print('All follow record - ID: ${doc.id}, userId: ${data['userId']}, followerId: ${data['followerId']}, current_user: ${user.uid}');
      }

      // 4. 현재 사용자의 팔로워 데이터 상세 출력
      for (var doc in followersSnapshot.docs) {
        final data = doc.data();
        print('Current user followers - ID: ${doc.id}, userId: ${data['userId']}, followerId: ${data['followerId']}, timestamp: ${data['timestamp']}');
      }

      if (followersSnapshot.docs.isEmpty) {
        print('No followers records found for current user');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      List<String> followersIds = followersSnapshot.docs
          .map((doc) => doc['followerId'] as String)
          .toList();

      print('Followers IDs: $followersIds');

      // 5. users 컬렉션의 모든 데이터 확인해서 uid 필드 확인
      final allUsers = await _firestore.collection('users').get();
      print('Total users in database: ${allUsers.docs.length}');
      
      // 6. 모든 사용자의 uid 필드 출력
      for (var doc in allUsers.docs) {
        final data = doc.data() as Map<String, dynamic>;
        print('All users - Document ID: ${doc.id}, uid: ${data['uid']}, nickname: ${data['nickname']}');
      }

      // 7. 팔로워 사용자 정보 가져오기 - uid 필드로 조회
      List<Map<String, dynamic>> followersUsers = [];
      
      for (String followerId in followersIds) {
        try {
          // uid 필드로 사용자 찾기
          final userQuery = await _firestore
              .collection('users')
              .where('uid', isEqualTo: followerId)
              .get();
          
          if (userQuery.docs.isNotEmpty) {
            final userDoc = userQuery.docs.first;
            final data = userDoc.data() as Map<String, dynamic>;
            print('Found user by uid - Document ID: ${userDoc.id}, uid: ${data['uid']}, nickname: ${data['nickname']}, user_id: ${data['user_id']}, imageUrl: ${data['imageUrl']}');
            
            followersUsers.add({
              'id': userDoc.id,
              'uid': data['uid'],
              'nickname': data['nickname'] ?? '사용자',
              'user_id': data['user_id'] ?? '',
              'imageUrl': data['imageUrl'],
              'createdAt': data['createdAt'] ?? Timestamp.now(),
            });
          } else {
            // uid 필드로 찾지 못하면 문서 ID로 시도
            print('User not found by uid: $followerId, trying by document ID...');
            final userDoc = await _firestore.collection('users').doc(followerId).get();
            if (userDoc.exists) {
              final data = userDoc.data() as Map<String, dynamic>;
              print('Found user by document ID - Document ID: ${userDoc.id}, uid: ${data['uid']}, nickname: ${data['nickname']}');
              
              followersUsers.add({
                'id': userDoc.id,
                'uid': data['uid'] ?? userDoc.id,
                'nickname': data['nickname'] ?? '사용자',
                'user_id': data['user_id'] ?? '',
                'imageUrl': data['imageUrl'],
                'createdAt': data['createdAt'] ?? Timestamp.now(),
              });
            } else {
              print('User not found for ID: $followerId (both uid and document ID failed)');
            }
          }
        } catch (e) {
          print('Error fetching user $followerId: $e');
        }
      }

      print('Total followers users to display: ${followersUsers.length}');

      setState(() {
        _followersUsers = followersUsers;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading followers users: $e');
      print('Stack trace: ${StackTrace.current}');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _removeFollower(String userId) async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) return;

      print('Removing follower: $userId');

      // 팔로워 관계 삭제
      await _firestore
          .collection('followers')
          .where('userId', isEqualTo: currentUserId)
          .where('followerId', isEqualTo: userId)
          .get()
          .then((snapshot) {
        for (var doc in snapshot.docs) {
          print('Deleting follow relation: ${doc.id}');
          doc.reference.delete();
        }
      });

      // 팔로잉 관계도 삭제 (following 컬렉션)
      await _firestore
          .collection('following')
          .where('userId', isEqualTo: userId)
          .where('followingId', isEqualTo: currentUserId)
          .get()
          .then((snapshot) {
        for (var doc in snapshot.docs) {
          print('Deleting following relation: ${doc.id}');
          doc.reference.delete();
        }
      });

      print('Successfully removed follower: $userId');
      _loadFollowersUsers();
    } catch (e) {
      print('Error removing follower: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('팔로워를 삭제하는 데 실패했습니다.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    if (_searchQuery.isEmpty) return _followersUsers;
    
    return _followersUsers.where((user) {
      final nickname = user['nickname']?.toString().toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();
      return nickname.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF233554),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // 검색창
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(25),
            ),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: const InputDecoration(
                hintText: '검색',
                hintStyle: TextStyle(color: Colors.grey),
                prefixIcon: Icon(Icons.search, color: Colors.grey),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              ),
            ),
          ),
          
          // 사용자 목록
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredUsers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isEmpty ? '팔로워가 없습니다' : '검색 결과가 없습니다',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filteredUsers.length,
                        itemBuilder: (context, index) {
                          final user = _filteredUsers[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[300]!),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
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
                                  child: user['imageUrl'] != null && user['imageUrl'].isNotEmpty
                                      ? ClipOval(
                                          child: Image.network(
                                            user['imageUrl'],
                                            width: 50,
                                            height: 50,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) {
                                              return const Icon(
                                                Icons.person,
                                                size: 25,
                                                color: Colors.grey,
                                              );
                                            },
                                          ),
                                        )
                                      : const Icon(
                                          Icons.person,
                                          size: 25,
                                          color: Colors.grey,
                                        ),
                                ),
                                
                                const SizedBox(width: 16),
                                
                                // 사용자 정보
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user['nickname'] ?? '사용자',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        user['user_id'] ?? '',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                
                                // 삭제 버튼
                                GestureDetector(
                                  onTap: () => _removeFollower(user['id']),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Text(
                                      '삭제',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
