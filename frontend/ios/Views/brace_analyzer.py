#!/usr/bin/env python3
"""
Analyze Swift file for brace matching issues and improper struct nesting
"""

def analyze_braces(file_path):
    with open(file_path, 'r') as f:
        lines = f.readlines()
    
    brace_stack = []
    struct_locations = []
    issues = []
    
    for line_num, line in enumerate(lines, 1):
        stripped = line.strip()
        
        # Track struct definitions
        if stripped.startswith('struct ') and ':' in stripped and ' View' in stripped:
            struct_name = stripped.split(' ')[1].split(':')[0]
            struct_locations.append({
                'name': struct_name,
                'line': line_num,
                'nesting_level': len(brace_stack)
            })
            
            # Structs should only be at file scope (nesting level 0)
            if len(brace_stack) > 0:
                issues.append(f"Line {line_num}: Struct '{struct_name}' is nested inside another structure (nesting level: {len(brace_stack)})")
        
        # Also track non-View structs
        elif stripped.startswith('struct ') and ':' not in stripped and ' {' not in stripped:
            struct_name = stripped.split(' ')[1]
            struct_locations.append({
                'name': struct_name,
                'line': line_num,
                'nesting_level': len(brace_stack)
            })
            
            # Structs should only be at file scope (nesting level 0)
            if len(brace_stack) > 0:
                issues.append(f"Line {line_num}: Struct '{struct_name}' is nested inside another structure (nesting level: {len(brace_stack)})")
        
        # Count braces
        for char in line:
            if char == '{':
                brace_stack.append(line_num)
            elif char == '}':
                if brace_stack:
                    brace_stack.pop()
                else:
                    issues.append(f"Line {line_num}: Extra closing brace found")
    
    # Check for unclosed braces
    if brace_stack:
        issues.append(f"Unclosed opening braces at lines: {brace_stack}")
    
    return {
        'struct_locations': struct_locations,
        'issues': issues,
        'total_opening_braces': sum(line.count('{') for line in lines),
        'total_closing_braces': sum(line.count('}') for line in lines)
    }

if __name__ == "__main__":
    file_path = "/Users/nakulbhatnagar/Desktop/Golf Swing AI/frontend/ios/Views/SwingAnalysisView.swift"
    result = analyze_braces(file_path)
    
    print("BRACE ANALYSIS RESULTS:")
    print("=" * 50)
    print(f"Total opening braces: {result['total_opening_braces']}")
    print(f"Total closing braces: {result['total_closing_braces']}")
    print(f"Difference: {result['total_closing_braces'] - result['total_opening_braces']}")
    print()
    
    print("STRUCT DEFINITIONS:")
    print("-" * 30)
    for struct in result['struct_locations']:
        nesting = "✓ File scope" if struct['nesting_level'] == 0 else f"✗ Nested (level {struct['nesting_level']})"
        print(f"Line {struct['line']:4d}: {struct['name']} - {nesting}")
    print()
    
    print("ISSUES FOUND:")
    print("-" * 30)
    if result['issues']:
        for issue in result['issues']:
            print(f"• {issue}")
    else:
        print("No issues found")