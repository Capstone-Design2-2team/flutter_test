import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class WalkCalendarPicker extends StatefulWidget {
  final String mode; // 'daily' or 'monthly'
  final DateTime selectedDate;
  final Function(DateTime) onDateSelected;

  const WalkCalendarPicker({
    super.key,
    required this.mode,
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  State<WalkCalendarPicker> createState() => _WalkCalendarPickerState();
}

class _WalkCalendarPickerState extends State<WalkCalendarPicker> {
  late DateTime _currentMonth;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(widget.selectedDate.year, widget.selectedDate.month, 1);
    _selectedDate = widget.selectedDate;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mode == 'daily') {
      return _buildDailyCalendar();
    } else {
      return _buildMonthlyCalendar();
    }
  }

  Widget _buildDailyCalendar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFF233554),
      child: Column(
        children: [
          // 월 이동 버튼
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
                  });
                },
                icon: const Icon(Icons.chevron_left, color: Colors.white),
              ),
              Text(
                DateFormat('yyyy년 MM월').format(_currentMonth),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
                  });
                },
                icon: const Icon(Icons.chevron_right, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 요일 헤더
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['일', '월', '화', '수', '목', '금', '토'].map((day) {
              return SizedBox(
                width: 32,
                child: Text(
                  day,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: day == '일' ? Colors.pinkAccent : Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          // 날짜 그리드
          _buildDayGrid(),
        ],
      ),
    );
  }

  Widget _buildDayGrid() {
    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final startWeekday = firstDay.weekday % 7; // 일요일이 0이 되도록 조정
    final daysInMonth = lastDay.day;

    return Column(
      children: List.generate(6, (weekIndex) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(7, (dayIndex) {
            final dayNumber = weekIndex * 7 + dayIndex - startWeekday + 1;
            
            if (dayNumber <= 0 || dayNumber > daysInMonth) {
              return const SizedBox(width: 32, height: 32);
            }

            final currentDate = DateTime(_currentMonth.year, _currentMonth.month, dayNumber);
            final isSelected = _isSameDay(currentDate, _selectedDate);
            final isToday = _isSameDay(currentDate, DateTime.now());
            final isWeekend = dayIndex == 0 || dayIndex == 6;

            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedDate = currentDate;
                });
                widget.onDateSelected(currentDate);
              },
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFE8B4F3) : Colors.transparent,
                  shape: BoxShape.circle,
                  border: isToday && !isSelected 
                      ? Border.all(color: const Color(0xFFE8B4F3), width: 2)
                      : null,
                ),
                child: Center(
                  child: Text(
                    '$dayNumber',
                    style: TextStyle(
                      color: isSelected 
                          ? const Color(0xFF233554)
                          : isWeekend
                              ? Colors.pinkAccent
                              : Colors.white,
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      }),
    );
  }

  Widget _buildMonthlyCalendar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFF233554),
      child: Column(
        children: [
          // 연도 선택
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    _currentMonth = DateTime(_currentMonth.year - 1, 1, 1);
                  });
                },
                icon: const Icon(Icons.chevron_left, color: Colors.white),
              ),
              Text(
                '${_currentMonth.year}년',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _currentMonth = DateTime(_currentMonth.year + 1, 1, 1);
                  });
                },
                icon: const Icon(Icons.chevron_right, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // 월 그리드
          _buildMonthGrid(),
        ],
      ),
    );
  }

  Widget _buildMonthGrid() {
    final months = ['1월', '2월', '3월', '4월', '5월', '6월', 
                   '7월', '8월', '9월', '10월', '11월', '12월'];
    
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 2.5,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: 12,
      itemBuilder: (context, index) {
        final month = index + 1;
        final selectedMonth = DateTime(_currentMonth.year, month, 1);
        final isSelected = _selectedDate.year == _currentMonth.year && 
                         _selectedDate.month == month;

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedDate = selectedMonth;
            });
            widget.onDateSelected(selectedMonth);
          },
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFE8B4F3) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? Colors.transparent : Colors.white30,
                width: 1,
              ),
            ),
            child: Center(
              child: Text(
                months[index],
                style: TextStyle(
                  color: isSelected 
                      ? const Color(0xFF233554)
                      : Colors.white,
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }
}