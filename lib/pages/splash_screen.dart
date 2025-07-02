import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tatehama_trainradio/pages/radio_screen.dart';
import 'package:url_launcher/url_launcher.dart';

// ScreenStateの定義
enum ScreenState {
  initializing,
  loginRequired,
  success,
  pcConnectionRequired,
  standaloneConfirmation,
  speechSelectionRequired,
  qrScanning,
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

  String? _displayName;
  String? _discordAvatarUrl;
  String? _pcConnectionInfo;

  final MobileScannerController _scannerController = MobileScannerController();
  
  int _pcTextTapCount = 0;
  DateTime _lastTapTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _playPushSound() {
    // ボタンが押されるたびに新しいプレイヤーを作成して再生し、即座に破棄する
    AudioPlayer().play(AssetSource('sound/push.mp3'));
  }

  void _playNoticeSound() {
    AudioPlayer().play(AssetSource('sound/notice.mp3'));
  }

  Future<void> _initializeApp() async {
    setState(() => _currentState = ScreenState.initializing);
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

  Future<void> _handleDiscordLogin() async {
    _playPushSound();
    setState(() => _currentState = ScreenState.initializing);

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

    final error = uri.queryParameters['error'];
    if (error != null) {
      if (error == 'not_in_guild') {
        _setErrorState(403, '指定されたサーバーに参加していません。');
      } else {
        _setErrorState(-103, '認証に失敗しました。($error)');
      }
      return;
    }

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
  
  void _onConnectToRadioPressed() {
    _playPushSound();
    setState(() {
      _currentState = ScreenState.pcConnectionRequired;
    });
  }

  void _onSpeechSelection(bool canSpeak) async {
    _playPushSound();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('canSpeak', canSpeak);
    
    _navigateToRadioScreen(canSpeak: canSpeak, pcConnectionInfo: _pcConnectionInfo);
  }

  void _onScanQrPressed() {
    _playPushSound();
    setState(() {
      _currentState = ScreenState.qrScanning;
    });
  }

  void _handleHiddenTap() {
    _playPushSound();
    final now = DateTime.now();
    if (now.difference(_lastTapTime).inSeconds > 1) {
      _pcTextTapCount = 0;
    }
    _lastTapTime = now;
    _pcTextTapCount++;
    
    if (_pcTextTapCount >= 5) {
      _pcTextTapCount = 0;
      _playNoticeSound();
      setState(() {
        _currentState = ScreenState.standaloneConfirmation;
      });
    }
  }

  Widget _buildStandaloneConfirmationUi() {
    return Container(
      key: const ValueKey('standalone_confirmation'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.yellow.shade800.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.yellow.shade800, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.yellow, size: 48),
          const SizedBox(height: 16),
          const Text(
            '本当にスタンドアローンモードで起動しますか？',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 16),
          const Text(
            'PCアプリに接続せずに起動するとこのような制限があります。',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          const Text(
            '・VoiceVoxによる読み上げ機能が利用できません。\n'
            '・走行位置、列車番号が取得できないため手動で設定する必要があります。\n'
            '・防護無線が列車無線から発報できません。ATS側で操作する必要があります。',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 24),
          const Text(
            'これでも本当にスタンドアローンモードで起動しますか？',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton(
                onPressed: () {
                  _playPushSound();
                  setState(() {
                    _currentState = ScreenState.pcConnectionRequired;
                  });
                },
                child: const Text('いいえ'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () {
                  _playPushSound();
                  setState(() {
                    _pcConnectionInfo = null;
                    _currentState = ScreenState.speechSelectionRequired;
                  });
                },
                child: const Text('はい'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPcConnectionUi() {
    return Column(
      key: const ValueKey('pc_connection'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: _handleHiddenTap,
          child: const Text('PCアプリに接続をします。', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 32),
        ElevatedButton.icon(
          icon: const Icon(Icons.qr_code_scanner, size: 28),
          label: const Text('QRコードを読み取る'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            shape: const StadiumBorder(),
          ),
          onPressed: _onScanQrPressed,
        ),
        const SizedBox(height: 32),
        const Text(
          'PCアプリはインストールしていますか？',
          style: TextStyle(color: Colors.white70),
        ),
        TextButton(
          onPressed: () {
            // TODO: PCアプリのダウンロードページなどのURLを開く
            // launchUrl(Uri.parse('https://example.com'));
          },
          child: const Text(
            'されていない場合はこちらを確認してください。',
            style: TextStyle(decoration: TextDecoration.underline, decorationColor: Colors.white70),
          ),
        ),
      ],
    );
  }

  Widget _buildQrScannerUi() {
    return Column(
      key: const ValueKey('qr_scanner'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('PC画面のQRコードを読み取ってください', style: TextStyle(color: Colors.white, fontSize: 16)),
        const SizedBox(height: 24),
        SizedBox(
          width: 250,
          height: 250,
          child: Stack(
            alignment: Alignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: MobileScanner(
                  controller: _scannerController,
                  onDetect: (capture) {
                    final List<Barcode> barcodes = capture.barcodes;
                    if (barcodes.isNotEmpty) {
                      final String? code = barcodes.first.rawValue;
                      if (code != null) {
                        _scannerController.stop();
                        print('QRコードを読み取りました: $code');
                        setState(() {
                          _pcConnectionInfo = code;
                          _currentState = ScreenState.speechSelectionRequired;
                        });
                      }
                    }
                  },
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.green.withOpacity(0.7), width: 4),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        TextButton(
          onPressed: () {
            _playPushSound();
            setState(() {
              _currentState = ScreenState.pcConnectionRequired;
            });
          },
          child: const Text('キャンセル', style: TextStyle(color: Colors.white)),
        )
      ],
    );
  }

  void _navigateToRadioScreen({required bool canSpeak, String? pcConnectionInfo}) {
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => RadioScreen(
            displayName: _displayName ?? '不明',
            avatarUrl: _discordAvatarUrl,
            canSpeak: canSpeak,
            pcConnectionInfo: pcConnectionInfo,
          ),
        ),
      );
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

  Widget _buildSelectionCard({
    required String title,
    required String imageUrl,
    required String description,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        color: const Color(0xFF40444B),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Image.asset(
                imageUrl,
                height: 80,
                width: 80,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox(height: 80, width: 80, child: Icon(Icons.error)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: TextStyle(color: Colors.white.withOpacity(0.7)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainLayout() {
    return Column(
      key: const ValueKey('main_layout'),
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
                    onPressed: _onConnectToRadioPressed,
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
                    if (_errorCode == 403 || _errorCode == -2)
                      _buildDiscordLoginButton()
                    else
                      TextButton(
                        onPressed: () {
                          _playPushSound();
                          _initializeApp();
                        },
                        child: const Text('再試行', style: TextStyle(color: Colors.white, fontSize: 16)),
                      )
                  ],
                ),
              ),
            _ => const SizedBox.shrink(),
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF23272A),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            transitionBuilder: (child, animation) {
              return FadeTransition(opacity: animation, child: child);
            },
            child: switch (_currentState) {
              ScreenState.qrScanning => _buildQrScannerUi(),
              ScreenState.standaloneConfirmation => _buildStandaloneConfirmationUi(),
              ScreenState.pcConnectionRequired => _buildPcConnectionUi(),
              ScreenState.speechSelectionRequired => Column(
                  key: const ValueKey('speech_selection'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('あなたは....', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    _buildSelectionCard(
                      title: '喋れます',
                      imageUrl: 'assets/images/talk.png',
                      description: 'PTTスイッチが大きく表示されます。',
                      onTap: () => _onSpeechSelection(true),
                    ),
                    const SizedBox(height: 16),
                    _buildSelectionCard(
                      title: '喋れません',
                      imageUrl: 'assets/images/no_talk.png',
                      description: '代わりにずんだもんが喋ります。PTTスイッチは小さく配置されます。',
                      onTap: () => _onSpeechSelection(false),
                    ),
                    const SizedBox(height: 24),
                    Text('この設定はあとから変更することができます。', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                  ],
                ),
              _ => _buildMainLayout(),
            },
          ),
        ),
      ),
    );
  }
}
