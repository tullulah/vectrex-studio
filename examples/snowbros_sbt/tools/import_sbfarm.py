#!/usr/bin/env python3
"""Import SBFARM sprite-RAM dumps from a saved IDE console log.

Play in the IDE (F5); every first sighting of an unknown sprite frame logs an
'SBFARM <hex>' line to the console. Save the console/output log to a file and
run:  python3 tools/import_sbfarm.py <logfile>
The dumps land in dumps/ and the usual  --catalog  pass picks them up.
"""
import sys
import re
from pathlib import Path

here = Path(__file__).resolve().parent.parent
log = Path(sys.argv[1])
n = 0
existing = len(list((here / 'dumps').glob('sbfarm_*.bin')))
for m in re.finditer(r'SBFARM ([0-9a-f]{8192})', log.read_text(errors='replace')):
    data = bytes.fromhex(m.group(1))
    (here / 'dumps' / f'sbfarm_{existing + n:05d}.bin').write_bytes(data)
    n += 1
print(f'{n} dumps imported into dumps/')
