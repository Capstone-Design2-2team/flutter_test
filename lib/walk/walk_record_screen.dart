import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

class WalkRecordScreen extends StatefulWidget {
  final DateTime startedAt;
  final DateTime endedAt;
  final Duration duration;
  final double distanceMeters;
  final List<LatLng> path;
  final List<String> petIds;

  const WalkRecordScreen({
    super.key,
    required this.startedAt,
    required this.endedAt,
    required this.duration,
    required this.distanceMeters,
    required this.path,
    required this.petIds,
  });

  @override
  State<WalkRecordScreen> createState() => _WalkRecordScreenState();
}

class _WalkRecordScreenState extends State<WalkRecordScreen> {
  final TextEditingController _memoCtrl = TextEditingController();

  bool _isPublic = false; // is_public
  String _moodEmoji = '😊'; // mood_emoji

  final List<XFile> _photos = <XFile>[]; // post_images
  bool _saving = false;

  @override
  void dispose() {
    _memoCtrl.dispose();
    super.dispose();
  }

  String _fmtMin(Duration d) => '${d.inMinutes.toString().padLeft(2, '0')}분';

  Future<void> _pickPhotos() async {
    final picker = ImagePicker();
    final xs = await picker.pickMultiImage(imageQuality: 85);
    if (!mounted) return;
    if (xs.isEmpty) return;
    setState(() => _photos.addAll(xs));
  }

  List<LatLng> _samplePath(List<LatLng> src, {int maxPoints = 400}) {
    if (src.length <= maxPoints) return src;
    final step = (src.length / maxPoints).ceil();
    final out = <LatLng>[];
    for (var i = 0; i < src.length; i += step) {
      out.add(src[i]);
    }
    if (out.isEmpty && src.isNotEmpty) out.add(src.last);
    return out;
  }

  Future<List<String>> _uploadPhotos({required String walkId}) async {
    if (_photos.isEmpty) return [];

    final List<String> urls = [];
    for (var i = 0; i < _photos.length; i++) {
      final ref = FirebaseStorage.instance
          .ref()
          .child('walk_records')
          .child(walkId)
          .child('post_images')
          .child('img_$i.jpg');

      final file = File(_photos[i].path);
      await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
      urls.add(await ref.getDownloadURL());
    }
    return urls;
  }

  Future<void> _save() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다.')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final uid = user.uid;

      final docRef = FirebaseFirestore.instance.collection('walk_records').doc();
      final walkId = docRef.id;

      final postImages = await _uploadPhotos(walkId: walkId);

      final sampled = _samplePath(widget.path, maxPoints: 400);
      final route = sampled.map((p) => GeoPoint(p.latitude, p.longitude)).toList();

      final dateOnly = DateTime(widget.startedAt.year, widget.startedAt.month, widget.startedAt.day);

      final durationMinutes = widget.duration.inMinutes;
      final distanceKm = widget.distanceMeters / 1000.0;

      await docRef.set({
        // ===== 스키마 매칭 =====
        'walk_id': walkId,
        'user_id': uid,
        'pet_ids': widget.petIds,
        'date': Timestamp.fromDate(dateOnly),
        'start_time': Timestamp.fromDate(widget.startedAt),
        'end_time': Timestamp.fromDate(widget.endedAt),
        'duration_minutes': durationMinutes,
        'distance_km': double.parse(distanceKm.toStringAsFixed(3)),
        'route': route,
        'post_images': postImages,
        'memo': _memoCtrl.text.trim(),
        'mood_emoji': _moodEmoji,
        'like_count': 0,
        'is_public': _isPublic,
      });

      // ✅ Firebase 저장 성공 로그 (연동 확인용)
      // ignore: avoid_print
      print('walk_records saved: $walkId');

      if (_isPublic) {
        await Share.share(
          '산책 기록\n시간: ${_fmtMin(widget.duration)}\n거리: ${distanceKm.toStringAsFixed(2)}km\n메모: ${_memoCtrl.text.trim()}',
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('산책 기록이 저장되었습니다.')),
      );
    } catch (e) {
      // ignore: avoid_print
      print('walk_records save error: $e');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final distKm = (widget.distanceMeters / 1000).toStringAsFixed(2);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF233554),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 시간/거리
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
                          Text(_fmtMin(widget.duration),
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 44, color: const Color(0x33233554)),
                    Expanded(
                      child: Column(
                        children: [
                          const Text('거리', style: TextStyle(color: Color(0xFF233554), fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text('$distKm km', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // 기분
              Row(
                children: [
                  const Text('기분', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 10),
                  DropdownButton<String>(
                    value: _moodEmoji,
                    items: const ['😊', '😍', '😎', '😴', '😡', '😭']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 22))))
                        .toList(),
                    onChanged: (v) => setState(() => _moodEmoji = v ?? '😊'),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // 사진
              Text('산책 사진', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickPhotos,
                child: Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black26),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _photos.isEmpty
                      ? const Center(child: Icon(Icons.add, size: 40, color: Colors.black45))
                      : ListView.separated(
                          padding: const EdgeInsets.all(8),
                          scrollDirection: Axis.horizontal,
                          itemCount: _photos.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (_, i) => ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(_photos[i].path),
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 12),

              // 메모
              Text('메모 작성', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              TextField(
                controller: _memoCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),

              const Spacer(),

              Row(
                children: [
                  Checkbox(
                    value: _isPublic,
                    onChanged: (v) => setState(() => _isPublic = v ?? false),
                  ),
                  const Text('기록 공유하기'),
                  const Spacer(),
                  SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF233554),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                      ),
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : const Text('완료', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
