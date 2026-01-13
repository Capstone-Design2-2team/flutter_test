import 'package:flutter/material.dart';

class PostsScreen extends StatelessWidget {
  const PostsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF233554),
        title: const Text(
          '게시글',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: const Center(
        child: Text(
          '게시글 화면',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
