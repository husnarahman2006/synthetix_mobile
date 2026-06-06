import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // 🟢 ADDED: Need this to check who is logged in

class CloudTemplatesSheet extends StatelessWidget {
  final TextEditingController inputController;

  const CloudTemplatesSheet({
    super.key,
    required this.inputController,
  });

  // ☁️ Shifted: Hybrid data orchestration logic (KEPT EXACTLY AS YOU WROTE IT)
  Future<List<Map<String, dynamic>>> _fetchCloudTemplatesWithFallback() async {
    final List<Map<String, dynamic>> fallbackTemplates = [
      {
        "title": "Odd/Even Checker (Offline Mode)",
        "subtitle": "Built-in: Uses Switch-Case and Modulo",
        "code": "-- Synthetix Cloud Template: Odd/Even\nset num = 15\nset remainder = num % 2\n\nswitch remainder\n    case 0\n        show \"The number is Even.\"\n    case 1\n        show \"The number is Odd.\"\n    default\n        show \"Error\"\nend"
      },
      {
        "title": "Basic Calculator (Offline Mode)",
        "subtitle": "Built-in: Adds two numbers together",
        "code": "-- Synthetix Cloud Template: Calculator\nset a = 10\nset b = 25\nset result = a + b\n\nshow \"The result is:\"\nshow result"
      },
      {
        "title": "Repeat Loop Example (Offline Mode)",
        "subtitle": "Built-in: Prints a message 5 times",
        "code": "-- Synthetix Cloud Template: Loop\nset loops = 5\n\nrepeat loops times\n    show \"Hello from the Synthetix Loop!\"\nend"
      }
    ];

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('synthetix_templates')
          .get()
          .timeout(const Duration(seconds: 3));

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.map((doc) => {
          "title": doc.data().containsKey('title') ? doc['title'] : 'Unknown Cloud Template',
          "subtitle": doc.data().containsKey('subtitle') ? doc['subtitle'] : '',
          "code": doc.data().containsKey('code') ? doc['code'] : '',
        }).toList();
      }
    } catch (e) {
      debugPrint("Firebase fetch failed or timed out. Falling back to built-in templates. Error: $e");
    }
    return fallbackTemplates;
  }

  // Helper method for loading code from the new "My Scripts" tab
  void _loadCode(BuildContext context, String code) {
    inputController.text = code;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Script Loaded Successfully!"),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🟢 ADDED: Get the currently logged-in user
    final user = FirebaseAuth.instance.currentUser;

    return DefaultTabController(
      length: 2,
      child: SizedBox(
        height: MediaQuery.of(context).size.height,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.cloud_download, color: Colors.blueAccent),
                      SizedBox(width: 8),
                      Text(
                        "Cloud Storage",
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              const TabBar(
                indicatorColor: Colors.orangeAccent,
                labelColor: Colors.orangeAccent,
                unselectedLabelColor: Colors.white54,
                tabs: [
                  Tab(icon: Icon(Icons.library_books), text: "Templates"),
                  Tab(icon: Icon(Icons.folder_special), text: "My Scripts"),
                ],
              ),
              const SizedBox(height: 16),

              Expanded(
                child: TabBarView(
                  children: [
                    // --- TAB 1: TEMPLATES ---
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: _fetchCloudTemplatesWithFallback(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator(color: Colors.orangeAccent));
                        }

                        final templates = snapshot.data ?? [];

                        return ListView.builder(
                          itemCount: templates.length,
                          itemBuilder: (context, index) {
                            final template = templates[index];
                            return Card(
                              color: Colors.grey.shade900,
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: Icon(
                                  template["title"].toString().contains("Offline") ? Icons.save : Icons.cloud,
                                  color: Colors.orangeAccent,
                                ),
                                title: Text(template["title"]!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                subtitle: Text(template["subtitle"]!, style: const TextStyle(color: Colors.white54)),
                                onTap: () {
                                  inputController.text = template["code"]!;
                                  Navigator.pop(context);

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("Template Loaded!"),
                                      backgroundColor: Colors.green,
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        );
                      },
                    ),

                    // --- TAB 2: MY SCRIPTS (PRIVATE) ---
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('user_scripts')
                          .where('userId', isEqualTo: user?.uid) // 🟢 ADDED: Only fetch scripts owned by this user
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator(color: Colors.orangeAccent));
                        }

                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const Center(
                            child: Text(
                              "You haven't saved any scripts yet!\nUse the Cloud upload button to save.",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white54),
                            ),
                          );
                        }

                        final scripts = snapshot.data!.docs;

                        return ListView.builder(
                          itemCount: scripts.length,
                          itemBuilder: (context, index) {
                            final doc = scripts[index];
                            final data = doc.data() as Map<String, dynamic>;
                            final code = data['code'] ?? '';
                            final title = data['title'] ?? 'My Synthetix Script';

                            String timeString = "Recently";
                            if (data['timestamp'] != null) {
                              DateTime date = (data['timestamp'] as Timestamp).toDate();
                              timeString = "${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
                            }

                            return Card(
                              color: Colors.deepPurple.shade900.withAlpha(150),
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: const Icon(Icons.code, color: Colors.orangeAccent),
                                title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                subtitle: Text("Saved: $timeString\nLines: ${code.split('\n').length}", style: const TextStyle(color: Colors.white54)),
                                isThreeLine: true,
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                  onPressed: () {
                                    FirebaseFirestore.instance.collection('user_scripts').doc(doc.id).delete();
                                  },
                                ),
                                onTap: () => _loadCode(context, code),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}