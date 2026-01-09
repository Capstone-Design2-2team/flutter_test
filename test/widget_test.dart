// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:teamproject/main.dart';

void main() {
  testWidgets('App starts with StartScreen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const PetMoveApp());

    // Verify that the app starts with StartScreen
    expect(find.text('PETMOVE'), findsOneWidget);
    expect(find.text('시작하기'), findsOneWidget);
    expect(find.text('회원 가입'), findsOneWidget);
  });
}
