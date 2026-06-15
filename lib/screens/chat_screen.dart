import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/top_bar.dart';
import '../services/gemini_service.dart';

class ChatScreen extends StatefulWidget {
  final String diseaseName;

  const ChatScreen({super.key, required this.diseaseName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<Map<String, String>> _messages = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GeminiService _geminiService = GeminiService();
  bool _loading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Initialize with a welcome message
    final cleanName = widget.diseaseName.replaceAll('_', ' ');
    _messages.add({
      "role": "model",
      "message": "Hello! I am your Rice Guard AI assistant. Your crop has been diagnosed with **$cleanName**.\n\nI can only answer questions or provide details about **$cleanName**. How can I help you manage or treat it today?"
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
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

  void _sendMessage([String? customText]) async {
    final text = customText ?? _textController.text.trim();
    if (text.isEmpty) return;

    if (customText == null) {
      _textController.clear();
    }

    setState(() {
      _messages.add({"role": "user", "message": text});
      _loading = true;
      _errorMessage = null;
    });

    _scrollToBottom();

    try {
      // Create history list: exclude the newly added user message
      final history = _messages.sublist(0, _messages.length - 1);
      
      final response = await _geminiService.askChatbot(
        diseaseName: widget.diseaseName.replaceAll('_', ' '),
        history: history,
        message: text,
      );

      if (mounted) {
        setState(() {
          _messages.add({"role": "model", "message": response});
          _loading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMessage = e.toString().replaceFirst("Exception: ", "");
          _messages.add({
            "role": "model",
            "message": "⚠️ Sorry, I encountered an error: $_errorMessage"
          });
        });
        _scrollToBottom();
      }
    }
  }

  Widget _buildMessageText(String text, bool isUser) {
    final List<TextSpan> spans = [];
    final regExp = RegExp(r'\*\*(.*?)\*\*');
    int start = 0;

    for (final match in regExp.allMatches(text)) {
      if (match.start > start) {
        spans.add(TextSpan(
          text: text.substring(start, match.start),
          style: TextStyle(
            color: isUser ? Colors.white : AppColors.text,
            fontSize: 14.5,
            height: 1.4,
          ),
        ));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: TextStyle(
          color: isUser ? Colors.white : AppColors.text,
          fontWeight: FontWeight.bold,
          fontSize: 14.5,
          height: 1.4,
        ),
      ));
      start = match.end;
    }

    if (start < text.length) {
      spans.add(TextSpan(
        text: text.substring(start),
        style: TextStyle(
          color: isUser ? Colors.white : AppColors.text,
          fontSize: 14.5,
          height: 1.4,
        ),
      ));
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            TopBar(
              title: 'Rice Guard AI Assistant',
              onBack: () => Navigator.pop(context),
            ),
            
            // Disease Context Header
            

            // Chat Message List
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  final isUser = msg["role"] == "user";
                  
                  return Align(
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.78,
                      ),
                      decoration: BoxDecoration(
                        color: isUser ? AppColors.green : AppColors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16),
                          topRight: const Radius.circular(16),
                          bottomLeft: Radius.circular(isUser ? 16 : 4),
                          bottomRight: Radius.circular(isUser ? 4 : 16),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          )
                        ],
                        border: isUser ? null : Border.all(color: AppColors.border),
                      ),
                      child: _buildMessageText(msg["message"] ?? "", isUser),
                    ),
                  );
                },
              ),
            ),

            if (_loading)
              Padding(
                padding: const EdgeInsets.only(left: 20, bottom: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.green,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "AI is thinking...",
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.sub,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Suggestion Chips (only when not loading and no error)
            if (!_loading && _messages.length == 1)
              Container(
                height: 40,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _buildSuggestionChip("What is this disease?"),
                    _buildSuggestionChip("How can I treat it?"),
                    _buildSuggestionChip("How to prevent it spreading?"),
                  ],
                ),
              ),

            // Input Box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.white,
                border: Border(
                  top: BorderSide(color: AppColors.border, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.bg,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.border),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _textController,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                        decoration: const InputDecoration(
                          hintText: 'Ask AI about this disease...',
                          border: InputBorder.none,
                          hintStyle: TextStyle(color: AppColors.sub, fontSize: 14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => _sendMessage(),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: AppColors.green,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
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

  Widget _buildSuggestionChip(String query) {
    return GestureDetector(
      onTap: () => _sendMessage(query),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.white,
          border: Border.all(color: AppColors.green.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Center(
          child: Text(
            query,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.green,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
