import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // PlatformExceptionのためにインポート
import 'package:http/http.dart' as http;
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

// ScreenStateの定義
enum ScreenState {
  initializing,
  loginRequired,
  success,
  error,
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  ScreenState _currentState = ScreenState.initializing;
  String _errorMessage = '';
  int _errorCode = 0;

  String? _displayName; // 表示名（ニックネーム or ユーザー名）
  String? _discordAvatarUrl;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  @override
  void dispose() {
    super.dispose();
  }

  // 初期化処理
  Future<void> _initializeApp() async {
    setState(() => _currentState = ScreenState.initializing);
    
    // ネットワークチェック
    try {
      await http.get(Uri.parse('https://www.google.com')).timeout(const Duration(seconds: 5));
      if (mounted) setState(() => _currentState = ScreenState.loginRequired);
    } on TimeoutException {
      _setErrorState(408, '接続がタイムアウトしました。');
    } on SocketException {
      _setErrorState(-1, 'ネットワークに接続できません。');
    } catch (e) {
      _setErrorState(-99, '不明なエラーが発生しました。');
    }
  }

  void _setErrorState(int code, String message) {
    if (mounted) {
      setState(() {
        _currentState = ScreenState.error;
        _errorCode = code;
        _errorMessage = message;
      });
    }
  }

  /// Discordログインボタンが押されたときの処理
  Future<void> _handleDiscordLogin() async {
    setState(() {
      _currentState = ScreenState.initializing; // 処理中はインジケータを表示
    });

    final url = Uri.parse('https://discord.com/oauth2/authorize?client_id=1384881561094324264&response_type=code&redirect_uri=http%3A%2F%2Ftrain-radio.tatehama.jp%2Fauth%2Fdiscord%2Fcallback&scope=identify+guilds+guilds.members.read');
    const callbackUrlScheme = 'tatehama-trainradio';

    try {
      final result = await FlutterWebAuth2.authenticate(
        url: url.toString(),
        callbackUrlScheme: callbackUrlScheme,
      );
      _processUri(Uri.parse(result));
    } on PlatformException catch (e) {
      if (e.code == 'CANCELED' || e.code == 'USER_CANCELLED') {
        _setErrorState(-2, '認証がキャンセルされました。');
      } else {
        _setErrorState(-105, '認証フローを開始できませんでした。');
      }
    } catch (e) {
      _setErrorState(-99, '不明なエラーが発生しました。');
    }
  }
  
  void _processUri(Uri? uri) {
    if (uri == null) {
        _setErrorState(-2, '認証がキャンセルされました。');
        return;
    }
    
    // ★★★ エラーハンドリングロジックを修正 ★★★
    // 常に auth-success で返ってくるので、まず error パラメータの有無を確認する
    final error = uri.queryParameters['error'];
    if (error != null) {
      if (error == 'not_in_guild') {
        _setErrorState(403, '指定されたサーバーに参加していません。');
      } else {
        _setErrorState(-103, '認証に失敗しました。($error)');
      }
      return;
    }

    // error パラメータがなければ、token を探す
    final token = uri.queryParameters['token'];
    if (token != null) {
      _processSuccessToken(token);
    } else {
      _setErrorState(-102, '認証トークンが見つかりませんでした。');
    }
  }

  void _processSuccessToken(String token) {
    try {
      final Map<String, dynamic> decodedToken = JwtDecoder.decode(token);
      final userId = decodedToken['userId'];
      final username = decodedToken['username'];
      final guildNickname = decodedToken['guildNickname'];
      final avatarHash = decodedToken['avatar'];
      
      setState(() {
        _currentState = ScreenState.success;
        _displayName = guildNickname ?? username;
        if (avatarHash != null) {
          _discordAvatarUrl = 'https://cdn.discordapp.com/avatars/$userId/$avatarHash.png';
        }
      });
    } catch (e) {
      _setErrorState(-104, 'ユーザー情報の解析に失敗しました。');
    }
  }

  Widget _buildDiscordLoginButton() {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF5865F2),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: const StadiumBorder(),
      ),
      onPressed: _handleDiscordLogin,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/images/Discord.png', height: 24),
          const SizedBox(width: 12),
          const Text('Discordでログイン', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF23272A),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/images/logo.png', width: 200),
              const SizedBox(height: 24),
              const Text(
                '館浜電鉄列車無線',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 40), 
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) {
                  return FadeTransition(opacity: animation, child: child);
                },
                child: switch (_currentState) {
                  ScreenState.initializing => const SizedBox(
                      height: 100,
                      key: ValueKey('progress'), 
                      child: Center(child: CircularProgressIndicator(color: Colors.white70))
                    ),
                  ScreenState.loginRequired => SizedBox(
                      height: 100,
                      key: const ValueKey('button'), 
                      child: Center(child: _buildDiscordLoginButton())
                    ),
                  
                  ScreenState.success => Column(
                      key: const ValueKey('success'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_discordAvatarUrl != null)
                          CircleAvatar(
                            radius: 40,
                            backgroundImage: NetworkImage(_discordAvatarUrl!),
                          )
                        else
                          const CircleAvatar(
                            radius: 40,
                            backgroundColor: Colors.grey,
                            child: Icon(Icons.person, size: 40, color: Colors.white),
                          ),
                        const SizedBox(height: 16),
                        Text(
                          'ようこそ ${_displayName ?? 'ユーザー'}さん',
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.tram_outlined),
                          label: const Text('列車無線に接続する'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            shape: const StadiumBorder(),
                          ),
                          onPressed: () { /* TODO: 次の画面へ */ },
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _handleDiscordLogin,
                          child: const Text(
                            '別のアカウントでログイン',
                            style: TextStyle(color: Colors.white70, decoration: TextDecoration.underline, decorationColor: Colors.white70),
                          ),
                        ),
                      ],
                    ),

                  ScreenState.error => SizedBox(
                      height: 120,
                      key: const ValueKey('error'),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$_errorCode: $_errorMessage',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 20),
                          if (_errorCode == 403 || _errorCode == -2) // サーバー未参加 or キャンセル
                            _buildDiscordLoginButton()
                          else // その他のエラー
                            TextButton(
                              onPressed: _initializeApp,
                              child: const Text('再試行', style: TextStyle(color: Colors.white, fontSize: 16)),
                            )
                        ],
                      ),
                    ),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
