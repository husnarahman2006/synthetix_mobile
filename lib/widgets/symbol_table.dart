import 'package:flutter/material.dart';
import '../constants/synthetix_constants.dart';

class SymbolTableDrawer extends StatelessWidget {
  final Map<String, String> symbolTable;

  const SymbolTableDrawer({
    super.key,
    required this.symbolTable,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: SynthetixConstants.terminalBackground,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 10),
            color: Colors.grey.shade900,
            child: SafeArea(
              bottom: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.memory,
                        color: Colors.orangeAccent),
                    const SizedBox(width: 8),
                    const Text("Symbol Table",
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold)),
                  ]),
                  IconButton(
                    icon: const Icon(Icons.close,
                        color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          ),

          // Content
          Expanded(
            child: symbolTable.isEmpty
                ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.memory,
                      color: Colors.grey, size: 48),
                  SizedBox(height: 12),
                  Text("No memory state.",
                      style: TextStyle(
                          color: Colors.grey,
                          fontSize: 16)),
                  SizedBox(height: 4),
                  Text(
                    "Run code with 'set' to see variables.",
                    style: TextStyle(
                        color: Colors.white38,
                        fontSize: 12),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: symbolTable.entries
                  .where((e) => !e.key.startsWith('_'))
                  .length,
              itemBuilder: (context, index) {
                final filtered = symbolTable.entries
                    .where((e) => !e.key.startsWith('_'))
                    .toList();
                String key = filtered[index].key;
                String value = filtered[index].value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        const Icon(Icons.label_outline,
                            color: Colors.blueAccent,
                            size: 18),
                        const SizedBox(width: 8),
                        Text(key,
                            style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'monospace',
                                fontSize: 14)),
                      ]),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orangeAccent
                              .withAlpha(40),
                          borderRadius:
                          BorderRadius.circular(6),
                          border: Border.all(
                              color: Colors.orangeAccent
                                  .withAlpha(100)),
                        ),
                        child: Text(value,
                            style: const TextStyle(
                                color: Colors.orangeAccent,
                                fontFamily: 'monospace',
                                fontSize: 14)),
                      ),
                    ],
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