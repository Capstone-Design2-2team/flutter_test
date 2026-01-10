import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FriendDetailPage extends StatefulWidget {
  final Map<String, dynamic> user;

  const FriendDetailPage({super.key, required this.user});

  @override
  State<FriendDetailPage> createState() => _FriendDetailPageState();
}

class _FriendDetailPageState extends State<FriendDetailPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isFollowing = false;
  bool _isLoading = true;
  Map<String, dynamic>? _fullUserData;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Get full user data from Firebase
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(widget.user['uid'] ?? widget.user['user_id'])
          .get();

      if (userDoc.exists) {
        setState(() {
          _fullUserData = userDoc.data() as Map<String, dynamic>;
        });
      }

      // Check if current user follows this user
      DocumentSnapshot followDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('following')
          .doc(widget.user['uid'] ?? widget.user['user_id'])
          .get();

      setState(() {
        _isFollowing = followDoc.exists;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading user data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFollow() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final targetUserId = widget.user['uid'] ?? widget.user['user_id'];
      DocumentReference followRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('following')
          .doc(targetUserId);

      if (_isFollowing) {
        await followRef.delete();
        setState(() => _isFollowing = false);
      } else {
        await followRef.set({
          'followingUserId': targetUserId,
          'createdAt': Timestamp.now(),
        });
        setState(() => _isFollowing = true);
      }
    } catch (e) {
      print('Error toggling follow: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final userData = _fullUserData ?? widget.user;
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF233554),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(userData['nickname'] ?? '프로필'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF233554),
                        image: userData['profile_image'] != null
                            ? DecorationImage(
                                image: NetworkImage(userData['profile_image']),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: userData['profile_image'] == null
                          ? const Icon(Icons.person, size: 60, color: Colors.white)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    "닉네임",
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    userData['nickname'] ?? '알 수 없음',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "소개",
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    userData['bio'] ?? '소개글이 없습니다.',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "팔로워",
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${userData['follower_count'] ?? 0}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "팔로잉",
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${userData['following_count'] ?? 0}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 30),
                  Center(
                    child: ElevatedButton(
                      onPressed: _toggleFollow,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isFollowing ? Colors.grey : const Color(0xFF233554),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                      ),
                      child: Text(
                        _isFollowing ? '팔로잉' : '팔로우',
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
