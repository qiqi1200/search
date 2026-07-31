import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/ai_provider.dart';

/// AI API 配置弹窗（聊天页与设置页共用）
class AIConfigSheet extends StatefulWidget {
  const AIConfigSheet({super.key});

  @override
  State<AIConfigSheet> createState() => _AIConfigSheetState();
}

class _AIConfigSheetState extends State<AIConfigSheet> {
  final _keyController = TextEditingController();
  final _urlController = TextEditingController(
    text: 'https://api.openai.com/v1/chat/completions',
  );
  final _modelController = TextEditingController(text: 'gpt-3.5-turbo');

  @override
  void initState() {
    super.initState();
    final ai = context.read<AIProvider>();
    // 不预填 API Key（安全）
    _urlController.text = ai.apiUrl;
    _modelController.text = ai.model;
  }

  @override
  void dispose() {
    _keyController.dispose();
    _urlController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text('配置 AI API', style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            TextField(
              controller: _keyController,
              decoration: const InputDecoration(
                labelText: 'API Key',
                hintText: 'sk-...',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'API 地址',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _modelController,
              decoration: const InputDecoration(
                labelText: '模型名称',
                hintText: 'gpt-3.5-turbo, deepseek-chat, etc.',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  if (_keyController.text.trim().isEmpty) return;
                  context.read<AIProvider>().configure(
                        apiKey: _keyController.text.trim(),
                        apiUrl: _urlController.text.trim(),
                        model: _modelController.text.trim(),
                      );
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('API 配置已保存')),
                  );
                },
                child: const Text('保存配置'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
