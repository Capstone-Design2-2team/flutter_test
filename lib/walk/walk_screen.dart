// lib/walk/walk_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

import 'walk_record_screen.dart';

class WalkScreen extends StatefulWidget {
  final VoidCallback? onBack; // 탭에서 "뒤로"처럼 동작시키고 싶을 때
  const WalkScreen({super.key, this.onBack});

  @override
  State<WalkScreen> createState() => _WalkScreenState();
}

class _WalkScreenState extends State<WalkScreen> {
  GoogleMapController? _map;
  bool _permissionOk = false;

  bool _isWalking = false;
  DateTime? _startedAt;
  Timer? _tick;
  Duration _elapsed = Duration.zero;

  StreamSubscription<Position>? _posSub;
  Position? _lastPos;

  double _distanceM = 0;
  final List<LatLng> _path = [];

  LatLng _cameraCenter = const LatLng(37.5665, 126.9780); // fallback: 서울

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  @override
  void dispose() {
    _tick?.cancel();
    _posSub?.cancel();
    _map?.dispose();
    super.dispose();
  }

  Future<void> _initLocation() async {
    final ok = await _ensurePermission();
    if (!mounted) return;

    setState(() => _permissionOk = ok);

    if (!ok) return;

    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    _cameraCenter = LatLng(pos.latitude, pos.longitude);
    _lastPos = pos;
    _path
      ..clear()
      ..add(_cameraCenter);

    if (_map != null) {
      await _map!.animateCamera(CameraUpdate.newLatLngZoom(_cameraCenter, 17));
    }
    setState(() {});
  }

  Future<bool> _ensurePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied) return false;
    if (perm == LocationPermission.deniedForever) return false;
    return true;
  }

  Future<void> _startWalk() async {
    final ok = await _ensurePermission();
    if (!mounted) return;

    if (!ok) {
      setState(() => _permissionOk = false);
      return;
    }
    setState(() => _permissionOk = true);

    _isWalking = true;
    _distanceM = 0;
    _path.clear();
    _startedAt = DateTime.now();
    _elapsed = Duration.zero;

    final first = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.bestForNavigation,
    );
    _lastPos = first;
    final firstLatLng = LatLng(first.latitude, first.longitude);
    _path.add(firstLatLng);
    _cameraCenter = firstLatLng;

    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _startedAt == null) return;
      setState(() => _elapsed = DateTime.now().difference(_startedAt!));
    });

    _posSub?.cancel();
    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5, // 5m 움직일 때마다 업데이트
      ),
    ).listen((pos) async {
      final last = _lastPos;
      _lastPos = pos;

      final p = LatLng(pos.latitude, pos.longitude);

      if (last != null) {
        final d = Geolocator.distanceBetween(
          last.latitude,
          last.longitude,
          pos.latitude,
          pos.longitude,
        );
        // 너무 미세한 흔들림은 컷
        if (d >= 2) {
          _distanceM += d;
          _path.add(p);
        }
      } else {
        _path.add(p);
      }

      _cameraCenter = p;
      if (_map != null) {
        await _map!.animateCamera(CameraUpdate.newLatLng(p));
      }
      if (mounted) setState(() {});
    });

    if (_map != null) {
      await _map!.animateCamera(CameraUpdate.newLatLngZoom(_cameraCenter, 17));
    }
    if (mounted) setState(() {});
  }

  Future<void> _stopWalk() async {
    _tick?.cancel();
    await _posSub?.cancel();
    _posSub = null;

    final startedAt = _startedAt ?? DateTime.now();
    final endedAt = DateTime.now();
    final elapsed = _elapsed;

    setState(() {
      _isWalking = false;
    });

    if (!mounted) return;

    // 기록 화면으로 이동 (사진/메모/공유/완료)
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WalkRecordScreen(
          startedAt: startedAt,
          endedAt: endedAt,
          duration: elapsed,
          distanceMeters: _distanceM,
          path: List<LatLng>.from(_path),
        ),
      ),
    );
  }

  String _fmtDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    if (m < 60) return '${m.toString().padLeft(2, '0')}분 ${s.toString().padLeft(2, '0')}초';
    final h = d.inHours;
    final mm = m % 60;
    return '${h.toString().padLeft(2, '0')}시간 ${mm.toString().padLeft(2, '0')}분';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Map
        Positioned.fill(
          child: GoogleMap(
            initialCameraPosition: CameraPosition(target: _cameraCenter, zoom: 16),
            myLocationEnabled: _permissionOk,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
            polylines: {
              if (_path.length >= 2)
                Polyline(
                  polylineId: const PolylineId('walk'),
                  points: _path,
                  width: 6,
                ),
            },
            markers: {
              if (_path.isNotEmpty)
                Marker(
                  markerId: const MarkerId('me'),
                  position: _path.last,
                ),
            },
            onMapCreated: (c) {
              _map = c;
              if (_permissionOk) {
                _map!.animateCamera(CameraUpdate.newLatLngZoom(_cameraCenter, 17));
              }
            },
          ),
        ),

        // 상단 "뒤로" (스크린샷처럼)
        SafeArea(
          child: Align(
            alignment: Alignment.topLeft,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              onPressed: widget.onBack ?? () => Navigator.maybePop(context),
            ),
          ),
        ),

        // 권한 안내 배너
        if (!_permissionOk)
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_off, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    const Text('위치 권한/서비스가 필요합니다', style: TextStyle(color: Colors.white)),
                    const SizedBox(width: 10),
                    TextButton(
                      onPressed: _initLocation,
                      child: const Text('다시 시도', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // 하단 UI (스크린샷 스타일)
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              boxShadow: [
                BoxShadow(blurRadius: 20, color: Color(0x22000000), offset: Offset(0, -6)),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // (1) 펫 선택 row (지금 프로젝트에 pets 구조가 없어서 UI만 먼저 구현)
                  if (!_isWalking) ...[
                    Row(
                      children: [
                        _petCircle(imageUrl: null, label: '펫1'),
                        const SizedBox(width: 10),
                        _petCircle(imageUrl: null, label: '펫2'),
                        const SizedBox(width: 10),
                        _addPetCircle(),
                        const Spacer(),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF233554),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                        ),
                        onPressed: _startWalk,
                        child: const Text('산책 시작', style: TextStyle(color: Colors.white, fontSize: 18)),
                      ),
                    ),
                  ] else ...[
                    // (2) 산책 중 UI: 시간/거리 + 종료 버튼
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFF233554), width: 1.5),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                const Text('산책시간', style: TextStyle(color: Color(0xFF233554), fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                Text(
                                  _fmtDuration(_elapsed),
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          Container(width: 1, height: 44, color: const Color(0x33233554)),
                          Expanded(
                            child: Column(
                              children: [
                                const Text('거리', style: TextStyle(color: Color(0xFF233554), fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                Text(
                                  '${(_distanceM / 1000).toStringAsFixed(2)}km',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: SizedBox(
                        height: 40,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF233554),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                          ),
                          onPressed: _stopWalk,
                          child: const Text('산책 종료', style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _petCircle({String? imageUrl, required String label}) {
    return Column(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: const Color(0xFFE9EEF6),
          backgroundImage: (imageUrl != null) ? NetworkImage(imageUrl) : null,
          child: (imageUrl == null) ? const Icon(Icons.pets, color: Color(0xFF233554)) : null,
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
      ],
    );
  }

  Widget _addPetCircle() {
    return GestureDetector(
      onTap: () {
        // TODO: 펫 등록/선택 화면 연결 (현재 프로젝트에 해당 기능 없음)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('펫 추가 화면은 아직 연결되지 않았습니다.')),
        );
      },
      child: CircleAvatar(
        radius: 22,
        backgroundColor: const Color(0xFFE0E0E0),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
