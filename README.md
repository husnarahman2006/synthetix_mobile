#  Synthetix Mobile

> **A Hybrid Architecture for Custom DSL Compilation & Intelligent Code Synthesis**

Synthetix Mobile is a cross-platform Integrated Development Environment (IDE) built for Android. It bridges the gap between natural language processing and low-level code execution. By leveraging cloud-based Generative AI and a Native C++ compiler engine, Synthetix empowers absolute beginners to write, synthesize, and execute structured logic entirely on their mobile devices.

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![C++](https://img.shields.io/badge/C++-00599C?style=for-the-badge&logo=c%2B%2B&logoColor=white)
![TensorFlow Lite](https://img.shields.io/badge/TensorFlow_Lite-FF6F00?style=for-the-badge&logo=tensorflow&logoColor=white)
![Gemini AI](https://img.shields.io/badge/Gemini_AI-8E75B2?style=for-the-badge&logo=googlebard&logoColor=white)

---

## Architecture Overview

Synthetix is not a standard mobile application; it is a full language processing pipeline deployed on edge hardware, utilizing a 4-pillar hybrid architecture:

1. **Mobile Application Development (MAD):** A high-performance, responsive Flutter UI featuring a custom 2D visual scrollbar architecture and a Dracula-inspired high-contrast coding environment.
2. **Compiler Construction (CC):** A Native C++ transpiler linked via Dart Foreign Function Interface (FFI). It handles high-speed lexical scanning and syntax validation, achieving **10x faster parsing** than standard Dart execution.
3. **Machine Learning (ML):** A 100% On-Device TensorFlow Lite (`.tflite`) model that analyzes programmer behavior and code complexity to provide real-time skill classification (Beginner, Intermediate, Advanced) with zero server latency.
4. **Human-Computer Interaction (HCI):** Interface heavily grounded in Nielsen’s Heuristics, featuring a live Symbol Table for system observability and a sandboxed Execution Console.

---

##  Core Features

* **Prompt-to-Code Synthesis:** Integrates Google's Gemini 2.5 API to translate natural language user intent into structured Synthetix Domain-Specific Language (DSL).
* **Native C++ Engine Bridge:** Uses memory-safe Dart FFI to pass string pointers directly to a C++ shared library for binary-level syntax checking.
* **Real-time Symbol Table:** A live dictionary state manager that allows users to track variable mutations directly in the active memory environment.
* **On-Device Skill Analytics:** Neural network classification running locally on the device to ensure strict user data privacy.
* **Graceful Degradation:** Built-in local `SharedPreferences` caching to ensure the app remains functional even when offline.

---

##  Project Structure

The repository is organized to separate the UI layer from the native compiler engine:

```text
synthetix_mobile/
├── android/app/src/main/cpp/   #  Native Core: parser.cpp and C++ FFI bindings
├── assets/                     #  ML Core: synthetix_ml.tflite model
├── lib/
│   ├── main.dart               #  Entry point and initialization
│   ├── screens/                #  Main Workspace and IDE layout
│   ├── widgets/                #  Custom UI components (SymbolTable, ExecutionConsole)
│   └── constants/              #  Dracula theme definitions and FFI pointers
└── pubspec.yaml                #  Flutter & Package dependencies




