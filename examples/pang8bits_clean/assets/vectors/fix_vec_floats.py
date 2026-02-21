#!/usr/bin/env python3
"""
Fix floating-point coordinates in .vec files.
Usage: python3 fix_vec_floats.py <file.vec>
"""
import json
import re
import sys

if len(sys.argv) != 2:
    print("Usage: python3 fix_vec_floats.py <file.vec>")
    sys.exit(1)

filename = sys.argv[1]

# Read file
with open(filename, 'r') as f:
    content = f.read()

# Count floats before
float_count = len(re.findall(r'"[xyz]":\s*-?\d+\.\d+', content))
print(f"Found {float_count} float coordinates in {filename}")

if float_count == 0:
    print("✓ No floats to fix")
    sys.exit(0)

# Round all float coordinates to integers
def round_coord(match):
    key = match.group(1)
    value = float(match.group(2))
    return f'"{key}": {int(round(value))}'

content = re.sub(r'"([xyz])":\s*(-?\d+\.\d+)', round_coord, content)

# Verify all floats are gone
remaining = len(re.findall(r'"[xyz]":\s*-?\d+\.\d+', content))
print(f"Remaining floats: {remaining}")

# Write back
with open(filename, 'w') as f:
    f.write(content)

# Verify JSON
try:
    data = json.loads(content)
    path_count = len(data['layers'][0]['paths'])
    print(f"✓ JSON valid, {path_count} paths")
except Exception as e:
    print(f"✗ JSON validation failed: {e}")
    sys.exit(1)
