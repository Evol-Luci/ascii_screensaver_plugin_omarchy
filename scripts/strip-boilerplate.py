import os
import re

animations_dir = "animations"
for anim in os.listdir(animations_dir):
    anim_path = os.path.join(animations_dir, anim)
    if not os.path.isdir(anim_path): continue
    
    path = os.path.join(anim_path, "index.html")
    if not os.path.isfile(path): continue
    
    with open(path, "r") as f:
        content = f.read()
    
    new_content = content
    
    # Handle both SCREENSAVER_MODE and SCREENSAVER patterns
    for start_str in ["if (SCREENSAVER_MODE) {", "if (SCREENSAVER) {"]:
        while True:
            start_idx = new_content.find(start_str)
            if start_idx == -1:
                break
            
            # find matching brace
            brace_count = 0
            in_block = False
            end_idx = -1
            for i in range(start_idx, len(new_content)):
                if new_content[i] == '{':
                    brace_count += 1
                    in_block = True
                elif new_content[i] == '}':
                    brace_count -= 1
                    if in_block and brace_count == 0:
                        end_idx = i + 1
                        break

            # Unbalanced braces: leave the file alone rather than looping
            # forever on the same match.
            if end_idx == -1:
                print(f"Skipping {path}: unbalanced braces after '{start_str}'")
                break

            if end_idx != -1:
                # Check for " else {" immediately following
                rest = new_content[end_idx:]
                m = re.match(r'^\s*else\s*\{', rest)
                if m:
                    # find end of else block
                    else_start = end_idx + m.end() - 1  # points to '{'
                    else_brace_count = 0
                    else_in_block = False
                    else_end_idx = -1
                    for i in range(else_start, len(new_content)):
                        if new_content[i] == '{':
                            else_brace_count += 1
                            else_in_block = True
                        elif new_content[i] == '}':
                            else_brace_count -= 1
                            if else_in_block and else_brace_count == 0:
                                else_end_idx = i + 1
                                break
                    if else_end_idx != -1:
                        end_idx = else_end_idx
                
                prefix = new_content[:start_idx]
                suffix = new_content[end_idx:]
                prefix = prefix.rstrip() + "\n"
                suffix = "\n" + suffix.lstrip('\r\n')
                new_content = prefix + suffix
    
    # Also strip the related constants if they exist
    new_content = re.sub(r'const\s+SCREENSAVER_MODE\s*=\s*\w+\.has\(\'screensaver\'\);\n?', '', new_content)
    new_content = re.sub(r'const\s+SCREENSAVER\s*=\s*\w+\.has\(\'screensaver\'\);\n?', '', new_content)
    # Some files use document.body.classList.add('screensaver-mode') in a single line
    new_content = re.sub(r'if\s*\(SCREENSAVER_MODE\)\s*document\.body\.classList\.add\(\'screensaver-mode\'\);\n?', '', new_content)
    new_content = re.sub(r'if\s*\(SCREENSAVER\)\s*document\.body\.classList\.add\(\'screensaver-mode\'\);\n?', '', new_content)
    
    if new_content != content:
        with open(path, "w") as f:
            f.write(new_content)
            print(f"Stripped boilerplate from {path}")