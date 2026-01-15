import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'widgets/walk_calendar_picker.dart';
import 'widgets/walk_statistics_graph.dart';

class WalkStatisticsScreen extends StatefulWidget {
  const WalkStatisticsScreen({super.key});

  @override
  State<WalkStatisticsScreen> createState() => _WalkStatisticsScreenState();
}

class _WalkStatisticsScreenState extends State<WalkStatisticsScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedDate = DateTime.now();
  DateTime _selectedMonth = DateTime.now();
  
  // 실시간 데이터 감지를 위한 StreamSubscription
  StreamSubscription<QuerySnapshot>? _walkDataSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      // 탭 변경 시 UI 업데이트는 TabBarView가 자동으로 처리
    });
    _setupRealtimeListener();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _walkDataSubscription?.cancel();
    super.dispose();
  }

  void _setupRealtimeListener() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId != null) {
      _walkDataSubscription = FirebaseFirestore.instance
          .collection('walk_data')
          .where('userId', isEqualTo: currentUserId)
          .snapshots()
          .listen((snapshot) {
        // 데이터 변경 시 UI 업데이트
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF233554),
        elevation: 0,
        title: const Text(
          '산책 통계',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          tabs: const [
            Tab(text: '일별'),
            Tab(text: '월별'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDailyView(),
          _buildMonthlyView(),
        ],
      ),
    );
  }

  Widget _buildDailyView() {
    return Column(
      children: [
        // 날짜 선택기
        WalkCalendarPicker(
          mode: 'daily',
          selectedDate: _selectedDate,
          onDateSelected: (date) {
            setState(() {
              _selectedDate = date;
            });
          },
        ),
        // 통계 그래프
        Expanded(
          child: WalkStatisticsGraph(
            mode: 'daily',
            selectedDate: _selectedDate,
          ),
        ),
      ],
    );
  }

  Widget _buildMonthlyView() {
    return Column(
      children: [
        // 월 선택기
        WalkCalendarPicker(
          mode: 'monthly',
          selectedDate: _selectedMonth,
          onDateSelected: (date) {
            setState(() {
              _selectedMonth = date;
            });
          },
        ),
        // 통계 그래프
        Expanded(
          child: WalkStatisticsGraph(
            mode: 'monthly',
            selectedDate: _selectedMonth,
          ),
        ),
      ],
    );
  }
}
