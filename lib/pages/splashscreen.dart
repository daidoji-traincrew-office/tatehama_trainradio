import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_appauth/flutter_appauth.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _showLoading = false;
  bool _showLoginButton = false;
  String? _error;

  @override
  void initState() {
    super.initState();

    // 2秒後にローディング開始
    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        _showLoading = true;
      });

      _checkInternetConnection().then((success) {
        if (!success) {
          setState(() {
            _error = 'ネットワーク接続に失敗しました。';
            _showLoading = false;
          });
          return;
        }

        // 接続成功したらさらに2秒後にログイン表示
        Future.delayed(const Duration(seconds: 2), () {
          setState(() {
            _showLoginButton = true;
            _showLoading = false;
          });
        });
      });
    });
  }

  Future<bool> _checkInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/logo.png',
              width: 200,
            ),
            const SizedBox(height: 20),
            const Text(
              '館浜電鉄列車無線',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 30),
            Visibility(
              visible: _showLoading && _error == null,
              child: const Text(
                '起動中...',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: Visibility(
                visible: _showLoading,
                child: const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 30,
              child: _error != null
                  ? Text(
                      _error!,
                      style: const TextStyle(color: Colors.red, fontSize: 16),
                    )
                  : null,
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 48,
              child: Visibility(
                visible: _showLoginButton,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final FlutterAppAuth appAuth = FlutterAppAuth();

                    const String clientId = '1384881561094324264';
                    const String redirectUrl = 'tatehama://auth';
                    const List<String> scopes = ['identify'];

                    try {
                      final AuthorizationTokenResponse? result =
                          await appAuth.authorizeAndExchangeCode(
                        AuthorizationTokenRequest(
                          clientId,
                          redirectUrl,
                          serviceConfiguration: AuthorizationServiceConfiguration(
                            authorizationEndpoint: 'https://discord.com/oauth2/authorize',
                            tokenEndpoint: 'https://discord.com/api/oauth2/token',
                          ),
                          scopes: scopes,
                        ),
                      );

                      if (result != null) {
                        final String? accessToken = result.accessToken;
                        print('アクセストークン: $accessToken');
                        // TODO: サーバー側にアクセストークンを送る処理を追加
                      }
                    } catch (e) {
                      print('Discordログイン失敗: $e');
                    }
                  },
                  icon: Image.asset(
                    'assets/images/Discord.png',
                    width: 24,
                    height: 24,
                  ),
                  label: const Text('Discordでログイン'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}