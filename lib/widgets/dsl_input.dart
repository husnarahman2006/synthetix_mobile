import 'package:flutter/material.dart';
import '../constants/synthetix_constants.dart';

class DslInputWidget extends StatelessWidget {
  final TextEditingController controller;

  const DslInputWidget({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text("Write your DSL intent:",
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'e.g.,\nshow "Hello World!"\nset age to 21',
            filled: true,
            fillColor: SynthetixConstants.backgroundColor,
          ),
        ),
      ],
    );
  }
}