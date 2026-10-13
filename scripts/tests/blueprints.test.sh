#!/usr/bin/env bash
# Offline checks for the MVP screen specs (#23): every screen ID in
# docs/blueprints/flows.md has a 1440 px and a 390 px wireframe PNG, every
# wireframe is linked from screens.md and every link resolves, every screen
# section documents its four states, data, actions and components, and every
# `Entity.field` reference exists in docs/domain/model.md.
# Run from anywhere: bash scripts/tests/blueprints.test.sh
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"

PY=""
for candidate in python3 python; do
  if "$candidate" -c "" >/dev/null 2>&1; then PY="$candidate"; break; fi
done
if [ -z "$PY" ]; then
  echo "error: python3 or python is required." >&2
  exit 2
fi

"$PY" - "$REPO_ROOT" <<'PYEOF'
import os
import re
import struct
import sys

root = sys.argv[1]
blueprints = os.path.join(root, 'docs', 'blueprints')
wireframes = os.path.join(blueprints, 'wireframes')
flows = open(os.path.join(blueprints, 'flows.md'), encoding='utf-8').read()
screens = open(os.path.join(blueprints, 'screens.md'), encoding='utf-8').read()
model = open(os.path.join(root, 'docs', 'domain', 'model.md'), encoding='utf-8').read()

passed = failed = 0


def check(label, ok, detail=''):
    global passed, failed
    if ok:
        passed += 1
        print(f'ok   - {label}')
    else:
        failed += 1
        print(f'FAIL - {label} ({detail})')


def png_width(path):
    with open(path, 'rb') as f:
        head = f.read(24)
    if head[:8] != b'\x89PNG\r\n\x1a\n':
        return None
    return struct.unpack('>I', head[16:20])[0]


ids = re.findall(r'^\| `(S\d\d-[a-z-]+)`', flows.split('## Screen IDs', 1)[1], re.M)
check('flows.md lists screen IDs', len(ids) > 0, 'none found')
files = sorted(f for f in os.listdir(wireframes) if f.endswith('.png'))

for sid in ids:
    for width in ('1440', '390'):
        name = f'{sid}-{width}.png'
        path = os.path.join(wireframes, name)
        if not os.path.exists(path):
            check(f'{name} exists', False, 'missing')
            continue
        actual = png_width(path)
        check(f'{name} is a {width} px PNG', actual == int(width), f'width {actual}')

for name in files:
    check(f'{name} belongs to a screen ID',
          any(name.startswith(sid + '-') for sid in ids), 'no matching ID')
    check(f'{name} is linked from screens.md',
          f'wireframes/{name}' in screens, 'not linked')

for link in sorted(set(re.findall(r'\]\((wireframes/[^)]+)\)', screens))):
    check(f'link {link} resolves',
          os.path.exists(os.path.join(blueprints, link)), 'file not found')

table = screens.split('## Screens', 1)[1].split('\n---\n', 1)[0]
for sid in ids:
    check(f'{sid} is in the screens table', f'`{sid}`' in table, 'missing row')
    section = re.search(r'^### ' + re.escape(sid) + r'\n(.*?)(?=^### |^## |\Z)',
                        screens, re.S | re.M)
    if not section:
        check(f'{sid} has a section', False, 'missing')
        continue
    body = section.group(1)
    for state in ('Loading', 'Empty', 'Error', 'Success'):
        check(f'{sid} documents {state}',
              re.search(r'^\| ' + state + r' \|', body, re.M) is not None, 'no row')
    for part in ('**Data', '**Actions:**', '**Components:**'):
        check(f'{sid} documents {part.strip("*:")}', part in body, 'missing')

diagram = model.split('```mermaid', 1)[1].split('```', 1)[0]
fields = {}
for cls, body in re.findall(r'class (\w+) \{(.*?)\}', diagram, re.S):
    fields[cls] = {line.split()[-1] for line in body.strip().splitlines()
                   if line.strip() and '(' not in line}
refs = sorted(set(re.findall(r'`([A-Z]\w+)\.(\w+)`', screens)))
for cls, field in refs:
    if cls in fields:
        check(f'{cls}.{field} is in docs/domain/model.md',
              field in fields[cls], 'unknown field')

print()
print(f'passed: {passed}, failed: {failed}')
sys.exit(1 if failed else 0)
PYEOF
