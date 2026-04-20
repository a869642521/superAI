import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:starpath/core/theme.dart';

/// 伙伴气泡内 Markdown（浅色文字，适配紫底气泡）
class ChatAssistantMarkdown extends StatelessWidget {
  final String data;
  final Color textColor;

  const ChatAssistantMarkdown({
    super.key,
    required this.data,
    this.textColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      color: textColor,
      fontSize: 15,
      height: 1.6,
      fontFamilyFallback: StarpathTheme.emojiFontFallback,
    );
    final dim = textColor.withValues(alpha: 0.85);

    return MarkdownBody(
      data: data,
      shrinkWrap: true,
      selectable: true,
      styleSheet: MarkdownStyleSheet(
        p: base,
        h1: base.copyWith(fontSize: 20, fontWeight: FontWeight.w800),
        h2: base.copyWith(fontSize: 18, fontWeight: FontWeight.w800),
        h3: base.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
        h4: base.copyWith(fontSize: 15, fontWeight: FontWeight.w700),
        listBullet: base,
        listIndent: 20,
        blockquote: base.copyWith(color: dim, fontStyle: FontStyle.italic),
        blockquoteDecoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border(
            left: BorderSide(color: textColor.withValues(alpha: 0.45), width: 3),
          ),
        ),
        code: base.copyWith(
          backgroundColor: Colors.black.withValues(alpha: 0.25),
          fontFamily: 'monospace',
          fontFamilyFallback: StarpathTheme.emojiFontFallback,
          fontSize: 13,
        ),
        codeblockDecoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(8),
        ),
        codeblockPadding: const EdgeInsets.all(10),
        horizontalRuleDecoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: textColor.withValues(alpha: 0.25)),
          ),
        ),
        a: base.copyWith(
          color: const Color(0xFF9EC5FF),
          decoration: TextDecoration.underline,
        ),
        tableHead: base.copyWith(fontWeight: FontWeight.w700),
        tableBody: base,
        tableBorder: TableBorder.all(
          color: textColor.withValues(alpha: 0.2),
          width: 0.6,
        ),
      ),
    );
  }
}
