import 'package:flutter/material.dart';

class RadioScreen extends StatefulWidget {
  final String displayName;
  final String? avatarUrl;
  final bool canSpeak;
  final String? pcConnectionInfo; // ★ PC連携情報を受け取る

  const RadioScreen({
    super.key,
    required this.displayName,
    required this.canSpeak,
    this.avatarUrl,
    this.pcConnectionInfo, // ★ コンストラクタに追加
  });

  @override
  State<RadioScreen> createState() => _RadioScreenState();
}

class _RadioScreenState extends State<RadioScreen> {
  bool _isConnected = true;
  bool _isTransmitting = false;
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<String> _logs = [
    '司令室: 3番線、出発進行。',
    'こちら1234A、了解。',
  ];

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendTextMessage(String text) {
    if (text.isEmpty) return;
    setState(() {
      _logs.insert(0, '${widget.displayName}: $text');
    });
    _textController.clear();
    _scrollController.animateTo(
      0.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Widget _buildInputArea() {
    if (widget.canSpeak) {
      return GestureDetector(
        onLongPressStart: (details) {
          setState(() => _isTransmitting = true);
        },
        onLongPressEnd: (details) {
          setState(() => _isTransmitting = false);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 32), 
          decoration: BoxDecoration(
            color: _isTransmitting ? Colors.red.shade700 : Colors.blue,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: const Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.mic, color: Colors.white, size: 32),
                SizedBox(width: 12),
                Text(
                  '押して話す',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } 
    else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        decoration: BoxDecoration(
          color: const Color(0xFF40444B),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _textController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'メッセージを入力...',
                  hintStyle: TextStyle(color: Colors.white54),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16),
                ),
                onSubmitted: _sendTextMessage,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send, color: Colors.white70),
              onPressed: () => _sendTextMessage(_textController.text),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF36393F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2F3136),
        title: const Text('館浜電鉄 列車無線'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Row(
              children: [
                Icon(
                  Icons.circle,
                  color: _isConnected ? Colors.greenAccent : Colors.redAccent,
                  size: 14,
                ),
                const SizedBox(width: 8),
                Text(_isConnected ? '接続中' : '未接続'),
              ],
            ),
          )
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12.0),
            color: const Color(0xFF2F3136),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: widget.avatarUrl != null
                      ? NetworkImage(widget.avatarUrl!)
                      : null,
                  child: widget.avatarUrl == null
                      ? const Icon(Icons.person, size: 20)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.displayName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const Text(
                        '列車番号: 1234A / 館浜本線',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      // ★ PC連携情報を表示
                      if (widget.pcConnectionInfo != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            'PC連携中: ${widget.pcConnectionInfo}',
                            style: const TextStyle(color: Colors.cyanAccent, fontSize: 10),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              reverse: true,
              itemCount: _logs.length,
              itemBuilder: (context, index) {
                return ListTile(
                  leading: const Icon(Icons.record_voice_over, size: 20),
                  title: Text(_logs[index]),
                  dense: true,
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.black.withOpacity(0.2),
            child: _buildInputArea(),
          ),
        ],
      ),
    );
  }
}
