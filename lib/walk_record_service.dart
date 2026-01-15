import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WalkRecordService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<List<Map<String, dynamic>>> getWalkRecords({String? petId}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      List<Map<String, dynamic>> records = [];
      
      if (petId != null) {
        print('DEBUG: Using direct approach - no user_id filtering');
        
        // user_id 필드가 없으므로 전체 walk_records에서 직접 필터링
        final allSnapshot = await _firestore
            .collection('walk_records')
            .orderBy('date', descending: true)
            .get();
            
        print('DEBUG: Total walk records in database: ${allSnapshot.docs.length}');
        
        // 클라이언트에서 직접 필터링
        List<Map<String, dynamic>> filteredRecords = [];
        for (var doc in allSnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          
          print('DEBUG: Checking document ${doc.id}');
          print('DEBUG: Document data keys: ${data.keys.toList()}');
          
          // 다양한 pet 필드명 확인
          final petIds = _getFieldValue(data, ['pet_ids', 'petIds', 'pets']) as List<dynamic>?;
          final petIdField = _getFieldValue(data, ['pet_id', 'petId', 'pet']);
          
          bool matches = false;
          if (petIds != null && petIds.contains(petId)) {
            matches = true;
            print('DEBUG: Document ${doc.id} matches via pet_ids array: $petIds');
          } else if (petIdField == petId) {
            matches = true;
            print('DEBUG: Document ${doc.id} matches via pet_id field: $petIdField');
          }
          
          if (matches) {
            final processedRecord = {
              'id': doc.id,
              'date': _getFieldValue(data, ['date', 'createdAt', 'created_at', 'timestamp']) ?? Timestamp.now(),
              'distance_km': _getNumericField(data, ['distance_km', 'distanceKm', 'distance', 'totalDistance', 'total_distance']) ?? 0.0,
              'duration_minutes': _getNumericField(data, ['duration_minutes', 'durationMinutes', 'duration', 'totalDuration', 'total_duration']) ?? 0,
              'route': _getFieldValue(data, ['route', 'path', 'coordinates', 'route_points']) as List<dynamic>?,
              'pet_ids': petIds ?? [],
              'pet_id': petIdField,
              'pet_name': _getFieldValue(data, ['pet_name', 'petName', 'pet', 'animalName', 'animal_name']) ?? '알 수 없는 펫',
              'postImages': _getFieldValue(data, ['post_images', 'postImages', 'images', 'photos', 'walk_images', 'walkImages']) as List<dynamic>? ?? [],
              'startTime': _getFieldValue(data, ['start_time', 'startTime', 'startedAt', 'start_at']) ?? data['date'],
              'endTime': _getFieldValue(data, ['end_time', 'endTime', 'finishedAt', 'end_at']) ?? data['date'],
              'moodEmoji': _getFieldValue(data, ['mood_emoji', 'moodEmoji', 'mood', 'feeling', 'emotion']) ?? '😊',
              'memo': _getFieldValue(data, ['memo', 'description', 'note', 'comment', 'walk_memo', 'walkMemo']) ?? '',
              'calories': _getNumericField(data, ['calories', 'calorie', 'burnedCalories', 'burned_calories']) ?? 0.0,
              'steps': _getNumericField(data, ['steps', 'stepCount', 'step_count']) ?? 0,
            };
            filteredRecords.add(processedRecord);
            print('DEBUG: Added matching record: ${processedRecord['id']}');
          }
        }
        
        print('DEBUG: Final filtered records count: ${filteredRecords.length}');
        records.addAll(filteredRecords);
        
      } else {
        // petId가 없으면 모든 산책 기록 가져오기
        final snapshot = await _firestore
            .collection('walk_records')
            .orderBy('date', descending: true)
            .get();
        
        records.addAll(_processSnapshot(snapshot));
      }

      return records;
    } catch (e) {
      print('DEBUG: Error in getWalkRecords: $e');
      return [];
    }
  }

  static List<Map<String, dynamic>> _processSnapshot(QuerySnapshot snapshot) {
    List<Map<String, dynamic>> records = [];
    print('DEBUG: Processing ${snapshot.docs.length} raw documents');
    
    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      print('DEBUG: Raw document data keys: ${data.keys.toList()}');
      print('DEBUG: Raw document data: $data');
      
      // 다양한 필드명 형식을 지원하도록 처리
      final processedRecord = {
        'id': doc.id,
        'date': _getFieldValue(data, ['date', 'createdAt', 'created_at', 'timestamp']) ?? Timestamp.now(),
        'distance_km': _getNumericField(data, ['distance_km', 'distanceKm', 'distance', 'totalDistance', 'total_distance']) ?? 0.0,
        'duration_minutes': _getNumericField(data, ['duration_minutes', 'durationMinutes', 'duration', 'totalDuration', 'total_duration']) ?? 0,
        'route': _getFieldValue(data, ['route', 'path', 'coordinates', 'route_points']) as List<dynamic>?,
        'pet_ids': _getFieldValue(data, ['pet_ids', 'petIds', 'pets']) as List<dynamic>? ?? [],
        'pet_id': _getFieldValue(data, ['pet_id', 'petId', 'pet']) ?? (_getFieldValue(data, ['pet_ids', 'petIds']) as List?)?.first,
        'pet_name': _getFieldValue(data, ['pet_name', 'petName', 'pet', 'animalName', 'animal_name']) ?? '알 수 없는 펫',
        'postImages': _getFieldValue(data, ['post_images', 'postImages', 'images', 'photos', 'walk_images', 'walkImages']) as List<dynamic>? ?? [],
        'startTime': _getFieldValue(data, ['start_time', 'startTime', 'startedAt', 'start_at']) ?? data['date'],
        'endTime': _getFieldValue(data, ['end_time', 'endTime', 'finishedAt', 'end_at']) ?? data['date'],
        'moodEmoji': _getFieldValue(data, ['mood_emoji', 'moodEmoji', 'mood', 'feeling', 'emotion']) ?? '😊',
        'memo': _getFieldValue(data, ['memo', 'description', 'note', 'comment', 'walk_memo', 'walkMemo']) ?? '',
        'calories': _getNumericField(data, ['calories', 'calorie', 'burnedCalories', 'burned_calories']) ?? 0.0,
        'steps': _getNumericField(data, ['steps', 'stepCount', 'step_count']) ?? 0,
      };
      
      print('DEBUG: Processed record: $processedRecord');
      records.add(processedRecord);
    }
    
    print('DEBUG: Final processed records count: ${records.length}');
    return records;
  }

  // 필드 값 가져오기 헬퍼 메서드
  static dynamic _getFieldValue(Map<String, dynamic> data, List<String> fieldNames) {
    for (final fieldName in fieldNames) {
      if (data.containsKey(fieldName) && data[fieldName] != null) {
        return data[fieldName];
      }
    }
    return null;
  }

  // 숫자 필드 값 가져오기 헬퍼 메서드
  static double? _getNumericField(Map<String, dynamic> data, List<String> fieldNames) {
    for (final fieldName in fieldNames) {
      if (data.containsKey(fieldName) && data[fieldName] != null) {
        final value = data[fieldName];
        if (value is num) {
          return value.toDouble();
        } else if (value is String) {
          return double.tryParse(value);
        }
      }
    }
    return null;
  }

  static Future<void> createSampleWalkRecord(String petId, String petName) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final now = DateTime.now();
      
      // 여러 날짜의 샘플 데이터 생성 (최근 14일)
      for (int i = 0; i < 14; i++) {
        final date = now.subtract(Duration(days: i));
        final startHour = 8 + (i % 4); // 8시부터 11시까지
        final startMinute = (i * 7) % 60;
        final startTime = DateTime(date.year, date.month, date.day, startHour, startMinute);
        final duration = 20 + (i * 5) % 40; // 20분부터 60분까지
        final endTime = startTime.add(Duration(minutes: duration));
        final distance = 1.0 + (i * 0.3) + (i % 3 * 0.5); // 1.0km부터 6.5km까지

        // 샘플 산책 기록 생성
        await _firestore.collection('walk_records').add({
          'user_id': user.uid,
          'pet_ids': [petId], // 배열 형태로 저장
          'pet_name': petName,
          'date': Timestamp.fromDate(DateTime(date.year, date.month, date.day)),
          'start_time': Timestamp.fromDate(startTime),
          'end_time': Timestamp.fromDate(endTime),
          'distance_km': distance,
          'duration_minutes': duration,
          'route': [
            {'lat': 37.5665 + (i * 0.005), 'lng': 126.9780 + (i * 0.005)},
            {'lat': 37.5670 + (i * 0.005), 'lng': 126.9785 + (i * 0.005)},
            {'lat': 37.5675 + (i * 0.005), 'lng': 126.9790 + (i * 0.005)},
            {'lat': 37.5670 + (i * 0.005), 'lng': 126.9795 + (i * 0.005)},
            {'lat': 37.5665 + (i * 0.005), 'lng': 126.9790 + (i * 0.005)},
          ],
          'post_images': i % 3 != 0 ? [
            'https://picsum.photos/seed/walk${i}_1/400/300.jpg',
            'https://picsum.photos/seed/walk${i}_2/400/300.jpg',
            if (i % 2 == 0) 'https://picsum.photos/seed/walk${i}_3/400/300.jpg',
          ] : [], // 3번째마다 이미지 없음
          'mood_emoji': ['😊', '🥰', '😎', '🤗', '😌', '😄', '🐕', '🏃', '🌞', '🌙', '🌸', '🍃', '⭐', '🎉'][i],
          'memo': [
            '오늘은 날씨가 좋아서 즐거운 산책이었어요!',
            '공원에서 다른 강아지들도 만나고 재미있었어요',
            '조금 더 길게 산책했어요. 펫이 좋아했네요!',
            '아침 일찍 산책해서 상쾌하네요',
            '저녁 산책은 역시 최고예요',
            '주말이라서 여유롭게 산책했어요',
            '오늘도 펫과 함께 즐거운 시간!',
            '새로운 경로로 산책해서 신선했어요',
            '해가 질 때까지 함께 걸었어요',
            '달밤 산책은 로맨틱하네요',
            '봄꽃이 만발한 공원을 산책했어요',
            '바닷가를 따라서 걸었어요',
            '별이 빛나는 밤에 산책했어요',
            '펫 생일이라서 특별한 산책을 했어요!'
          ][i],
          'calories': 50 + (i * 10), // 50부터 190까지
          'steps': 1000 + (i * 200), // 1000부터 3700까지
          'weather': ['맑음', '흐림', '부분 흐림', '화창', '약간 흐림', '맑음', '화창', '맑음', '맑음', '흐림', '맑음', '부분 흐림', '맑음', '맑음'][i],
          'location': ['서울숲공원', '한강공원', '여의도공원', '뚝섬공원', '올림픽공원', '북한산', '남산공원', '잠실공원', '강남구', '마포구', '성동구', '종로구', '용산구', '강북구'][i],
          'created_at': Timestamp.now(),
        });
      }
    } catch (e) {
      // Silent error handling
    }
  }
}
