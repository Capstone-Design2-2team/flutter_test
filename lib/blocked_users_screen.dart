import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Map<String, dynamic>> _blockedUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
  }

  Future<void> _loadBlockedUsers() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // 차단된 사용자 목록 가져오기
      final blockedSnapshot = await _firestore
          .collection('blocked_users')
          .where('userId', isEqualTo: user.uid)
          .orderBy('blockedAt', descending: true)
          .get();

      List<Map<String, dynamic>> blockedUsers = [];

      for (var doc in blockedSnapshot.docs) {
        final blockedData = doc.data();
        final blockedUserId = blockedData['blockedUserId'];

        // 차단된 사용자의 상세 정보 가져오기
        final userDoc = await _firestore
            .collection('users')
            .doc(blockedUserId)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          blockedUsers.add({
            'id': doc.id,
            'userId': blockedUserId,
            'nickname': userData['nickname'] ?? '알 수 없는 사용자',
            'profileImageUrl': userData['profileImageUrl'] ?? '',
            'blockedAt': blockedData['blockedAt'],
          });
        }
      }

      setState(() {
        _blockedUsers = blockedUsers;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading blocked users: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _unblockUser(String blockedUserId, String docId) async {
    try {
      // 차단 해제 확인 다이얼로그
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('차단 해제'),
          content: const Text('이 사용자의 차단을 해제하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('해제'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        // Firestore에서 차단 기록 삭제
        await _firestore.collection('blocked_users').doc(docId).delete();

        setState(() {
          _blockedUsers.removeWhere((user) => user['id'] == docId);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('차단이 해제되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error unblocking user: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('차단 해제에 실패했습니다.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return '오늘';
    } else if (difference.inDays == 1) {
      return '어제';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}일 전';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()}주 전';
    } else {
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
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
          '차단된 사용자',
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
          : _blockedUsers.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.block,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        '차단된 사용자가 없습니다',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '사용자를 차단하면 여기에 표시됩니다',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _blockedUsers.length,
                  itemBuilder: (context, index) {
                    final user = _blockedUsers[index];
                    return _buildBlockedUserCard(user);
                  },
                ),
    );
  }

  Widget _buildBlockedUserCard(Map<String, dynamic> user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
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
              shape: BoxShape.circle,
              color: Colors.grey[300],
            ),
            child: user['profileImageUrl'] != null && user['profileImageUrl'].isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(25),
                    child: Image.network(
                      user['profileImageUrl'],
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
                  user['nickname'],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatDate(user['blockedAt'])}에 차단',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),

          // 차단 해제 버튼
          TextButton(
            onPressed: () => _unblockUser(user['userId'], user['id']),
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFF233554),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text(
              '차단 해제',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
