import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/synthetix_constants.dart';

class CommandMenuWidget extends StatelessWidget {
  final List<String> snippetHistory;

  const CommandMenuWidget({super.key, required this.snippetHistory});

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text)).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Snippet copied!"), backgroundColor: Colors.green, duration: Duration(seconds: 2)),
      );
    }).catchError((e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Clipboard access denied."), backgroundColor: Colors.redAccent),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF282C34),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header perfectly matched to main Compiler App Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: SynthetixConstants.primaryColor,
            child: SafeArea(
              bottom: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.history, color: Colors.white),
                      SizedBox(width: 8),
                      Text("Session History", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          ),

          Expanded(
            child: snippetHistory.isEmpty
                ? const Center(child: Text("No history available.", style: TextStyle(color: Colors.white)))
                : ListView.builder(
              padding: const EdgeInsets.all(12.0),
              itemCount: snippetHistory.length,
              itemBuilder: (context, index) {
                String snippet = snippetHistory[index];
                int snippetNumber = snippetHistory.length - index;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF3E4451),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF5C6370), width: 1.5),
                      boxShadow: [
                        // ✅ Replaced withAlpha for clean modern linter standards
                        BoxShadow(color: Colors.black.withAlpha(128), blurRadius: 8, offset: const Offset(0, 5)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.only(left: 12, right: 4, top: 6, bottom: 6),
                          decoration: const BoxDecoration(
                            color: Color(0xFF2C313C),
                            borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      // ✅ Replaced withAlpha for modern color tracking
                                      color: Colors.blueAccent.withAlpha(64),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.blueAccent.withAlpha(128)),
                                    ),
                                    child: Text("Run #$snippetNumber", style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 10),
                                  const Text("Python", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                                ],
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy_all, color: Colors.lightBlueAccent, size: 22),
                                tooltip: "Copy Snippet",
                                onPressed: () => _copyToClipboard(context, snippet),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          decoration: const BoxDecoration(
                            color: Color(0xFF1E2227),
                            borderRadius: BorderRadius.vertical(bottom: Radius.circular(11)),
                          ),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.all(14),
                            child: Text(
                              snippet,
                              style: TextStyle(
                                  color: Colors.blueGrey.shade50,
                                  fontFamily: 'monospace',
                                  fontSize: 14,
                                  height: 1.5
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}