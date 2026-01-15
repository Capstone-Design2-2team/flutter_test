import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 현재 로그인된 사용자 정보 가져오기
  static User? getCurrentUser() {
    return _auth.currentUser;
  }

  // 현재 사용자의 UID 가져오기
  static String? getCurrentUserId() {
    return _auth.currentUser?.uid;
  }

  // Firestore에서 사용자 정보 가져오기
  static Future<Map<String, dynamic>?> getUserInfo(String userId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('사용자 정보 가져오기 오류: $e');
      return null;
    }
  }

  // 현재 로그인된 사용자의 전체 정보 가져오기
  static Future<Map<String, dynamic>?> getCurrentUserInfo() async {
    final userId = getCurrentUserId();
    if (userId != null) {
      return await getUserInfo(userId);
    }
    return null;
  }

  // 게시글 수 가져오기
  static Future<int> getUserPostsCount(String userId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('feeds')
          .where('userId', isEqualTo: userId)
          .get();
      return snapshot.docs.length;
    } catch (e) {
      print('게시글 수 가져오기 오류: $e');
      return 0;
    }
  }

  // 팔로잉 수 가져오기
  static Future<int> getUserFollowingCount(String userId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('following')
          .where('userId', isEqualTo: userId)
          .get();
      return snapshot.docs.length;
    } catch (e) {
      print('팔로잉 수 가져오기 오류: $e');
      return 0;
    }
  }

  // 팔로워 수 가져오기
  static Future<int> getUserFollowersCount(String userId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('following')
          .where('followingId', isEqualTo: userId)
          .get();
      return snapshot.docs.length;
    } catch (e) {
      print('팔로워 수 가져오기 오류: $e');
      return 0;
    }
  }

  // 위치 공개 상태 가져오기
  static Future<bool> getUserLocationPublic(String userId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return data['locationPublic'] ?? false;
      }
      return false;
    } catch (e) {
      print('위치 공개 상태 가져오기 오류: $e');
      return false;
    }
  }

  // 위치 공개 상태 업데이트
  static Future<void> updateLocationPublic(String userId, bool isPublic) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'locationPublic': isPublic,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('위치 공개 상태 업데이트 오류: $e');
    }
  }

  // 반려동물 정보 가져오기
  static Future<List<Map<String, dynamic>>> getUserPets(String userId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('pets')
          .where('userId', isEqualTo: userId)
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id; // 문서 ID 추가
        return data;
      }).toList();
    } catch (e) {
      print('반려동물 정보 가져오기 오류: $e');
      return [];
    }
  }

  // 대표 반려동물 가져오기
  static Future<Map<String, dynamic>?> getUserRepresentativePet(String userId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('pets')
          .where('userId', isEqualTo: userId)
          .where('isRepresentative', isEqualTo: true)
          .limit(1)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('대표 반려동물 가져오기 오류: $e');
      return null;
    }
  }
}
