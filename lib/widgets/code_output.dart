import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/dracula.dart';
import '../constants/synthetix_constants.dart';

class CodeOutputWidget extends StatelessWidget {
  final String generatedCode;
  final ScrollController verticalController;
  final ScrollController horizontalController;

  const CodeOutputWidget({
    super.key,
    required this.generatedCode,
    required this.verticalController,
    required this.horizontalController,
  });

  void _copyToClipboard(BuildContext context) {
    if (generatedCode.isEmpty || generatedCode == "# Python code will appear here") return;

    Clipboard.setData(ClipboardData(text: generatedCode)).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Python code copied to clipboard!"),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }).catchError((e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Clipboard access denied by system."),
          backgroundColor: Colors.redAccent,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // 🟢 FIXED: Removed the fixed height SizedBox.
    // 'StackFit.expand' forces the black box to stretch perfectly
    // into whatever space is given to it by the main screen!
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: BoxDecoration(
            color: SynthetixConstants.codeBackground,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Scrollbar(
            controller: verticalController,
            thumbVisibility: true,
            child: Scrollbar(
              controller: horizontalController,
              thumbVisibility: true,
              notificationPredicate: (notif) => notif.depth == 1,
              child: SingleChildScrollView(
                controller: verticalController,
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  controller: horizontalController,
                  scrollDirection: Axis.horizontal,
                  child: HighlightView(
                    generatedCode.isEmpty ? "# Python code will appear here" : generatedCode,
                    language: 'python',
                    theme: draculaTheme,
                    padding: const EdgeInsets.all(12),
                    textStyle: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        Positioned(
          top: 8,
          right: 8,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(128),
              borderRadius: BorderRadius.circular(4),
            ),
            child: IconButton(
              icon: const Icon(Icons.copy, color: Colors.white70, size: 20),
              tooltip: "Copy Python Code",
              onPressed: () => _copyToClipboard(context),
            ),
          ),
        ),
      ],
    );
  }
}