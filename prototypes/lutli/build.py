#!/usr/bin/env python3
"""Build the dependency-free, offline HTML prototype; run from any directory."""
from pathlib import Path
import base64

root = Path(__file__).resolve().parent
output = root.parent.parent / 'docs' / 'prototype' / 'lutli.html'
html = (root / 'markup.html').read_text(encoding="utf-8")
replacements = {
    '/* INLINE_STYLES */': (root / 'styles.css').read_text(encoding="utf-8"),
    '/* INLINE_RENDERER */': (root / 'renderer.js').read_text(encoding="utf-8").replace('</script', '<\\/script'),
    '/* INLINE_APP */': (root / 'app.js').read_text(encoding="utf-8").replace('</script', '<\\/script'),
    '<!-- SCENE_DATA -->': 'data:image/png;base64,' + base64.b64encode((root / 'assets' / 'demo-scene.png').read_bytes()).decode(),
}
for marker, content in replacements.items():
    assert html.count(marker) == 1, f'Missing or duplicate marker: {marker}'
    html = html.replace(marker, content)
output.parent.mkdir(parents=True, exist_ok=True)
output.write_text(html, encoding="utf-8")
print(f'Built {output.relative_to(root.parent.parent)} ({output.stat().st_size:,} bytes)')
