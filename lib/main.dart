import 'package:flutter/material.dart';
import 'package:tatehama_trainradio/pages/splash_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '館浜電鉄列車無線',
      theme: ThemeData(
        // アプリ全体の基本的なテーマ設定
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFF23272A), // 背景色をスプラッシュ画面と統一
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      // 最初に表示する画面をSplashScreenに設定
      home: const SplashScreen(),
    );
  }
}
