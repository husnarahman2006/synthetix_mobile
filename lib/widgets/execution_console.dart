import 'package:flutter/material.dart';
import '../constants/synthetix_constants.dart';

class ExecutionConsoleSheet extends StatelessWidget {
  final String executionOutput;
  final ScrollController consoleScrollController;
  final ScrollController outHorizontalScrollController;
  final Function(String, String) onCopy; // Callback for the clipboard utility

  const ExecutionConsoleSheet({
    super.key,
    required this.executionOutput,
    required this.consoleScrollController,
    required this.outHorizontalScrollController,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.4,
      minChildSize: 0.2,
      maxChildSize: 0.95, // Allows the user to pull it up full screen if needed!
      builder: (context, sheetScrollController) => Container(
        decoration: const BoxDecoration(
          color: SynthetixConstants.terminalBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Console Header Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.terminal, color: Colors.greenAccent),
                      const SizedBox(width: 8),
                      const Text(
                        "Execution Console",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.copy, color: Colors.white),
                        tooltip: "Copy Console Output",
                        onPressed: () => onCopy(executionOutput, "Console Output copied!"),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Console Terminal Output Text
            Expanded(
              child: Scrollbar(
                controller: consoleScrollController,
                thumbVisibility: true,
                child: Scrollbar(
                  controller: outHorizontalScrollController,
                  notificationPredicate: (notif) => notif.depth == 1,
                  child: SingleChildScrollView(
                    controller: consoleScrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: SingleChildScrollView(
                      controller: outHorizontalScrollController,
                      scrollDirection: Axis.horizontal,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          executionOutput,
                          style: SynthetixConstants.terminalTextStyle,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}