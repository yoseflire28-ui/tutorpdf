import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../data/providers/active_document_provider.dart';
import '../presentation/providers/chat_provider.dart';
import '../services/text_extraction_service.dart';
import '../services/settings_service.dart';
import '../models/document.dart';
import 'api_settings_screen.dart';

class AiChatScreen extends StatefulWidget {
  final Document document;
  final int currentPage;
  const AiChatScreen({
    super.key,
    required this.document,
    this.currentPage = 0,
  });

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  int _lastMessageCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final activeProvider = context.read<ActiveDocumentProvider>();
      final chatProvider = context.read<ChatProvider>();

      String? text = activeProvider.extractedText;
      if (text == null || text.isEmpty) {
        final extractor = TextExtractionService();
        text = await extractor.extractText(widget.document.filePath);
        if (text.isEmpty && activeProvider.convertedPdfPath != null && activeProvider.convertedPdfPath!.isNotEmpty) {
          text = await extractor.extractText(activeProvider.convertedPdfPath!);
        }
      }

      await chatProvider.initializeChat(widget.document, extractedText: text);
      chatProvider.addListener(_onProviderUpdate);
    });

    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 300), _scrollToBottom);
      }
    });
  }

  @override
  void dispose() {
    // Avoid accessing provider if context is already unmounted/disposing
    try {
      context.read<ChatProvider>().removeListener(_onProviderUpdate);
    } catch (_) {}
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onProviderUpdate() {
    if (!mounted) return;
    final provider = context.read<ChatProvider>();
    if (provider.messages.length != _lastMessageCount) {
      _lastMessageCount = provider.messages.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _handleSend(ChatProvider provider) {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      _controller.clear(); // Clear input instantly
      provider.sendMessage(text); // Let the provider handle the async state
      _focusNode.requestFocus(); // Keep keyboard open
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final bool isLoading = chatProvider.isLoading;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF3D3D3F),
        elevation: 0,
        title: Text(
          'Chat with ${widget.document.fileName}',
          style: const TextStyle(color: Color(0xFFF9F6F0), fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Color(0xFFF9F6F0)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever, color: Color(0xFFF9F6F0)),
            tooltip: 'Clear Conversation',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: const Color(0xFF3D3D3F),
                  title: const Text('Clear Chat', style: TextStyle(color: Color(0xFFF9F6F0))),
                  content: const Text(
                      'Are you sure you want to wipe out the entire conversation thread history?',
                      style: TextStyle(color: Color(0xFFF9F6F0))),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel', style: TextStyle(color: Color(0xFFE65A4B))),
                    ),
                    TextButton(
                      onPressed: () {
                        chatProvider.clearChat();
                        Navigator.pop(context);
                      },
                      child: const Text('Clear All',
                          style: TextStyle(color: Color(0xFFE65A4B))),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Container(
        color: const Color(0xFFEFE7DC), // Cream Background
        child: Column(
          children: [
            // Top Context Chip pinned right below AppBar
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFF3D3D3F), // Dark Charcoal Context Bar
              child: Text(
                'Context: "${widget.document.fileName}"',
                style: const TextStyle(
                  color: Color(0xFFF9F6F0),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            FutureBuilder<bool>(
              future: SettingsService().hasApiKey(),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data == false) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3D3D3F),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE65A4B)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.vpn_key_outlined, color: Color(0xFFE65A4B), size: 22),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Add your Gemini API key in Settings to use AI features',
                            style: TextStyle(color: Color(0xFFF9F6F0), fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ApiSettingsScreen()),
                            ).then((_) => setState(() {}));
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: const Color(0xFFE65A4B),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          ),
                          child: const Text('Settings'),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                reverse: false, // Oldest Top, Newest Bottom
                padding: const EdgeInsets.all(12),
                itemCount: chatProvider.messages.length,
                itemBuilder: (context, index) {
                  final msg = chatProvider.messages[index];
                  final isUser = msg.sender == 'user';

                  final isError = !isUser && (
                    msg.content.startsWith('Technical Error:') ||
                    msg.content.contains('Exception:') ||
                    msg.content.startsWith('Error fetching response:') ||
                    msg.content.startsWith('AI returned an empty response.') ||
                    msg.content.startsWith('Service Error:') ||
                    msg.content.contains('Add your Gemini API key in Settings')
                  );

                  return Align(
                    alignment:
                        isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        crossAxisAlignment: isUser
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          Container(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.8,
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isUser
                                  ? const Color(0xFFE65A4B) // Coral Red accent
                                  : isError
                                      ? Colors.red[900] // Error red
                                      : const Color(0xFF3D3D3F), // Dark Charcoal AI bubble
                              border: isError
                                  ? Border.all(color: Colors.redAccent, width: 2)
                                  : null,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(16),
                                topRight: const Radius.circular(16),
                                bottomLeft: Radius.circular(isUser ? 16 : 4),
                                bottomRight: Radius.circular(isUser ? 4 : 16),
                              ),
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
                                              msg.content,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (msg.content.contains('Add your Gemini API key in Settings')) ...[
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
                                            backgroundColor: const Color(0xFFE65A4B),
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
                                : SelectableText(
                                    msg.content,
                                    style: const TextStyle(
                                      color: Color(0xFFF9F6F0), // Off-White text
                                      fontSize: 15,
                                    ),
                                  ),
                          ),
                          // Interactive Message Toolkit Pop-up Row
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 2),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    Clipboard.setData(
                                        ClipboardData(text: msg.content));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Copied to clipboard'),
                                        duration: Duration(seconds: 1),
                                      ),
                                    );
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.all(4.0),
                                    child: Icon(
                                      Icons.copy,
                                      size: 14,
                                      color: Color(0xFF3D3D3F),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () {
                                    chatProvider.deleteMessage(index);
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.all(4.0),
                                    child: Icon(
                                      Icons.delete_outline,
                                      size: 14,
                                      color: Color(0xFF3D3D3F),
                                    ),
                                  ),
                                ),
                                // Refresh/Regenerate: Only for the last AI message
                                if (!isUser &&
                                    index ==
                                        chatProvider.messages.length - 1) ...[
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () {
                                      chatProvider.regenerateLastResponse();
                                    },
                                    child: const Padding(
                                      padding: EdgeInsets.all(4.0),
                                      child: Icon(
                                        Icons.refresh,
                                        size: 14,
                                        color: Color(0xFF3D3D3F),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
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
                        color: const Color(0xFF3D3D3F),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        "AI is thinking...",
                        style: TextStyle(color: Color(0xFFF9F6F0)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFE65A4B)),
                    ),
                  ],
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: const Color(0xFFEFE7DC),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _handleSend(chatProvider),
                      style: const TextStyle(color: Color(0xFFF9F6F0), fontSize: 16),
                      decoration: InputDecoration(
                        hintText: "Ask about the document...",
                        hintStyle: TextStyle(color: const Color(0xFFF9F6F0).withValues(alpha: 0.6)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: const Color(0xFF3D3D3F),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: isLoading ? null : () => _handleSend(chatProvider),
                    child: Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFE65A4B),
                      ),
                      child: const Icon(Icons.send, color: Color(0xFFF9F6F0)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
