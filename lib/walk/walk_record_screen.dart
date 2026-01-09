// lib/walk/walk_record_screen.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

class WalkRecordScreen extends StatefulWidget {
  final DateTime startedAt;
  final DateTime endedAt;
  final Duration duration;
  final double distanceMeters;
  final List<LatLng> path;

  const WalkRecordScreen({
    super.key,
    required this.startedAt,
    required this.endedAt,
    required this.duration,
    required this.distanceMeters,
    required this.path,
  });

  @override
  State<WalkRecordScreen> createState() => _WalkRecordScreenState();
}

class _WalkRecordScreenState extends State<WalkRecordScreen> {
  final _memoCtrl = TextEditingController();
  bool _share = false;

  XFile? _photo;
  bool _saving = false;

  @override
  void dispose() {
    _memoCtrl.dispose();
    super.dispose();
  }

  String _fmtMin(Duration d) => '${d.inMinutes.toString().padLeft(2, '0')}분';

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (!mounted) return;
    setState(() => _photo = x);
  }

  Future<String?> _uploadPhotoIfAny(String uid, String walkId) async {
    if (_photo == null) return null;

    final ref = FirebaseStorage.instance
        .ref()
        .child('walks')
        .child(uid)
        .child('$walkId.jpg');

    if (kIsWeb) {
      final bytes = await _photo!.readAsBytes();
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    } else {
      // ignore: avoid_slow_async_io
      await ref.putFile(FileX.platformFile(_photo!));
    }

    return await ref.getDownloadURL();
  }

  Future<void> _save() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('로그인이 필요합니다.')));
      return;
    }

    setState(() => _saving = true);
    try {
      final uid = user.uid;
      final walkRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('walks')
          .doc();

      final photoUrl = await _uploadPhotoIfAny(uid, walkRef.id);

      // Firestore 문서 크기(1MB) 때문에 path가 길면 터질 수 있어서 샘플링 권장
      final sampled = _samplePath(widget.path, maxPoints: 400);

      await walkRef.set({
        'createdAt': FieldValue.serverTimestamp(),
        'startedAt': Timestamp.fromDate(widget.startedAt),
        'endedAt': Timestamp.fromDate(widget.endedAt),
        'durationSec': widget.duration.inSeconds,
        'distanceM': widget.distanceMeters,
        'memo': _memoCtrl.text.trim(),
        'share': _share,
        'photoUrl': photoUrl,
        'path': sampled
            .map((p) => GeoPoint(p.latitude, p.longitude))
            .toList(),
      });

      if (_share) {
        final text =
            '산책 기록\n시간: ${_fmtMin(widget.duration)}\n거리: ${(widget.distanceMeters / 1000).toStringAsFixed(2)}km\n메모: ${_memoCtrl.text.trim()}';
        await Share.share(text);
      }

      if (!mounted) return;
      Navigator.of(context).pop(); // 기록 화면 닫기
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('산책 기록이 저장되었습니다.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('저장 실패: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<LatLng> _samplePath(List<LatLng> src, {required int maxPoints}) {
    if (src.length <= maxPoints) return src;
    final step = (src.length / maxPoints).ceil();
    final out = <LatLng>[];
    for (var i = 0; i < src.length; i += step) {
      out.add(src[i]);
    }
    if (out.isEmpty && src.isNotEmpty) out.add(src.last);
    return out;
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
            children: [
              // 시간/거리 캡슐
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

              const SizedBox(height: 18),

              // 사진
              Align(
                alignment: Alignment.centerLeft,
                child: Text('산책 사진', style: Theme.of(context).textTheme.titleMedium),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickPhoto,
                child: Container(
                  height: 160,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black26),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _photo == null
                      ? const Center(child: Icon(Icons.add, size: 40, color: Colors.black45))
                      : ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: kIsWeb
                        ? FutureBuilder<Uint8List>(
                      future: _photo!.readAsBytes(),
                      builder: (c, snap) {
                        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                        return Image.memory(snap.data!, fit: BoxFit.cover);
                      },
                    )
                        : Image.file(FileX.platformFile(_photo!), fit: BoxFit.cover),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // 메모
              Align(
                alignment: Alignment.centerLeft,
                child: Text('메모 작성', style: Theme.of(context).textTheme.titleMedium),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _memoCtrl,
                maxLines: 4,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),

              const SizedBox(height: 10),

              Row(
                children: [
                  Checkbox(
                    value: _share,
                    onChanged: (v) => setState(() => _share = v ?? false),
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
                        child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
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

/// image_picker XFile -> File 변환(모바일용)
/// dart:io 를 직접 import 하면 web에서 에러날 수 있어 분리 우회
class FileX {
  static dynamic platformFile(XFile x) {
    // ignore: avoid_web_libraries_in_flutter
    // (web은 여기로 들어오지 않도록 위에서 분기)
    // ignore: undefined_class
    return File(x.path);
  }
}
