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
    
    # Find the if (SCREENSAVER_MODE) { block
    start_str = "if (SCREENSAVER_MODE) {"
    start_idx = content.find(start_str)
    
    new_content = content
    if start_idx != -1:
        # find matching brace
        brace_count = 0
        in_block = False
        end_idx = -1
        for i in range(start_idx, len(content)):
            if content[i] == '{':
                brace_count += 1
                in_block = True
            elif content[i] == '}':
                brace_count -= 1
                if in_block and brace_count == 0:
                    end_idx = i + 1
                    break
        
        if end_idx != -1:
            # Check for " else {" immediately following
            rest = content[end_idx:]
            m = re.match(r'^\s*else\s*\{', rest)
            if m:
                # find end of else block
                else_start = end_idx + m.end() - 1 # points to '{'
                else_brace_count = 0
                else_in_block = False
                else_end_idx = -1
                for i in range(else_start, len(content)):
                    if content[i] == '{':
                        else_brace_count += 1
                        else_in_block = True
                    elif content[i] == '}':
                        else_brace_count -= 1
                        if else_in_block and else_brace_count == 0:
                            else_end_idx = i + 1
                            break
                if else_end_idx != -1:
                    end_idx = else_end_idx

            prefix = content[:start_idx]
            suffix = content[end_idx:]
            # strip trailing spaces from prefix
            prefix = prefix.rstrip() + "\n"
            # strip leading newlines from suffix
            suffix = "\n" + suffix.lstrip('\r\n')
            new_content = prefix + suffix
            
    # Also strip the related constants if they exist
    new_content = re.sub(r'const\s+SCREENSAVER_MODE\s*=\s*_params\.has\(\'screensaver\'\);\n?', '', new_content)
    # Some files use document.body.classList.add('screensaver-mode') in a single line
    new_content = re.sub(r'if\s*\(SCREENSAVER_MODE\)\s*document\.body\.classList\.add\(\'screensaver-mode\'\);\n?', '', new_content)
    
    if new_content != content:
        with open(path, "w") as f:
            f.write(new_content)
