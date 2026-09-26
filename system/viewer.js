// Shared by viewer.html (the fullscreen screensaver) and preview.html (the
// settings panel's live preview). They are separate files only because
// Chromium on Wayland derives each window's app_id from the page's path and
// ignores --class, so a separate file is what lets Hyprland (and Service.qml)
// tell a preview window apart from a real screensaver window.
//
// The animation itself runs in a sandboxed iframe (opaque origin, scripts
// only): it can draw, but it cannot read local files, reach this page, or
// close the window. Everything a screensaver needs beyond drawing — the
// info panel and dismiss-on-input — lives here, so animation authors never
// write it themselves.
(function () {
    'use strict';

    const PREVIEW = document.documentElement.dataset.mode === 'preview';
    const params = new URLSearchParams(window.location.search);
    const animPath = params.get('path') || '';

    // Params addressed to this page rather than to the animation. Everything
    // else in the URL is the animation's own settings and is passed through.
    const VIEWER_KEYS = new Set([
        'anim', 'path', 'state', 'screensaver',
        'meta_title', 'meta_description', 'meta_author',
    ]);

    const baseParams = new URLSearchParams();
    params.forEach((value, key) => {
        if (!VIEWER_KEYS.has(key)) baseParams.set(key, value);
    });

    const frame = document.getElementById('anim-frame');

    function frameUrl(overrides) {
        const url = new URL(animPath);
        const merged = new URLSearchParams(baseParams);
        if (overrides) {
            for (const [key, value] of Object.entries(overrides)) {
                if (value === null || value === undefined) continue;
                merged.set(key, String(value));
            }
        }
        url.search = merged.toString();
        return url.toString();
    }

    // Only ever load a local animation file into the frame.
    if (!animPath.startsWith('file:///') || !animPath.endsWith('/index.html')) {
        console.error('[viewer] refusing to load animation path:', animPath);
        return;
    }

    if (PREVIEW) startPreview();
    else startScreensaver();

    // ── Screensaver ────────────────────────────────────────────────────────
    function startScreensaver() {
        frame.src = frameUrl(null);

        // window.close() works because Chromium runs this page in --app mode.
        let armed = false;
        setTimeout(() => { armed = true; }, 1500);
        const dismiss = () => {
            if (!armed) return;
            window.close();
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

        showCredits({
            title: params.get('meta_title') || params.get('anim') || '',
            description: params.get('meta_description') || '',
            author: params.get('meta_author') || '',
        });
    }

    // Built with textContent only: title, description and author come from
    // a marketplace manifest written by whoever submitted the animation, so
    // they must never be parsed as HTML.
    function showCredits(meta) {
        if (!meta.title) return;

        const credits = document.createElement('div');
        credits.className = 'credits-popup';

        const addText = (tag, text, className) => {
            const el = document.createElement(tag);
            el.textContent = text;
            if (className) el.className = className;
            credits.appendChild(el);
        };

        addText('h2', meta.title);
        if (meta.description.trim()) {
            addText('p', 'Animation', 'credits-label');
            addText('p', meta.description);
        }
        if (meta.author.trim()) {
            credits.appendChild(document.createElement('hr'));
            addText('p', 'Credits', 'credits-label');
            addText('p', meta.author);
        }

        document.body.appendChild(credits);
        setTimeout(() => credits.classList.add('visible'), 100);
        setTimeout(() => credits.classList.remove('visible'), 4500);
        setTimeout(() => credits.remove(), 6500);
    }

    // ── Live preview ───────────────────────────────────────────────────────
    // The settings panel rewrites a small JSONP file whenever a setting
    // changes: `window.__previewUpdate({...params})`. A <script> tag can load
    // a file:// URL from a file:// page without --allow-file-access-from-files
    // (fetch() cannot), so this polls by re-adding that tag, and reloads the
    // animation with the new params whenever they differ from the last ones.
    function startPreview() {
        const statePath = params.get('state') || '';
        if (!statePath.startsWith('/') || statePath.includes('..')
                || !statePath.endsWith('/ascii-screensaver/preview-state.js')) {
            console.error('[preview] invalid state path:', statePath);
            frame.src = frameUrl(null);
            return;
        }

        let lastState = null;
        window.__previewUpdate = (state) => {
            if (!state || typeof state !== 'object') return;
            const serialized = JSON.stringify(state);
            if (serialized === lastState) return;
            lastState = serialized;
            frame.src = frameUrl(state);
        };

        let pending = null;
        const poll = () => {
            if (pending) pending.remove();
            const tag = document.createElement('script');
            tag.src = 'file://' + statePath + '?t=' + Date.now();
            tag.onerror = () => {
                // No state written yet: show the animation with its defaults.
                if (lastState === null) window.__previewUpdate({});
            };
            document.head.appendChild(tag);
            pending = tag;
        };
        poll();
        setInterval(poll, 300);
    }
})();
