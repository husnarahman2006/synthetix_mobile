import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../constants/synthetix_constants.dart';
import '../widgets/command_menu.dart';
import '../widgets/dsl_input.dart';
import '../widgets/code_output.dart';
import '../widgets/symbol_table.dart';
import '../widgets/cloud_template.dart';
import '../widgets/execution_console.dart';

final DynamicLibrary nativeCompilerLib = DynamicLibrary.open('libcompiler_core.so');

typedef CompileC = Pointer<Utf8> Function(Pointer<Utf8>);
typedef CompileDart = Pointer<Utf8> Function(Pointer<Utf8>);
final CompileDart compileDsl = nativeCompilerLib
    .lookup<NativeFunction<CompileC>>('compile_dsl_to_python')
    .asFunction();

typedef FreeStringC = Void Function(Pointer<Utf8>);
typedef FreeStringDart = void Function(Pointer<Utf8>);
final FreeStringDart freeString = nativeCompilerLib
    .lookup<NativeFunction<FreeStringC>>('free_string')
    .asFunction();

class CompilerScreen extends StatefulWidget {
  const CompilerScreen({super.key});

  @override
  State<CompilerScreen> createState() => _CompilerScreenState();
}

class _CompilerScreenState extends State<CompilerScreen> {
  final TextEditingController _inputController = TextEditingController();
  final TextEditingController _promptController = TextEditingController();

  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _outHorizontalScrollController = ScrollController();
  final ScrollController _consoleScrollController = ScrollController();

  String _generatedCode = "# Python code will appear here";
  String _executionOutput = "Console output will appear here";
  String _generatedPython = "";
  Map<String, String> _symbolTable = {};
  List<String> _snippetHistory = [];

  bool _isTranslating = false;
  String _userApiKey = "";

  @override
  void initState() {
    super.initState();
    _loadApiKey();
  }

  Future<void> _loadApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        // Load the key SPECIFIC to the currently logged-in user
        _userApiKey = prefs.getString('gemini_api_key_${user.uid}') ?? "";
      });
    }
  }

  Future<void> _saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Save the key tied permanently to this user's ID
      await prefs.setString('gemini_api_key_${user.uid}', key);
      setState(() {
        _userApiKey = key;
      });
    }
  }

  Future<void> _saveScriptToCloud() async {
    final String currentCode = _inputController.text.trim();
    final user = FirebaseAuth.instance.currentUser; // 🟢 Get current user

    if (currentCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Cannot save an empty script!"),
            backgroundColor: Colors.orange),
      );
      return;
    }

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error: You must be logged in to save."),
            backgroundColor: Colors.redAccent),
      );
      return;
    }

    try {
      // 🟢 Add the 'userId' field so Firebase knows who owns this code
      await FirebaseFirestore.instance.collection('user_scripts').add({
        'userId': user.uid,
        'userEmail': user.email, // Optional, helpful for debugging
        'title': 'My Synthetix Script',
        'code': currentCode,
        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Script saved privately to your Cloud! ☁️"),
            backgroundColor: Colors.green),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to save: $error"),
            backgroundColor: Colors.redAccent),
      );
    }
  }

  void _showSettingsDialog() {
    final TextEditingController keyController = TextEditingController(
        text: _userApiKey);

    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            backgroundColor: SynthetixConstants.terminalBackground,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.settings, color: Colors.blueAccent),
                SizedBox(width: 8),
                Text("API Settings", style: TextStyle(color: Colors.white)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Enter your free Gemini API Key to enable the 'Prompt-to-Code' feature.",
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: keyController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Paste API Key here...",
                    hintStyle: const TextStyle(color: Colors.white30),
                    filled: true,
                    fillColor: Colors.grey.shade900,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                    "Cancel", style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: SynthetixConstants.primaryColor),
                onPressed: () {
                  _saveApiKey(keyController.text.trim());
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("API Key Saved Successfully!"),
                        backgroundColor: Colors.green),
                  );
                },
                child: const Text(
                    "Save Key", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
    );
  }

// ml part gemini
  Future<void> _generateCodeFromPrompt() async {
    final promptText = _promptController.text.trim();
    if (promptText.isEmpty) return;

    if (_userApiKey.isEmpty) {
      _showSettingsDialog();
      return;
    }

    setState(() {
      _isTranslating = true;
      _inputController.text =
      "-- AI is generating Synthetix code...\n-- Please wait...";
    });

    try {
      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: _userApiKey,
      );

      final hiddenInstructions = '''
        You are a code translator for the 'Synthetix' language.
        Translate the user's natural language request into Synthetix DSL.
        RULES:
        1. Variable assignment uses 'set var = value'
        2. Printing uses 'show "text"' or 'show var'
        3. If/Else uses 'if condition', 'else', and 'end'
        4. Loops use 'repeat X times' and 'end'
        5. Comments use '--'
        6. Math operations support +, -, *, /, and % (modulo)
        7. Relational operators support ==, !=, >, <, >=, and <=
        8. Switch-case uses 'switch var', 'case value', 'default', and 'end'
        9. Functions use 'function functionName', end with 'end', and are called by typing the function name.
        ONLY output the raw Synthetix code. Do not use markdown formatting like ```text. Do not explain the code.
      ''';

      final fullPrompt = '$hiddenInstructions\n\nUSER REQUEST: $promptText';
      final response = await model.generateContent([Content.text(fullPrompt)]);

      setState(() {
        _inputController.text =
            response.text?.trim() ?? "-- Error generating code.";
      });
    } catch (e) {
      setState(() {
        _inputController.text = "-- AI Translation failed.\n-- Error: $e";
      });
    } finally {
      setState(() {
        _isTranslating = false;
      });
    }
  }

  void _compileCode() {
    final String userInput = _inputController.text;
    if (userInput.isEmpty) return;

    final inputPointer = userInput.toNativeUtf8();
    final resultPointer = compileDsl(inputPointer);

    setState(() {
      _generatedPython = resultPointer.toDartString();
      _generatedCode = _generatedPython;
      _executionOutput = "Code compiled successfully!";

      if (_generatedPython.isNotEmpty &&
          !_generatedPython.contains("# Waiting for input")) {
        _snippetHistory.insert(0, _generatedPython);
      }
    });

    freeString(resultPointer);
    malloc.free(inputPointer);
  }

// ml part of tensorflow
  Future<String> _predictProgrammerSkill(String code,
      Map<String, String> variables) async {
    try {
      int linesOfCode = code
          .split('\n')
          .length;
      int numVariables = variables.length;
      double hasLoop = code.contains("repeat") ? 1.0 : 0.0;
      double hasSwitch = code.contains("switch") ? 1.0 : 0.0;

      if (linesOfCode <= 2 && numVariables == 0 && hasLoop == 0.0 &&
          hasSwitch == 0.0) {
        return "Beginner Programmer";
      }

      final interpreter = await Interpreter.fromAsset(
          'assets/synthetix_ml.tflite');

      var input = [
        [linesOfCode.toDouble(), numVariables.toDouble(), hasLoop, hasSwitch]
      ];
      var output = List.filled(1 * 3, 0.0).reshape([1, 3]);

      interpreter.run(input, output);
      interpreter.close();

      List<double> probabilities = (output[0] as List).cast<double>();
      int highestIndex = 0;
      for (int i = 0; i < probabilities.length; i++) {
        if (probabilities[i] > probabilities[highestIndex]) {
          highestIndex = i;
        }
      }

      if (highestIndex == 0) return "Beginner Programmer";
      if (highestIndex == 1) return "Intermediate Programmer";
      return "Advanced Programmer";
    } catch (e) {
      debugPrint("ML Error: $e");
      return "Skill Analysis Unavailable";
    }
  }

  String _removeQuotes(String str) {
    return str.replaceAll('"', '').replaceAll("'", "");
  }

  void _copyToClipboard(String text, String successMessage) {
    if (text.isEmpty || text == "Console output will appear here") return;
    Clipboard.setData(ClipboardData(text: text)).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMessage),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    });
  }

  Future<void> _runPython() async {
    if (_generatedPython.isEmpty) {
      setState(() => _executionOutput = "Compile first!");
      _showConsole();
      return;
    }

    String output = "";
    Map<String, String> variables = {};
    Map<String, List<String>> customFunctions = {};
    List<String> lines = _generatedPython.split('\n');

    bool skipBlock = false;
    int targetIndent = 0;
    bool lastIfConditionMet = false;
    bool switchCaseHandled = false;

    for (int i = 0; i < lines.length; i++) {
      String rawLine = lines[i];
      if (rawLine
          .trim()
          .isEmpty) continue;

      if (rawLine.contains('#')) {
        rawLine = rawLine.substring(0, rawLine.indexOf('#'));
      }

      int currentIndent = rawLine.length - rawLine
          .trimLeft()
          .length;
      String line = rawLine.trim();
      if (line.isEmpty) continue;

      if (skipBlock && currentIndent > targetIndent) {
        continue;
      } else if (skipBlock && currentIndent <= targetIndent) {
        skipBlock = false;
      }

      if (line.startsWith("def ")) {
        String funcName = line.substring(4, line.indexOf("(")).trim();
        List<String> funcBody = [];

        int j = i + 1;
        while (j < lines.length) {
          if (lines[j]
              .trim()
              .isEmpty) {
            j++;
            continue;
          }
          int nextIndent = lines[j].length - lines[j]
              .trimLeft()
              .length;
          if (nextIndent <= currentIndent) break;
          funcBody.add(lines[j]);
          j++;
        }
        customFunctions[funcName] = funcBody;
        i = j - 1;
        continue;
      }

      else if (customFunctions.containsKey(line.replaceAll("()", "").trim())) {
        String calledFuncName = line.replaceAll("()", "").trim();
        List<String> bodyToRun = customFunctions[calledFuncName]!;
        output += _executeBlock(bodyToRun, variables);
      }

      else if (line.contains(" = ") && !line.startsWith("if ") &&
          !line.startsWith("for ")) {
        List<String> parts = line.split(" = ");
        String varName = parts[0].trim();
        String expression = parts[1].trim();

        if (varName == "_switch_val") switchCaseHandled = false;

        if (expression.startsWith('"') || expression.startsWith("'")) {
          variables[varName] = _removeQuotes(expression);
        } else if (RegExp(r'[+\-*/%]').hasMatch(expression)) {
          double result = _evaluateArithmetic(expression, variables);
          variables[varName] =
              result.toString().replaceAll(RegExp(r'\.0$'), '');
        } else {
          variables[varName] =
              variables[expression] ?? _removeQuotes(expression);
        }
      }

      else if (line.startsWith("for _ in range(")) {
        String countStr = line.substring(
            line.indexOf("(") + 1, line.indexOf(")"));
        int count = int.tryParse(variables[countStr] ?? countStr) ?? 0;
        List<String> loopLines = [];
        int j = i + 1;
        while (j < lines.length) {
          int nextIndent = lines[j].length - lines[j]
              .trimLeft()
              .length;
          if (lines[j]
              .trim()
              .isEmpty) {
            j++;
            continue;
          }
          if (nextIndent <= currentIndent) break;
          loopLines.add(lines[j]);
          j++;
        }
        for (int k = 0; k < count; k++) {
          output += _executeBlock(loopLines, variables);
        }
        i = j - 1;
      }

      else if (line.startsWith("if _switch_val == ") ||
          line.startsWith("elif _switch_val == ")) {
        String condition = line
            .replaceAll("elif ", "")
            .replaceAll("if ", "")
            .replaceAll(":", "")
            .trim();
        bool conditionMet = _evaluateCondition(condition, variables);

        if (conditionMet && !switchCaseHandled) {
          lastIfConditionMet = true;
          switchCaseHandled = true;
          skipBlock = false;
        } else {
          lastIfConditionMet = false;
          skipBlock = true;
          targetIndent = currentIndent;
        }
      }

      else if (line.startsWith("if ")) {
        String condition = line
            .replaceAll("if ", "")
            .replaceAll(":", "")
            .trim();
        lastIfConditionMet = _evaluateCondition(condition, variables);

        if (!lastIfConditionMet) {
          skipBlock = true;
          targetIndent = currentIndent;
        }
      }
      else if (line == "else:") {
        if (lastIfConditionMet || switchCaseHandled) {
          skipBlock = true;
          targetIndent = currentIndent;
        } else {
          skipBlock = false;
        }
      }

      else if (line.startsWith("print(")) {
        String content = line.substring(6, line.length - 1).trim();
        if (content.startsWith('"') || content.startsWith("'")) {
          output += "${_removeQuotes(content)}\n";
        }

        else {
          String val = variables[content] ?? content;
          output += "$val\n";
        }
      }
    }

    String skillLevel = await _predictProgrammerSkill(
        _inputController.text, variables);
    String finalConsoleOutput = output.isEmpty
        ? "Code ran successfully."
        : output;
    finalConsoleOutput +=
    "\n\n=== ML CODE ANALYSIS ===\nPredicted User Skill: $skillLevel";

    setState(() {
      _executionOutput = finalConsoleOutput;
      _symbolTable = variables;
    });

    _showConsole();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_consoleScrollController.hasClients) {
        _consoleScrollController.animateTo(
          _consoleScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  double _evaluateArithmetic(String expression, Map<String, String> variables) {
    String parsedExpr = expression;
    variables.forEach((key, value) =>
    parsedExpr = parsedExpr.replaceAll(RegExp('\\b$key\\b'), value));

    try {
      final tokens = parsedExpr.split(RegExp(r'(?<=[+\-*/%])|(?=[+\-*/%])'));
      List<double> nums = [];
      List<String> ops = [];

      for (var t in tokens) {
        String trimmed = t.trim();
        if (trimmed.isEmpty) continue;

        if (RegExp(r'[+\-*/%]').hasMatch(trimmed)) {
          ops.add(trimmed);
        } else {
          nums.add(double.tryParse(trimmed) ?? 0.0);
        }
      }

      for (int i = 0; i < ops.length; i++) {
        if (ops[i] == '*' || ops[i] == '/' || ops[i] == '%') {
          double res;
          if (ops[i] == '*') {
            res = nums[i] * nums[i + 1];
          } else if (ops[i] == '/') {
            res = nums[i] / nums[i + 1];
          } else {
            res = nums[i] % nums[i + 1];
          }

          nums[i] = res;
          nums.removeAt(i + 1);
          ops.removeAt(i);
          i--;
        }
      }

      double res = nums[0];
      for (int i = 0; i < ops.length; i++) {
        if (ops[i] == '+') res += nums[i + 1];
        if (ops[i] == '-') res -= nums[i + 1];
      }

      return res;
    } catch (e) {
      return 0.0;
    }
  }

  bool _evaluateCondition(String condition, Map<String, String> variables) {
    String op = "";
    if (condition.contains("==")) {
      op = "==";
    }
    else if (condition.contains("!=")) {
      op = "!=";
    }
    else if (condition.contains(">=")) {
      op = ">=";
    }
    else if (condition.contains("<=")) {
      op = "<=";
    }
    else if (condition.contains(">")) {
      op = ">";
    }
    else if (condition.contains("<")) {
      op = "<";
    }

    if (op.isEmpty) return false;

    var parts = condition.split(op);
    String leftSide = parts[0].trim();
    double v2 = double.tryParse(parts[1].trim()) ?? 0;

    double v1;
    if (leftSide.contains("%")) {
      var modParts = leftSide.split("%");
      double dividend = double.tryParse(
          variables[modParts[0].trim()] ?? modParts[0].trim()) ?? 0;
      double divisor = double.tryParse(
          variables[modParts[1].trim()] ?? modParts[1].trim()) ?? 1;
      v1 = dividend % divisor;
    } else {
      v1 = double.tryParse(variables[leftSide] ?? leftSide) ?? 0;
    }

    switch (op) {
      case "==":
        return v1 == v2;
      case "!=":
        return v1 != v2;
      case ">=":
        return v1 >= v2;
      case "<=":
        return v1 <= v2;
      case ">":
        return v1 > v2;
      case "<":
        return v1 < v2;
      default:
        return false;
    }
  }

  String _executeBlock(List<String> blockLines, Map<String, String> variables) {
    String blockOutput = "";
    for (String line in blockLines) {
      String t = line.trim();
      if (t.isEmpty) continue;

      if (t.contains(" = ") && !t.startsWith("if ") && !t.startsWith("for ")) {
        List<String> parts = t.split(" = ");
        String varName = parts[0].trim();
        String expression = parts[1].trim();

        if (expression.startsWith('"') || expression.startsWith("'")) {
          variables[varName] = _removeQuotes(expression);
        } else if (RegExp(r'[+\-*/%]').hasMatch(expression)) {
          double result = _evaluateArithmetic(expression, variables);
          variables[varName] =
              result.toString().replaceAll(RegExp(r'\.0$'), '');
        } else {
          String lookupKey = expression.trim();
          variables[varName] =
              variables[lookupKey] ?? _removeQuotes(expression);
        }
      }
      else if (t.startsWith("print(")) {
        String content = t.substring(6, t.length - 1).trim();

        if (content.startsWith('"') || content.startsWith("'")) {
          blockOutput += "${_removeQuotes(content)}\n";
        } else {
          String lookupKey = content.trim();
          String val = variables[lookupKey] ?? lookupKey;
          blockOutput += "$val\n";
        }
      }
    }
    return blockOutput;
  }

  void _showConsole() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          ExecutionConsoleSheet(
            executionOutput: _executionOutput,
            consoleScrollController: _consoleScrollController,
            outHorizontalScrollController: _outHorizontalScrollController,
            onCopy: _copyToClipboard,
          ),
    );
  }

  void _showCloudTemplates() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: SynthetixConstants.terminalBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) =>
          CloudTemplatesSheet(inputController: _inputController),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get the current user to display their email in the dashboard
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Synthetix Compiler',
            style: TextStyle(color: Colors.white, fontSize: 18)),
        backgroundColor: SynthetixConstants.primaryColor,
        elevation: 0,
        // 🟢 HCI FIX: Drastically cleaned up the top bar! Only the most important actions stay here.
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_upload, color: Colors.white),
            tooltip: "Save Script",
            onPressed: _saveScriptToCloud,
          ),
          IconButton(
            icon: const Icon(Icons.terminal, color: Colors.white),
            tooltip: "Execution Console",
            onPressed: _showConsole,
          ),
        ],
      ),

      // 🟢 THE NEW PROFESSIONAL DASHBOARD
      drawer: Drawer(
        backgroundColor: SynthetixConstants.terminalBackground,
        child: Column(
          children: [
            // The beautiful user profile header
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(
                  color: SynthetixConstants.primaryColor),
              accountName: const Text(
                  "Synthetix Developer",
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.white)
              ),
              accountEmail: Text(
                  user?.email ?? "Not logged in",
                  style: const TextStyle(color: Colors.white70)
              ),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Text(
                  user?.email?.substring(0, 1).toUpperCase() ?? "S",
                  style: const TextStyle(color: SynthetixConstants.primaryColor,
                      fontSize: 28,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),

            // The consolidated menu options
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  ListTile(
                    leading: const Icon(
                        Icons.cloud_download, color: Colors.blueAccent),
                    title: const Text(
                        "Cloud Storage", style: TextStyle(color: Colors.white)),
                    subtitle: const Text("Templates & My Scripts",
                        style: TextStyle(color: Colors.white54, fontSize: 12)),
                    onTap: () {
                      Navigator.pop(context); // Close the drawer first
                      _showCloudTemplates();
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                        Icons.history, color: Colors.orangeAccent),
                    title: const Text("Session History",
                        style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(context);
                      // Pops up your existing history widget smoothly from the bottom!
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: SynthetixConstants.terminalBackground,
                        builder: (context) =>
                            CommandMenuWidget(snippetHistory: _snippetHistory),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                        Icons.storage, color: Colors.greenAccent),
                    title: const Text(
                        "Symbol Table", style: TextStyle(color: Colors.white)),
                    subtitle: const Text("Live Variables",
                        style: TextStyle(color: Colors.white54, fontSize: 12)),
                    onTap: () {
                      Navigator.pop(context);
                      // Pops up your existing symbol table smoothly from the bottom!
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: SynthetixConstants.terminalBackground,
                        builder: (context) =>
                            SymbolTableDrawer(symbolTable: _symbolTable),
                      );
                    },
                  ),
                  const Divider(color: Colors.white24),
                  ListTile(
                    leading: const Icon(Icons.settings, color: Colors.grey),
                    title: const Text(
                        "API Settings", style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(context);
                      _showSettingsDialog();
                    },
                  ),
                ],
              ),
            ),

            // The secure Sign Out footer
            const Divider(color: Colors.white24, height: 1),
            ListTile(
              leading: const Icon(
                  Icons.logout_rounded, color: Colors.redAccent),
              title: const Text("Sign Out", style: TextStyle(
                  color: Colors.redAccent, fontWeight: FontWeight.bold)),
              onTap: () async {
                Navigator.pop(context);
                await FirebaseAuth.instance.signOut();
              },
            ),
            const SizedBox(height: 16), // Padding for the bottom of the screen
          ],
        ),
      ),

      // We removed the 'endDrawer' since everything is unified now!

      // Your CustomScrollView layout remains completely untouched below:
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(
                    left: 16.0, right: 16.0, top: 16.0, bottom: 6.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: SynthetixConstants
                            .primaryColor.withAlpha(128)),
                      ),
                      child: Row(
                        children: [
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12.0),
                            child: Icon(Icons.auto_awesome,
                                color: SynthetixConstants.primaryColor),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _promptController,
                              decoration: const InputDecoration(
                                hintText: "E.g., Calculate my age in seconds if I am 21",
                                border: InputBorder.none,
                                hintStyle: TextStyle(
                                    color: Colors.grey, fontSize: 14),
                              ),
                              style: const TextStyle(color: Colors.black87),
                              onSubmitted: (_) => _generateCodeFromPrompt(),
                            ),
                          ),
                          _isTranslating
                              ? const Padding(
                            padding: EdgeInsets.all(14.0),
                            child: SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2,
                                    color: SynthetixConstants.primaryColor)
                            ),
                          )
                              : IconButton(
                            icon: const Icon(Icons.send,
                                color: SynthetixConstants.primaryColor),
                            onPressed: _generateCodeFromPrompt,
                            tooltip: "Generate Code",
                          ),
                        ],
                      ),
                    ),

                    DslInputWidget(controller: _inputController),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: ElevatedButton.icon(
                            onPressed: _compileCode,
                            icon: const Icon(Icons.memory),
                            label: const Text("Compile"),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: SynthetixConstants
                                    .primaryColor,
                                foregroundColor: Colors.white))),
                        const SizedBox(width: 12),
                        Expanded(child: ElevatedButton.icon(
                            onPressed: _runPython,
                            icon: const Icon(Icons.play_arrow),
                            label: const Text("Run"),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white))),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text("Generated Python Code:",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),

            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.only(
                    left: 16.0, right: 16.0, bottom: 16.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 150),
                  child: CodeOutputWidget(
                    generatedCode: _generatedCode,
                    verticalController: _verticalScrollController,
                    horizontalController: _horizontalScrollController,
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
