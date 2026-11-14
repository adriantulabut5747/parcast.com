"""Copies the pieces of three.js the Tugak scene needs into web/tugak/three/.

Pinned version, served with the app (like MapLibre in web/map/): nothing is fetched
from anyone else's server at run time. Run again only to change VERSION.

  python tools/vendor_three.py
"""

import os
import re
import urllib.request

VERSION = '0.170.0'
CDN = f'https://cdn.jsdelivr.net/npm/three@{VERSION}/'
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'web', 'tugak', 'three')

# published path -> file name here (all flat in one folder)
FILES = {
    'build/three.module.min.js': 'three.module.min.js',
    'examples/jsm/loaders/GLTFLoader.js': 'GLTFLoader.js',
    'examples/jsm/utils/BufferGeometryUtils.js': 'BufferGeometryUtils.js',
    'examples/jsm/libs/meshopt_decoder.module.js': 'meshopt_decoder.module.js',
    'examples/jsm/environments/RoomEnvironment.js': 'RoomEnvironment.js',
    'LICENSE': 'LICENSE.txt',
}

os.makedirs(OUT, exist_ok=True)
for src, name in FILES.items():
    with urllib.request.urlopen(CDN + src) as r:
        text = r.read().decode('utf-8')
    # Browsers can't resolve the bare name 'three' without an import map, and the
    # folders are flattened: point every import at the file next to it.
    text = re.sub(r"from 'three'", "from './three.module.min.js'", text)
    text = re.sub(r"from '\.\./utils/([A-Za-z]+\.js)'", r"from './\1'", text)
    with open(os.path.join(OUT, name), 'w', encoding='utf-8', newline='\n') as f:
        f.write(text)
    print(f'{name}: {len(text) // 1024} KB')
