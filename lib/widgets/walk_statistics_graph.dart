import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';

class WalkStatisticsGraph extends StatefulWidget {
  final String mode; // 'daily' or 'monthly'
  final DateTime selectedDate;

  const WalkStatisticsGraph({
    super.key,
    required this.mode,
    required this.selectedDate,
  });

  @override
  State<WalkStatisticsGraph> createState() => _WalkStatisticsGraphState();
}

class _WalkStatisticsGraphState extends State<WalkStatisticsGraph> {
  List<Map<String, dynamic>> _walkData = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWalkData();
  }

  @override
  void didUpdateWidget(WalkStatisticsGraph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate != widget.selectedDate || oldWidget.mode != widget.mode) {
      _loadWalkData();
    }
  }

  Future<void> _loadWalkData() async {
    setState(() {
      _isLoading = true;
    });

    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      QuerySnapshot querySnapshot;
      
      if (widget.mode == 'daily') {
        // 일별: 선택된 날짜의 모든 산책 데이터
        final startOfDay = DateTime(
          widget.selectedDate.year,
          widget.selectedDate.month,
          widget.selectedDate.day,
        );
        final endOfDay = startOfDay.add(const Duration(days: 1));
        
        querySnapshot = await FirebaseFirestore.instance
            .collection('walk_data')
            .where('userId', isEqualTo: currentUserId)
            .where('startTime', isGreaterThanOrEqualTo: startOfDay)
            .where('startTime', isLessThan: endOfDay)
            .orderBy('startTime')
            .get();
      } else {
        // 월별: 선택된 월의 모든 산책 데이터
        final startOfMonth = DateTime(widget.selectedDate.year, widget.selectedDate.month, 1);
        final endOfMonth = DateTime(widget.selectedDate.year, widget.selectedDate.month + 1, 0, 23, 59, 59);
        
        querySnapshot = await FirebaseFirestore.instance
            .collection('walk_data')
            .where('userId', isEqualTo: currentUserId)
            .where('startTime', isGreaterThanOrEqualTo: startOfMonth)
            .where('startTime', isLessThanOrEqualTo: endOfMonth)
            .orderBy('startTime')
            .get();
      }

      final data = querySnapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data() as Map<String, dynamic>,
        };
      }).toList();

      setState(() {
        _walkData = data;
        _isLoading = false;
      });
    } catch (e) {
      // 개발 중 디버깅용, 프로덕션에서는 제거 권장
      print('산책 데이터 로드 오류: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF233554)),
        ),
      );
    }

    if (_walkData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.pets,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              widget.mode == 'daily' ? '산책 기록이 없습니다' : '이번 달 산책 기록이 없습니다',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return widget.mode == 'daily' ? _buildDailyGraph() : _buildMonthlyGraph();
  }

  Widget _buildDailyGraph() {
    // 시간별로 데이터 그룹화 (00시 ~ 23시)
    Map<int, double> hourlyDistance = {};
    Map<int, int> hourlyTime = {};

    for (int i = 0; i < 24; i++) {
      hourlyDistance[i] = 0.0;
      hourlyTime[i] = 0;
    }

    for (var walk in _walkData) {
      final startTime = (walk['startTime'] as Timestamp).toDate();
      final hour = startTime.hour;
      final distance = (walk['distance'] as num?)?.toDouble() ?? 0.0;
      final duration = (walk['duration'] as num?)?.toInt() ?? 0;

      hourlyDistance[hour] = (hourlyDistance[hour] ?? 0.0) + distance;
      hourlyTime[hour] = (hourlyTime[hour] ?? 0) + duration;
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 통계 요약
          _buildDailySummary(hourlyDistance, hourlyTime),
          const SizedBox(height: 24),
          // 그래프
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: _getMaxHourlyDistance(hourlyDistance) * 1.2,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => const Color(0xFF233554),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final hour = group.x.toInt();
                      final distance = hourlyDistance[hour] ?? 0.0;
                      final time = hourlyTime[hour] ?? 0;
                      return BarTooltipItem(
                        '$hour시\n거리: ${distance.toStringAsFixed(1)}km\n시간: ${time}분',
                        const TextStyle(color: Colors.white, fontSize: 12),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() % 3 == 0) {
                          return Text(
                            '${value.toInt()}시',
                            style: const TextStyle(
                              color: Color(0xFF233554),
                              fontSize: 10,
                            ),
                          );
                        }
                        return const Text('');
                      },
                      reservedSize: 22,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}km',
                          style: const TextStyle(
                            color: Color(0xFF233554),
                            fontSize: 10,
                          ),
                        );
                      },
                      reservedSize: 32,
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(24, (index) {
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: hourlyDistance[index] ?? 0.0,
                        color: const Color(0xFFE8B4F3),
                        width: 8,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyGraph() {
    // 일별로 데이터 그룹화
    Map<int, double> dailyDistance = {};
    Map<int, int> dailyTime = {};

    final daysInMonth = DateTime(widget.selectedDate.year, widget.selectedDate.month + 1, 0).day;
    for (int i = 1; i <= daysInMonth; i++) {
      dailyDistance[i] = 0.0;
      dailyTime[i] = 0;
    }

    for (var walk in _walkData) {
      final startTime = (walk['startTime'] as Timestamp).toDate();
      final day = startTime.day;
      final distance = (walk['distance'] as num?)?.toDouble() ?? 0.0;
      final duration = (walk['duration'] as num?)?.toInt() ?? 0;

      dailyDistance[day] = (dailyDistance[day] ?? 0.0) + distance;
      dailyTime[day] = (dailyTime[day] ?? 0) + duration;
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 통계 요약
          _buildMonthlySummary(dailyDistance, dailyTime),
          const SizedBox(height: 24),
          // 그래프
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: _getMaxDailyDistance(dailyDistance) * 1.2,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => const Color(0xFF233554),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final day = group.x.toInt();
                      final distance = dailyDistance[day] ?? 0.0;
                      final time = dailyTime[day] ?? 0;
                      return BarTooltipItem(
                        '${day}일\n거리: ${distance.toStringAsFixed(1)}km\n시간: ${time}분',
                        const TextStyle(color: Colors.white, fontSize: 12),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final day = value.toInt();
                        if (day % 5 == 1 || day == daysInMonth) {
                          return Text(
                            '${day}일',
                            style: const TextStyle(
                              color: Color(0xFF233554),
                              fontSize: 10,
                            ),
                          );
                        }
                        return const Text('');
                      },
                      reservedSize: 22,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}km',
                          style: const TextStyle(
                            color: Color(0xFF233554),
                            fontSize: 10,
                          ),
                        );
                      },
                      reservedSize: 32,
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(daysInMonth, (index) {
                  final day = index + 1;
                  return BarChartGroupData(
                    x: day,
                    barRods: [
                      // 거리 막대
                      BarChartRodData(
                        toY: dailyDistance[day] ?? 0.0,
                        color: const Color(0xFFE8B4F3),
                        width: 12,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                      // 시간 막대 (분을 km로 변환하여 표시)
                      BarChartRodData(
                        toY: (dailyTime[day] ?? 0) / 60.0, // 분을 시간으로 변환
                        color: const Color(0xFF9B7EDE),
                        width: 12,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
          // 범례
          _buildLegend(),
        ],
      ),
    );
  }

  Widget _buildDailySummary(Map<int, double> hourlyDistance, Map<int, int> hourlyTime) {
    final totalDistance = hourlyDistance.values.fold(0.0, (total, distance) => total + distance);
    final totalTime = hourlyTime.values.fold(0, (total, time) => total + time);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            children: [
              Text(
                '총 거리',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${totalDistance.toStringAsFixed(1)}km',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF233554),
                ),
              ),
            ],
          ),
          Column(
            children: [
              Text(
                '총 시간',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${totalTime}분',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF233554),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlySummary(Map<int, double> dailyDistance, Map<int, int> dailyTime) {
    final totalDistance = dailyDistance.values.fold(0.0, (total, distance) => total + distance);
    final totalTime = dailyTime.values.fold(0, (total, time) => total + time);
    final walkDays = dailyDistance.values.where((distance) => distance > 0).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            children: [
              Text(
                '총 거리',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${totalDistance.toStringAsFixed(1)}km',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF233554),
                ),
              ),
            ],
          ),
          Column(
            children: [
              Text(
                '총 시간',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${totalTime}분',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF233554),
                ),
              ),
            ],
          ),
          Column(
            children: [
              Text(
                '산책 일수',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$walkDays일',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF233554),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(
              color: Color(0xFFE8B4F3),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            '거리 (km)',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF233554),
            ),
          ),
          const SizedBox(width: 24),
          Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(
              color: Color(0xFF9B7EDE),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            '시간 (시)',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF233554),
            ),
          ),
        ],
      ),
    );
  }

  double _getMaxHourlyDistance(Map<int, double> hourlyDistance) {
    double maxDistance = 0.0;
    for (double distance in hourlyDistance.values) {
      if (distance > maxDistance) {
        maxDistance = distance;
      }
    }
    return maxDistance > 0 ? maxDistance : 1.0;
  }

  double _getMaxDailyDistance(Map<int, double> dailyDistance) {
    double maxDistance = 0.0;
    for (double distance in dailyDistance.values) {
      if (distance > maxDistance) {
        maxDistance = distance;
      }
    }
    return maxDistance > 0 ? maxDistance : 1.0;
  }
}