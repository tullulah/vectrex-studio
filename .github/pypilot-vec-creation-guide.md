# PyPilot Guide: Creating .vec Vector Files

## ✅ CORRECT FORMAT (VERIFIED WORKING)

### Basic Structure
```json
{
  "version": "1.0",
  "name": "asset_name",
  "canvas": {
    "width": 256,
    "height": 256,
    "origin": "center"
  },
  "layers": [
    {
      "name": "default",
      "visible": true,
      "paths": [
        {
          "name": "path_identifier",
          "intensity": 127,
          "closed": true,
          "points": [
            {"x": 0, "y": 20},
            {"x": -15, "y": -10},
            {"x": 15, "y": -10}
          ]
        }
      ]
    }
  ]
}
```

## 📋 MANDATORY FIELDS

### Top Level
- **`version`**: Always `"1.0"`
- **`name`**: Asset name (matches filename without .vec)
- **`canvas`**: Canvas definition
  - `width`: 256
  - `height`: 256
  - `origin`: "center"

### Layer Level
- **`name`**: Any string (typically "default")
- **`visible`**: **MUST BE `true`** - only visible layers are processed
- **`paths`**: Array of path objects

### Path Level (Each path = separate drawing call)
- **`name`**: Unique identifier for this path
- **`intensity`**: 0-255 (brightness, recommended 80-127)
- **`closed`**: 
  - `true` = polygon (auto-closes back to first point)
  - `false` = open line/polyline
- **`points`**: Array of coordinate objects

### Point Level
- **`x`**: Integer -127 to 127 (centered at 0)
- **`y`**: Integer -127 to 127 (centered at 0)

## ✅ WORKING EXAMPLES

### Single Path (Simple Shape)
```json
{
  "version": "1.0",
  "name": "triangle",
  "canvas": {"width": 256, "height": 256, "origin": "center"},
  "layers": [{
    "name": "default",
    "visible": true,
    "paths": [{
      "name": "body",
      "intensity": 127,
      "closed": true,
      "points": [
        {"x": 0, "y": 20},
        {"x": -15, "y": -10},
        {"x": 15, "y": -10}
      ]
    }]
  }]
}
```

### Multi-Path (Complex Shape)
```json
{
  "version": "1.0",
  "name": "spaceship",
  "canvas": {"width": 256, "height": 256, "origin": "center"},
  "layers": [{
    "name": "default",
    "visible": true,
    "paths": [
      {
        "name": "hull",
        "intensity": 127,
        "closed": true,
        "points": [
          {"x": 0, "y": 25},
          {"x": -10, "y": -15},
          {"x": 0, "y": -10},
          {"x": 10, "y": -15}
        ]
      },
      {
        "name": "wing_left",
        "intensity": 100,
        "closed": false,
        "points": [
          {"x": -10, "y": -15},
          {"x": -20, "y": -20}
        ]
      },
      {
        "name": "wing_right",
        "intensity": 100,
        "closed": false,
        "points": [
          {"x": 10, "y": -15},
          {"x": 20, "y": -20}
        ]
      }
    ]
  }]
}
```

## ❌ COMMON MISTAKES TO AVOID

### 1. Missing `visible: true`
```json
❌ BAD:
"layers": [{
  "name": "default",
  "paths": [...]  // Missing visible field
}]

✅ GOOD:
"layers": [{
  "name": "default",
  "visible": true,
  "paths": [...]
}]
```

### 2. Coordinates Out of Range
```json
❌ BAD:
{"x": 200, "y": -150}  // Out of -127 to 127 range

✅ GOOD:
{"x": 100, "y": -100}  // Within valid range
```

### 3. Missing Required Fields
```json
❌ BAD:
{
  "name": "ship",
  "points": [...]  // Missing intensity, closed
}

✅ GOOD:
{
  "name": "ship",
  "intensity": 127,
  "closed": true,
  "points": [...]
}
```

### 4. Compact JSON (Hard to Debug)
```json
❌ BAD (one-line):
{"version":"1.0","name":"asset","canvas":{...},...}

✅ GOOD (formatted):
{
  "version": "1.0",
  "name": "asset",
  "canvas": {...},
  ...
}
```

## 🎨 DESIGN GUIDELINES

### Coordinate System
- Origin (0,0) is at canvas center
- Positive Y = up, Negative Y = down
- Positive X = right, Negative X = left
- Valid range: -127 to +127 for both axes

### Intensity Recommendations
- **127**: Maximum brightness (main shapes)
- **100-110**: Medium brightness (secondary details)
- **80-90**: Low brightness (effects, trails)

### Path Organization
- **First path**: Usually main body/outline
- **Subsequent paths**: Details, wings, decorations
- Each path draws independently (separate JSR Draw_Sync_List)

### Closed vs Open Paths
- **Closed (`true`)**: Polygons, solid shapes
- **Open (`false`)**: Lines, trails, non-connecting elements

## 🔍 VERIFICATION

After creating a .vec file:

1. **Validate JSON**: Check syntax with any JSON validator
2. **Compile**: `cargo run --bin vpy_cli -- build your_program.vpy -o your_program.bin`
3. **Check ASM**: Run `cargo run --bin vpy_cli -- asm your_program.vpy` and verify the asset block (`; Generated from name.vec`, `; Total paths: N, points: M`) appears with the expected path count
4. **Test Binary**: Load .bin in IDE and verify all paths render

## 📊 PROVEN WORKING EXAMPLES (2025-12-12)

- **moon.vec**: 3 paths (circle + 2 craters) ✅
- **enemigo.vec**: 9 paths (complex alien) ✅
- **astronauta.vec**: 6 paths (humanoid figure) ✅
- **bullet.vec**: 2 paths (core + trail) ✅
- **cohete_base.vec**: 5 paths (rocket with fins) ✅
- **ejemplo.vec**: 6 paths (character with limbs) ✅
- **player.vec**: 2 paths (ship + cockpit) ✅
- **nave3d.vec**: 3 paths (ship body + wings) ✅

All follow this exact format and render correctly with multi-path architecture.
