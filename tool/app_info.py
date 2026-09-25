#!/usr/bin/env python3
"""Deploy step: puts the name from app.json on the iPhone home screen (manifest + apple title) and the browser tab.
  python3 tool/app_info.py build/web
To rename the game just edit "name" / "short_name" (under the icon, keep it ≤12 chars) / "subtitle" in app.json.
"""
import html
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def main(out_dir):
    app = json.load(open(os.path.join(ROOT, 'app.json'), encoding='utf-8'))
    name = app.get('name') or 'Game'
    short = app.get('short_name') or name

    mf_path = os.path.join(out_dir, 'manifest.json')
    mf = json.load(open(mf_path, encoding='utf-8'))
    mf['name'], mf['short_name'] = name, short
    if app.get('subtitle'):
        mf['description'] = app['subtitle']
    json.dump(mf, open(mf_path, 'w', encoding='utf-8'), ensure_ascii=False, indent=2)

    idx_path = os.path.join(out_dir, 'index.html')
    page = open(idx_path, encoding='utf-8').read()
    page = re.sub(r'<title>.*?</title>', f'<title>{html.escape(name)}</title>', page, flags=re.S)
    page = re.sub(r'(<meta name="apple-mobile-web-app-title" content=")[^"]*(")', lambda m: m.group(1) + html.escape(short) + m.group(2), page)
    open(idx_path, 'w', encoding='utf-8').write(page)
    print(f'name: {name} / home screen: {short}')


if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else 'build/web')
