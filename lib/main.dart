import 'package:flutter/material.dart';
import 'package:tatehama_trainradio/pages/splashscreen.dart';

void main() {
  runApp(const TatehamaTrainRadioApp());
}

class TatehamaTrainRadioApp extends StatelessWidget {
  const TatehamaTrainRadioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '館浜電鉄列車無線',
      theme: ThemeData.dark(),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
