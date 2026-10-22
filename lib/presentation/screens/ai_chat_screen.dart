import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/document.dart';
import '../../core/app_theme.dart';
import '../../data/providers/settings_provider.dart';
import '../../services/settings_service.dart';
import '../../screens/api_settings_screen.dart';
import '../providers/chat_provider.dart';

class AiChatScreen extends StatefulWidget {
  final Document document;
  final int currentPage;
  final String? extractedText;

  const AiChatScreen({
    super.key,
    required this.document,
    this.currentPage = 0,
    this.extractedText,
  });

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().initializeChat(widget.document, extractedText: widget.extractedText);
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSend(ChatProvider provider) {
    final text = _messageController.text.trim();
    if (text.isNotEmpty) {
      _messageController.clear(); // Clear input instantly
      provider.sendMessage(text); // Let the provider handle the async state
      _scrollToBottom();
      _focusNode.requestFocus(); // Keep keyboard open
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final settingsProvider = context.watch<SettingsProvider>();
    final bool isLoading = chatProvider.isLoading;

    final backgroundColor = settingsProvider.isDarkMode 
        ? AppTheme.darkBackground 
        : AppTheme.creamBackground;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.charcoalCard,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppTheme.coralAccent),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.document.fileName,
              style: const TextStyle(
                color: AppTheme.offWhiteText,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'AI Study Assistant',
              style: TextStyle(
                color: AppTheme.offWhiteText.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppTheme.offWhiteText),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: AppTheme.charcoalCard,
                  title: const Text(
                    'Clear Chat History',
                    style: TextStyle(color: AppTheme.offWhiteText),
                  ),
                  content: const Text(
                    'Are you sure you want to clear all messages in this chat?',
                    style: TextStyle(color: AppTheme.offWhiteText),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: AppTheme.coralAccent),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text(
                        'Clear',
                        style: TextStyle(color: AppTheme.coralAccent),
                      ),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                await context.read<ChatProvider>().clearChat();
              }
            },
          ),
        ],
      ),
      // ✅ PERFECT 3-TIER LAYOUT with SafeArea
      body: SafeArea(
        child: Column(
          children: [
            // A. TOP: Document header info
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'Chatting about: ${widget.document.fileName}',
                style: TextStyle(
                  fontSize: 12,
                  color: settingsProvider.isDarkMode ? AppTheme.offWhiteText : AppTheme.charcoalCard,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // B. MIDDLE: Messages list (Expanded to fill available space)
            Expanded(
              child: Builder(
                builder: (context) {
                  if (chatProvider.isLoading && chatProvider.messages.isEmpty) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.coralAccent,
                      ),
                    );
                  }

                  if (!chatProvider.hasMessages) {
                    return _buildEmptyState(settingsProvider);
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    reverse: true,
                    itemCount: chatProvider.messages.length,
                    itemBuilder: (context, index) {
                      final message = chatProvider.messages[chatProvider.messages.length - 1 - index];
                      return _buildMessageBubble(message, settingsProvider);
                    },
                  );
                },
              ),
            ),
            if (chatProvider.isLoading)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.charcoalCard,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        "AI is thinking...",
                        style: TextStyle(color: AppTheme.offWhiteText),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.coralAccent),
                    ),
                  ],
                ),
              ),
            _buildInputArea(chatProvider, isLoading, backgroundColor),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(SettingsProvider settingsProvider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.charcoalCard.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.psychology_outlined,
                size: 64,
                color: settingsProvider.isDarkMode ? AppTheme.offWhiteText : AppTheme.charcoalCard,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Start a conversation',
              style: TextStyle(
                color: settingsProvider.isDarkMode ? AppTheme.offWhiteText : AppTheme.charcoalCard,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ask questions about your document to get AI-powered insights and explanations.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: settingsProvider.isDarkMode ? AppTheme.offWhiteText : AppTheme.charcoalCard,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, SettingsProvider settingsProvider) {
    final isUser = message.sender == 'user';
    final isError = !isUser && (
      message.content.startsWith('Technical Error:') ||
      message.content.contains('Exception:') ||
      message.content.startsWith('Error fetching response:') ||
      message.content.contains('Add your Gemini API key in Settings')
    );
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: AppTheme.charcoalCard,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isError ? Icons.error_outline : Icons.smart_toy_outlined,
                color: AppTheme.offWhiteText,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser 
                    ? AppTheme.coralAccent 
                    : isError
                        ? Colors.red[900]
                        : AppTheme.charcoalCard,
                border: isError
                    ? Border.all(color: Colors.redAccent, width: 2)
                    : null,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: isError
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.error_outline, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: SelectableText(
                                message.content,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (message.content.contains('Add your Gemini API key in Settings')) ...[
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ApiSettingsScreen(),
                                ),
                              ).then((_) => setState(() {}));
                            },
                            icon: const Icon(Icons.settings, size: 16),
                            label: const Text('Open Settings'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.coralAccent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ],
                      ],
                    )
                  : Text(
                      message.content,
                      style: const TextStyle(
                        color: AppTheme.offWhiteText,
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 12),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.charcoalCard.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person_outline,
                color: settingsProvider.isDarkMode ? AppTheme.offWhiteText : AppTheme.charcoalCard,
                size: 20,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInputArea(ChatProvider chatProvider, bool isLoading, Color backgroundColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.charcoalCard,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _messageController,
                  focusNode: _focusNode,
                  enabled: !isLoading,
                  style: const TextStyle(
                    color: AppTheme.offWhiteText,
                    fontSize: 16,
                  ),
                  maxLines: 4,
                  minLines: 1,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: "Ask about the document...",
                    hintStyle: TextStyle(
                      color: AppTheme.offWhiteText.withValues(alpha: 0.6),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  onSubmitted: (_) => _handleSend(chatProvider),
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: isLoading ? null : () => _handleSend(chatProvider),
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: isLoading
                      ? AppTheme.charcoalCard.withValues(alpha: 0.5)
                      : AppTheme.coralAccent,
                  shape: BoxShape.circle,
                  boxShadow: isLoading ? null : [
                    BoxShadow(
                      color: AppTheme.coralAccent.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.send_rounded,
                  color: AppTheme.offWhiteText,
                  size: 24,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
