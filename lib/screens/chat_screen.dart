import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../services/chat_repository.dart';
import '../services/mothership_chat_client.dart';
import '../services/mothership_client.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatRepository _repository = ChatRepository();
  late final MothershipClient _mothershipClient;
  late final MothershipChatClient _chatClient;
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _syncing = false;
  bool _sending = false;
  List<ChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _mothershipClient = MothershipClient();
    _chatClient = MothershipChatClient(repository: _repository, baseClient: _mothershipClient);
    _refreshMessages();
  }

  Future<void> _refreshMessages() async {
    setState(() => _syncing = true);
    await _chatClient.sync();
    final list = await _repository.listMessages();
    if (!mounted) return;
    setState(() {
      _messages = list;
      _syncing = false;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendMessage() async {
    if (_sending) return;
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    final clientId = await _mothershipClient.ensureClientId();
    await _repository.addOutbound(clientId: clientId, body: text);
    _inputController.clear();
    await _chatClient.sync();
    final list = await _repository.listMessages();
    if (!mounted) return;
    setState(() {
      _messages = list;
      _sending = false;
    });
    _scrollToBottom();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('母艦チャット'),
        actions: [
          IconButton(
            tooltip: '再同期',
            onPressed: _syncing ? null : _refreshMessages,
            icon: _syncing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: theme.colorScheme.surface,
              child: _messages.isEmpty
                  ? Center(
                      child: Text(
                        _syncing ? '同期中...' : 'まだメッセージはありません',
                        style: theme.textTheme.bodyMedium,
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) => _MessageBubble(message: _messages[index]),
                    ),
            ),
          ),
          const Divider(height: 1),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'メッセージを入力',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _sending ? null : _sendMessage,
                    icon: const Icon(Icons.send),
                    label: const Text('送信'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isOutbound = message.direction == ChatDirection.outbound;
    final theme = Theme.of(context);
    final bubbleColor = isOutbound ? theme.colorScheme.primary : Colors.grey.shade200;
    final textColor = isOutbound ? Colors.white : Colors.grey.shade900;
    final align = isOutbound ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(isOutbound ? 16 : 4),
      bottomRight: Radius.circular(isOutbound ? 4 : 16),
    );
    final timeText = TimeOfDay.fromDateTime(message.createdAt.toLocal()).format(context);

    return Column(
      crossAxisAlignment: align,
      children: [
        Align(
          alignment: isOutbound ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: const BoxConstraints(maxWidth: 320),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: borderRadius,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: align,
              children: [
                Text(
                  message.body,
                  style: theme.textTheme.bodyMedium?.copyWith(color: textColor),
                ),
                const SizedBox(height: 6),
                Text(
                  timeText,
                  style: theme.textTheme.labelSmall?.copyWith(color: textColor.withValues(alpha: 0.8), fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
