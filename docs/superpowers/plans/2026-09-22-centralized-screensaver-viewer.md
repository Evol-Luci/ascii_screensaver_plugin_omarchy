# Centralized Screensaver Viewer Implementation Plan

> **Status:** Implemented, with changes — see the note at the top of the matching spec. Historical plan.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Shift info panel rendering and mouse/keyboard dismiss logic from individual animations to a centralized HTML wrapper.

**Architecture:** A new `system/viewer.html` wrapper loaded by `bin/ascii-screensaver-cmd`. It embeds the target animation via iframe and places a transparent shield on top to catch events and draw a unified info panel.

**Tech Stack:** HTML/JS, Bash, jq.

## Global Constraints
None specified directly beyond existing Omarchy environment capabilities (Wayland, Chromium kiosk).

---

### Task 1: Create the Viewer Wrapper Base

**Files:**
- Create: `system/viewer.html`

**Interfaces:**
- Consumes: Query parameters `anim` (animation ID), `path` (file URI of animation), and `screensaver=1`
- Produces: A rendering environment for the animation iframe with a transparent dismiss shield.

- [ ] **Step 1: Write `system/viewer.html` basic structure**

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Screensaver Viewer</title>
    <style>
        @import url('https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;700&display=swap');
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            background: #000;
            overflow: hidden;
            width: 100vw;
            height: 100vh;
            cursor: none;
        }
        #anim-frame {
            position: absolute;
            top: 0; left: 0;
            width: 100%; height: 100%;
            border: none;
            z-index: 1;
        }
        #dismiss-shield {
            position: absolute;
            top: 0; left: 0;
            width: 100%; height: 100%;
            z-index: 9999;
            background: transparent;
        }
        .credits-popup {
            position: fixed;
            bottom: 32px;
            right: 32px;
            background: rgba(10, 10, 18, 0.92);
            border: 1px solid rgba(50, 110, 50, 0.4);
            border-radius: 8px;
            padding: 20px 24px;
            font-family: 'JetBrains Mono', 'Courier New', monospace;
            font-size: 12px;
            color: #90b890;
            max-width: 280px;
            opacity: 0;
            transition: opacity 2s ease-in-out;
            z-index: 10000;
            line-height: 1.6;
        }
        .credits-popup.visible { opacity: 1; }
        .credits-popup h2 {
            font-size: 14px;
            font-weight: 700;
            color: #40a040;
            letter-spacing: 2px;
            text-transform: uppercase;
            margin-bottom: 4px;
        }
        .credits-popup .credits-label {
            font-size: 10px;
            color: #507050;
            text-transform: uppercase;
            letter-spacing: 1px;
            margin-top: 10px;
            margin-bottom: 4px;
        }
        .credits-popup hr {
            border: none;
            border-top: 1px solid rgba(50, 110, 50, 0.3);
            margin: 12px 0;
        }
        .credits-popup a { color: #50a050; text-decoration: none; }
    </style>
</head>
<body>
    <iframe id="anim-frame"></iframe>
    <div id="dismiss-shield"></div>

    <script>
        const params = new URLSearchParams(window.location.search);
        const animPath = params.get('path');
        const animId = params.get('anim');
        
        // Pass original params down to iframe
        const frameUrl = new URL(animPath);
        params.forEach((val, key) => {
            if (key !== 'path' && key !== 'anim') {
                frameUrl.searchParams.set(key, val);
            }
        });
        document.getElementById('anim-frame').src = frameUrl.toString();

        // Dismiss Logic
        let armed = false;
        setTimeout(() => { armed = true; }, 1500);
        const dismiss = () => {
            if (!armed) return;
            try { window.close(); } catch(e) {}
            document.body.innerHTML = '';
        };

        const shield = document.getElementById('dismiss-shield');
        shield.addEventListener('mousedown', dismiss);
        document.addEventListener('keydown', dismiss);
        
        let lastX = -1, lastY = -1, moveCount = 0;
        shield.addEventListener('mousemove', (e) => {
            if (lastX === -1) { lastX = e.clientX; lastY = e.clientY; return; }
            if (e.clientX === lastX && e.clientY === lastY) return;
            lastX = e.clientX; lastY = e.clientY;
            if (++moveCount > 10) dismiss();
        });
    </script>
</body>
</html>
```

- [ ] **Step 2: Commit wrapper base**
```bash
git add system/viewer.html
git commit -m "feat: add basic viewer wrapper with dismiss logic"
```

---

### Task 2: Implement Metadata Parsing in Viewer

**Files:**
- Modify: `system/viewer.html`

- [ ] **Step 1: Add fetch logic for metadata**
Append inside the `<script>` block in `system/viewer.html`:

```javascript
        async function loadMetadata() {
            if (!animId) return;
            try {
                // Determine if bundled or user animation
                const isUserAnim = animPath.includes('.config/omarchy/ascii-screensaver');
                let metadata = { title: animId, hint: '', author: '' };

                if (isUserAnim) {
                    const manifestPath = animPath.substring(0, animPath.lastIndexOf('/')) + '/manifest.json';
                    const res = await fetch(manifestPath);
                    if (res.ok) {
                        const manifest = await res.json();
                        metadata.title = manifest.name || animId;
                        metadata.hint = manifest.description || '';
                        metadata.author = manifest.author || '';
                    }
                } else {
                    // Fetch bundled schema
                    // Since viewer is in system/, params.schema.json is at ../params.schema.json
                    const schemaRes = await fetch('../params.schema.json');
                    if (schemaRes.ok) {
                        const schema = await schemaRes.json();
                        if (schema[animId]) {
                            metadata.title = schema[animId].title || animId;
                            metadata.hint = schema[animId].hint || '';
                            metadata.author = 'Evol Digital Productions'; // Bundled default
                        }
                    }
                }
                
                showCredits(metadata);
            } catch (err) {
                console.error("Failed to load metadata", err);
            }
        }

        function showCredits(meta) {
            const credits = document.createElement('div');
            credits.className = 'credits-popup';
            
            let html = `<h2>${meta.title}</h2>`;
            if (meta.hint) {
                html += `<p class="credits-label">Animation</p><p>${meta.hint}</p>`;
            }
            if (meta.author) {
                html += `<hr><p class="credits-label">Credits</p><p>${meta.author}</p>`;
            }
            credits.innerHTML = html;
            
            document.body.appendChild(credits);
            setTimeout(() => credits.classList.add('visible'), 500);
            setTimeout(() => credits.classList.remove('visible'), 30500);
            setTimeout(() => credits.remove(), 32500);
        }

        loadMetadata();
```

- [ ] **Step 2: Commit metadata logic**
```bash
git add system/viewer.html
git commit -m "feat: parse and display metadata panel in viewer"
```

---

### Task 3: Update `bin/ascii-screensaver-cmd`

**Files:**
- Modify: `bin/ascii-screensaver-cmd`

- [ ] **Step 1: Route Chromium to `viewer.html`**
Change how `HTML_URL` is constructed in `bin/ascii-screensaver-cmd`. Replace:

```bash
# Build base URL
if [[ -n "${START_AT:-}" ]]; then
  HTML_URL="file://${ANIM_DIR}?screensaver=1&startAt=${START_AT}"
else
  HTML_URL="file://${ANIM_DIR}?screensaver=1&delayedStart=1"
fi
```
With:
```bash
# Build base URL pointing to viewer wrapper
VIEWER_HTML="${PLUGIN_ROOT}/system/viewer.html"

if [[ -n "${START_AT:-}" ]]; then
  HTML_URL="file://${VIEWER_HTML}?anim=${ANIMATION}&path=file://${ANIM_DIR}&screensaver=1&startAt=${START_AT}"
else
  HTML_URL="file://${VIEWER_HTML}?anim=${ANIMATION}&path=file://${ANIM_DIR}&screensaver=1&delayedStart=1"
fi
```

- [ ] **Step 2: Add flag for local file access**
In the `chromium` launch command at the bottom, add `--allow-file-access-from-files` so `viewer.html` can fetch `params.schema.json` and user manifests.

Modify:
```bash
  --disable-dev-shm-usage \
  --background-color=000000 \
```
To:
```bash
  --disable-dev-shm-usage \
  --allow-file-access-from-files \
  --background-color=000000 \
```

- [ ] **Step 3: Commit launcher changes**
```bash
git add bin/ascii-screensaver-cmd
git commit -m "feat: route launcher to central viewer wrapper"
```

---

### Task 4: Clean Up Legacy Boilerplate

**Files:**
- Modify: All `animations/*/index.html`
- Create: `scripts/strip-boilerplate.py`

- [ ] **Step 1: Write a python script to strip the boilerplate from all animations**
Create `scripts/strip-boilerplate.py`:
```python
import os
import re

animations_dir = "animations"
# A regex to aggressively strip out the entire `if (SCREENSAVER_MODE) { ... }` block.
# We will match from `if (SCREENSAVER_MODE)` to the end of the block.
# It's usually the last thing in the <script>.
for anim in os.listdir(animations_dir):
    path = os.path.join(animations_dir, anim, "index.html")
    if not os.path.isfile(path): continue
    
    with open(path, "r") as f:
        content = f.read()
    
    # Simple replace for known boilerplate
    # Use re.sub with DOTALL to remove the entire if (SCREENSAVER_MODE) { ... } block
    new_content = re.sub(r'if\s*\(SCREENSAVER_MODE\)\s*\{.*?\n\}\s*(?=</script>)', '', content, flags=re.DOTALL)
    
    # Also strip the related constants if they exist
    new_content = re.sub(r'const\s+SCREENSAVER_MODE\s*=\s*_params\.has\(\'screensaver\'\);\n?', '', new_content)
    
    with open(path, "w") as f:
        f.write(new_content)
```

- [ ] **Step 2: Run the script to clean up**
Run: `python3 scripts/strip-boilerplate.py`
Verify changes: `git diff animations/bonsai/index.html`

- [ ] **Step 3: Remove unused CSS**
Since `.credits-popup` CSS is no longer used, we can also manually remove it or use another script to strip `.credits-popup { ... }` up to `</style>`. For simplicity, this step can be manual or skipped (CSS won't hurt).

- [ ] **Step 4: Commit cleanup**
```bash
git add animations/ scripts/
git commit -m "refactor: remove legacy screensaver boilerplate from bundled animations"
```

---

### Task 5: Update `AGENTS.md`

**Files:**
- Modify: `AGENTS.md`

- [ ] **Step 1: Update the "Anatomy of a marketplace animation" section**
Remove the `Screensaver Dismiss Logic` requirement. State clearly that the system wrapper automatically handles mouse/keyboard events and `window.close()`.

Replace:
```markdown
2. **Screensaver Dismiss Logic**: Animations do NOT close automatically. To respond to mouse and keyboard events when the screensaver runs, you MUST inject the following snippet at the bottom of the animation's `<script>` block:
[...code block...]
```
With:
```markdown
2. **Screensaver Dismiss Logic**: You do **NOT** need to implement dismiss logic. The Omarchy screensaver plugin wraps all animations in a unified system viewer that captures mouse/keyboard activity and automatically tears down the process.
```

- [ ] **Step 2: Commit doc updates**
```bash
git add AGENTS.md
git commit -m "docs: remove dismiss logic requirement for creators"
```
