import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WalkRouteScreen extends StatefulWidget {
  final String recordId;
  final Map<String, dynamic> recordData;

  const WalkRouteScreen({
    super.key,
    required this.recordId,
    required this.recordData,
  });

  @override
  State<WalkRouteScreen> createState() => _WalkRouteScreenState();
}

class _WalkRouteScreenState extends State<WalkRouteScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    // 데이터가 없을 경우를 대비한 기본값 설정
    final distance = widget.recordData['distance_km']?.toDouble() ?? 0.0;
    final duration = widget.recordData['duration_minutes']?.toInt() ?? 0;
    final calories = widget.recordData['calories']?.toInt();
    final date = widget.recordData['date'] as Timestamp?;
    final startTime = widget.recordData['startTime'] as Timestamp?;
    
    // GPS 기록이 있는지 확인
    final hasGpsData = widget.recordData['distance_km'] != null && 
                       widget.recordData['distance_km'] > 0;
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF233554),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // 경로 지도 영역 - 65% 차지
          Expanded(
            flex: 13,
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
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
              child: Stack(
                children: [
                  // 지도 배경
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 지도 아이콘
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            color: hasGpsData ? Colors.blue[400] : Colors.grey[400],
                            borderRadius: BorderRadius.circular(70),
                            boxShadow: [
                              BoxShadow(
                                color: (hasGpsData ? Colors.blue : Colors.grey).withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Icon(
                            hasGpsData ? Icons.map : Icons.location_off,
                            size: 70,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 20),
                        // 지도 텍스트
                        Text(
                          hasGpsData ? '이동 경로' : 'GPS 기록 없음',
                          style: TextStyle(
                            fontSize: 22,
                            color: hasGpsData ? Colors.blue[600] : Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          hasGpsData 
                            ? '산책 경로를 확인해주세요'
                            : 'GPS 기록이 있는 산책을 확인해주세요',
                          style: TextStyle(
                            fontSize: 16,
                            color: hasGpsData ? Colors.blue[400] : Colors.grey[500],
                          ),
                        ),
                        if (!hasGpsData) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange.withOpacity(0.3)),
                            ),
                            child: const Text(
                              '이 산책은 GPS 기록이 없습니다',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.orange,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  // GPS 기록이 있을 때만 경로 시각화 표시
                  if (hasGpsData)
                    Positioned.fill(
                      child: CustomPaint(
                        size: const Size(double.infinity, double.infinity),
                        painter: RoutePainter(
                          points: [
                            const Offset(80, 100),
                            const Offset(150, 80),
                            const Offset(220, 120),
                            const Offset(280, 90),
                            const Offset(320, 140),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          // 정보 표시 - 텍스트 형식으로 이미지 아래 표시
          Expanded(
            flex: 6,
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16),
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 총 거리 텍스트
                  RichText(
                    text: TextSpan(
                      children: [
                        const TextSpan(
                          text: '총 거리: ',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.black,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        TextSpan(
                          text: '${distance.toStringAsFixed(1)}km',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFF233554),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // 산책 시간 텍스트
                  RichText(
                    text: TextSpan(
                      children: [
                        const TextSpan(
                          text: '산책 시간: ',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.black,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        TextSpan(
                          text: '${duration.toString().padLeft(2, '0')}분',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFF233554),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatTime(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

// 경로 그리기 위젯 커스텀
class RoutePainter extends CustomPainter {
  final List<Offset> points;

  RoutePainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF233554)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (points.length < 2) return;

    for (int i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], paint);
    }

    // 포인트 그리기 (더 크게)
    for (final point in points) {
      final pointPaint = Paint()
        ..color = const Color(0xFF233554)
        ..style = PaintingStyle.fill
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      canvas.drawCircle(point, 8, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant oldDelegate) => false;
}
