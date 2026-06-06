#include <stdint.h>
#include <string.h>
#include <stdlib.h>
#include <string>
#include <sstream>
#include <map>

using namespace std;

map<string, double> variables;

string trim(const string& str) {
    size_t start = str.find_first_not_of(" \t\r\n");
    if (start == string::npos) return "";
    size_t end = str.find_last_not_of(" \t\r\n");
    return str.substr(start, end - start + 1);
}

bool isNumber(const string& s) {
    if (s.empty()) return false;
    bool hasDot = false;
    for (size_t i = 0; i < s.size(); i++) {
        if (s[i] == '.') {
            if (hasDot) return false;
            hasDot = true;
        } else if (!isdigit(s[i])) return false;
    }
    return true;
}

// Parses multiple math operations left-to-right correctly
string evaluateExpression(const string& expr) {
    string e = trim(expr);
    if (e.empty()) return "0";

    // If it's a simple string literal (starts with quotes), pass it right through
    if (e.front() == '"' || e.front() == '\'') return e;

    stringstream ss(e);
    string token;

    double total = 0.0;
    string currentOp = "+";

    while (ss >> token) {
        if (token == "+" || token == "-" || token == "*" || token == "/" || token == "%") {
            currentOp = token;
            continue;
        }

        double value = 0.0;
        if (variables.count(token)) {
            value = variables[token];
        } else {
            value = atof(token.c_str());
        }

        if (currentOp == "+") total += value;
        else if (currentOp == "-") total -= value;
        else if (currentOp == "*") total *= value;
        else if (currentOp == "/") {
            if (value != 0) total /= value;
        }
        else if (currentOp == "%") {
            if (value != 0) total = (int)total % (int)value;
        }
    }

    if (total == (int)total) {
        return to_string((int)total);
    }

    char buf[32];
    snprintf(buf, sizeof(buf), "%.2f", total);
    return string(buf);
}

extern "C" {

__attribute__((visibility("default"))) __attribute__((used))
const char* compile_dsl_to_python(const char* input_code) {
    variables.clear();
    string dsl(input_code);
    stringstream ss(dsl);
    string line;
    string python_code = "";
    int indent_level = 0;

    bool is_inside_case = false;
    bool is_inside_switch = false;
    string switch_var = "";

    while (getline(ss, line)) {
        line = trim(line);
        if (line.empty()) {
            python_code += "\n";
            continue;
        }

        // Handle END keyword
        if (line == "end") {
            if (indent_level > 0) indent_level--;
            if (indent_level == 0) {
                is_inside_case = false;
                is_inside_switch = false;
                switch_var = "";
            }
            continue;
        }

        string indent = string(indent_level * 4, ' ');

        // Extract inline comment
        string comment = "";
        size_t comment_pos = line.find("--");
        if (comment_pos != string::npos) {
            comment = "  # " + trim(line.substr(comment_pos + 2));
            line = trim(line.substr(0, comment_pos));
            if (line.empty()) {
                python_code += indent + "#" + comment + "\n";
                continue;
            }
        }

        // 1. COMMENT
        if (line.rfind("--", 0) == 0) {
            python_code += indent + "# " + trim(line.substr(2)) + "\n";
        }

            // 2. SET command
        else if (line.rfind("set ", 0) == 0) {
            string rest = line.substr(4);
            size_t eqPos = rest.find(" = ");
            size_t toPos = rest.find(" to ");

            string varName, valueExpr;
            if (eqPos != string::npos) {
                varName = trim(rest.substr(0, eqPos));
                valueExpr = trim(rest.substr(eqPos + 3));
            } else if (toPos != string::npos) {
                varName = trim(rest.substr(0, toPos));
                valueExpr = trim(rest.substr(toPos + 4));
            } else {
                python_code += indent + "# Error: Invalid set\n";
                continue;
            }

            // ✅ PURE DYNAMIC TRANSLATION
            // We no longer evaluate the math in C++. We pass the exact formula
            // directly to Python so the Flutter interpreter calculates it at runtime!
            python_code += indent + varName + " = " + valueExpr + comment + "\n";
        }

            // 3. SHOW command
        else if (line.rfind("show ", 0) == 0) {
            string content = trim(line.substr(5));

            // Just pass the raw variable name or string literal straight to Python!
            python_code += indent + "print(" + content + ")" + comment + "\n";
        }


            // 4. GREET command
        else if (line.rfind("greet ", 0) == 0) {
            string name = trim(line.substr(6));
            python_code += indent + "print(\"Hello, \" + str(" + name + ") + \"!\")" + comment + "\n";
        }

            // 5. IF command
        else if (line.rfind("if ", 0) == 0) {
            string condition = trim(line.substr(3));
            if (!condition.empty() && condition.back() == ':')
                condition.pop_back();
            python_code += indent + "if " + condition + ":" + comment + "\n";
            indent_level++;
        }

            // 6. ELSE command
        else if (line == "else" || line == "else:") {
            if (indent_level > 0) {
                string else_indent = string((indent_level - 1) * 4, ' ');
                python_code += else_indent + "else:" + comment + "\n";
            } else {
                python_code += "# Error: else without if\n";
            }
        }

            // 7. REPEAT command
        else if (line.rfind("repeat ", 0) == 0) {
            size_t timesPos = line.find(" times");
            if (timesPos != string::npos) {
                string count = trim(line.substr(7, timesPos - 7));
                python_code += indent + "for _ in range(" + count + "):" + comment + "\n";
                indent_level++;
            } else {
                python_code += indent + "# Error: Invalid repeat\n";
            }
        }

            // 8. SWITCH command
        else if (line.rfind("switch ", 0) == 0) {
            switch_var = trim(line.substr(7));
            is_inside_switch = true;
            is_inside_case = false;
            python_code += indent + "_switch_val = " + switch_var + comment + "\n";
        }

            // 9. CASE command
        else if (line.rfind("case ", 0) == 0) {
            string value = trim(line.substr(5));
            if (is_inside_case && indent_level > 0) {
                indent_level--;
                indent = string(indent_level * 4, ' ');
            }
            string keyword = is_inside_case ? "elif" : "if";
            python_code += indent + keyword + " _switch_val == " + value + ":" + comment + "\n";
            indent_level++;
            is_inside_case = true;
        }

            // 10. DEFAULT command
        else if (line == "default" || line == "default:") {
            if (is_inside_case && indent_level > 0) {
                indent_level--;
                indent = string(indent_level * 4, ' ');
            }
            python_code += indent + "else:" + comment + "\n";
            indent_level++;
            is_inside_case = false;
        }

            // 11. FUNCTION Definition command
        else if (line.rfind("function ", 0) == 0) {
            string funcName = trim(line.substr(9));
            python_code += indent + "def " + funcName + "():" + comment + "\n";
            indent_level++;
        }

            // 12. Direct Custom Function Calls or Unknown execution references
        else {
            if (line.find(' ') == string::npos && !line.empty() && line.find('(') == string::npos) {
                python_code += indent + line + "()" + comment + "\n";
            } else {
                python_code += indent + "# Unknown: " + line + "\n";
            }
        }
    }

    if (python_code.empty()) {
        python_code = "# Waiting for input...";
    }

    char* result = (char*)malloc(python_code.length() + 1);
    strcpy(result, python_code.c_str());
    return result;
}

__attribute__((visibility("default"))) __attribute__((used))
void free_string(char* str) {
    free(str);
}

}