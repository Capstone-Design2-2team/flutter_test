import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../pet_registration_screen.dart';
import 'walk_record_screen.dart';

class WalkScreen extends StatefulWidget {
  final VoidCallback onBackToHome;

  const WalkScreen({super.key, required this.onBackToHome});

  @override
  State<WalkScreen> createState() => _WalkScreenState();
}

class _WalkScreenState extends State<WalkScreen> {
  GoogleMapController? _map;

  bool _permissionOk = false;
  bool _requesting = false;

  bool _isWalking = false;

  DateTime? _startedAt;
  Timer? _tick;
  Duration _elapsed = Duration.zero;

  StreamSubscription<Position>? _posSub;
  Position? _lastPos;

  double _distanceM = 0.0;
  final List<LatLng> _path = <LatLng>[];

  LatLng _cameraCenter = const LatLng(37.5665, 126.9780);

  final Set<String> _selectedPetIds = <String>{};

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _tick?.cancel();
    _posSub?.cancel();
    _map?.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _bootstrap() async {
    final ok = await _ensureLocationReady(interactive: false);
    if (!mounted) return;
    setState(() => _permissionOk = ok);

    if (ok) {
      await _moveToCurrent();
    }
  }

  Future<bool> _ensureLocationReady({required bool interactive}) async {
    // 1) GPS (Location Service)
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (interactive) {
        _snack('GPS(위치 서비스)가 꺼져있습니다. 설정에서 켜 주세요.');
        await Geolocator.openLocationSettings();
      }
      return false;
    }

    // 2) Permission
    var perm = await Geolocator.checkPermission();

    if (perm == LocationPermission.denied) {
      if (!interactive) return false;
      perm = await Geolocator.requestPermission();
    }

    if (perm == LocationPermission.denied) {
      if (interactive) _snack('위치 권한이 거부되었습니다.');
      return false;
    }

    if (perm == LocationPermission.deniedForever) {
      if (!interactive) return false;

      final go = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('위치 권한 필요'),
          content: const Text('현재 “다시 묻지 않음” 상태입니다.\n앱 설정에서 위치 권한을 허용해 주세요.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('설정 열기')),
          ],
        ),
      );

      if (go == true) {
        await Geolocator.openAppSettings();
      }
      return false;
    }

    return true;
  }

  Future<void> _moveToCurrent() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _cameraCenter = LatLng(pos.latitude, pos.longitude);
      _lastPos = pos;

      if (_map != null) {
        await _map!.animateCamera(CameraUpdate.newLatLngZoom(_cameraCenter, 17));
      }
      if (mounted) setState(() {});
    } catch (e) {
      _snack('현재 위치를 가져오지 못했습니다: $e');
    }
  }

  Future<void> _onPermissionButton() async {
    if (_requesting) return;
    setState(() => _requesting = true);

    try {
      final ok = await _ensureLocationReady(interactive: true);
      if (!mounted) return;

      setState(() => _permissionOk = ok);
      if (ok) {
        _snack('위치 권한이 허용되었습니다.');
        await _moveToCurrent();
      }
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  Future<void> _startWalk() async {
    // 등록된 반려동물이 있는지 확인
    if (_selectedPetIds.isEmpty) {
      _snack('산책을 시작하려면 반려동물을 선택해주세요.');
      return;
    }

    final ok = await _ensureLocationReady(interactive: true);
    if (!mounted) return;

    setState(() => _permissionOk = ok);
    if (!ok) return;

    setState(() {
      _isWalking = true;
      _startedAt = DateTime.now();
      _elapsed = Duration.zero;
      _distanceM = 0.0;
      _path.clear();
    });

    try {
      final first = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      );
      _lastPos = first;
      _cameraCenter = LatLng(first.latitude, first.longitude);
      _path.add(_cameraCenter);
    } catch (e) {
      _snack('위치 측정 시작 실패: $e');
      setState(() => _isWalking = false);
      return;
    }

    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final start = _startedAt;
      if (start == null) return;
      setState(() => _elapsed = DateTime.now().difference(start));
    });

    await _posSub?.cancel();
    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
      ),
    ).listen((pos) async {
      if (!_isWalking) return;

      final prev = _lastPos;
      _lastPos = pos;

      final p = LatLng(pos.latitude, pos.longitude);
      _cameraCenter = p;

      if (prev != null) {
        final d = Geolocator.distanceBetween(
          prev.latitude,
          prev.longitude,
          pos.latitude,
          pos.longitude,
        );
        if (d >= 2) {
          _distanceM += d;
          _path.add(p);
        }
      } else {
        _path.add(p);
      }

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

    setState(() => _isWalking = false);

    if (!mounted) return;

    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => WalkRecordScreen(
          startedAt: startedAt,
          endedAt: endedAt,
          duration: elapsed,
          distanceMeters: _distanceM,
          path: List.from(_path),
          petIds: _selectedPetIds.toList(),
        ),
      ),
    );

    if (saved == true && mounted) {
      setState(() {
        _startedAt = null;
        _elapsed = Duration.zero;
        _distanceM = 0.0;
        _path.clear();
      });
    }
  }

  String _fmtDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    if (m < 60) return '${m.toString().padLeft(2, '0')}분 ${s.toString().padLeft(2, '0')}초';
    final h = d.inHours;
    final mm = m % 60;
    return '${h.toString().padLeft(2, '0')}시간 ${mm.toString().padLeft(2, '0')}분';
  }

  String _fmtKm(double meters) => (meters / 1000.0).toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    final panelHeight = _isWalking
        ? (h * 0.36).clamp(280.0, 380.0)
        : (h * 0.32).clamp(250.0, 350.0);

    return Stack(
      children: [
        Positioned.fill(
          child: _permissionOk
              ? GoogleMap(
            initialCameraPosition: CameraPosition(target: _cameraCenter, zoom: 17),
            onMapCreated: (c) => _map = c,
            myLocationEnabled: true,
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
          )
              : Container(
            color: const Color(0xFFEFEFEF),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_off, size: 44),
                    const SizedBox(height: 12),
                    const Text(
                      '위치 권한/위치 서비스(GPS)가 필요합니다.\n버튼을 눌러 설정을 진행해 주세요.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        onPressed: _requesting ? null : _onPermissionButton,
                        child: _requesting
                            ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                            : const Text('권한 요청 / 설정 열기'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        Positioned(
          top: MediaQuery.of(context).padding.top + 6,
          left: 4,
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: widget.onBackToHome,
          ),
        ),

        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SizedBox(
            height: panelHeight,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                boxShadow: [
                  BoxShadow(color: Color(0x22000000), blurRadius: 10, offset: Offset(0, -2)),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: 74,
                          child: Align(alignment: Alignment.centerLeft, child: _buildPetsRow(context)),
                        ),
                        const SizedBox(height: 16),

                        if (_isWalking) ...[
                          _statsBox(
                            leftLabel: '산책시간',
                            leftValue: _fmtDuration(_elapsed),
                            rightLabel: '거리',
                            rightValue: '${_fmtKm(_distanceM)}km',
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 46,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF233554),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: _stopWalk,
                              child: const Text('산책 종료', style: TextStyle(color: Colors.white)),
                            ),
                          ),
                        ] else ...[
                          SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF233554),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                              ),
                              onPressed: _permissionOk ? _startWalk : _onPermissionButton,
                              child: Text(
                                _permissionOk && _selectedPetIds.isNotEmpty 
                                    ? '산책 시작' 
                                    : _selectedPetIds.isEmpty 
                                        ? '산책 시작' 
                                        : '권한 먼저 허용',
                                style: const TextStyle(color: Colors.white, fontSize: 16),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _statsBox({
    required String leftLabel,
    required String leftValue,
    required String rightLabel,
    required String rightValue,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF233554), width: 1.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Text(leftLabel, style: const TextStyle(color: Color(0xFF233554), fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(leftValue, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Container(width: 1, height: 46, color: const Color(0x33233554)),
          Expanded(
            child: Column(
              children: [
                Text(rightLabel, style: const TextStyle(color: Color(0xFF233554), fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(rightValue, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPetsRow(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Row(
        children: [
          _petCircle(icon: Icons.pets, label: '로그인 필요', selected: false, onTap: null),
          const SizedBox(width: 10),
          _addPetCircle(context),
        ],
      );
    }

    final petsStream = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('pets')
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: petsStream,
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Row(
            children: [
              _addPetCircle(context),
            ],
          );
        }

        return ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: docs.length + 1,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, idx) {
            if (idx == docs.length) return _addPetCircle(context);

            final d = docs[idx];
            final id = d.id;
            final data = d.data();
            final name = (data['name'] ?? data['pet_name'] ?? '펫').toString();
            final photoUrl = (data['photo_url'] ?? data['image_url'] ?? '').toString();

            final selected = _selectedPetIds.contains(id);

            return _petCircle(
              label: name,
              photoUrl: photoUrl.isEmpty ? null : photoUrl,
              selected: selected,
              onTap: () {
                setState(() {
                  if (selected) {
                    _selectedPetIds.remove(id);
                  } else {
                    _selectedPetIds.add(id);
                  }
                });
              },
            );
          },
        );
      },
    );
  }

  Widget _petCircle({
    IconData? icon,
    String label = '',
    String? photoUrl,
    required bool selected,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFFE0E0E0),
                backgroundImage: (photoUrl != null) ? NetworkImage(photoUrl) : null,
                child: (photoUrl == null) ? Icon(icon ?? Icons.pets, color: Colors.white) : null,
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: 60,
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, height: 1.0, color: Colors.black54),
                ),
              ),
            ],
          ),
          if (selected)
            Positioned(
              right: -2,
              bottom: 22,
              child: Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(color: Color(0xFFE53935), shape: BoxShape.circle),
                child: const Icon(Icons.check, color: Colors.white, size: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _addPetCircle(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const PetRegistrationScreen()),
        ).then((_) {
          // 반려동물 등록 후 데이터 새로고침
          setState(() {});
        });
      },
      child: CircleAvatar(
        radius: 22,
        backgroundColor: const Color(0xFFE0E0E0),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
