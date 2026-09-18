// Single-stroke vector font for the .vec editor's "text" tool. Each glyph is a
// set of polyline strokes on a grid with the baseline at y=0 and the cap height
// at y=7 (y-up, matching the .vec coordinate system). Rounded letters are drawn
// as short straight segments — a polygonal look that suits the Vectrex beam and
// stays fully editable once dropped into the drawing.
//
// textToPaths(text, height) scales every glyph to the requested cap height and
// lays the string out left to right, returning one editable polyline per stroke.

export interface StrokeGlyph {
  w: number;            // advance width in grid units
  s: number[][][];      // strokes; each stroke is a list of [x, y] points
}

const CAP = 7; // grid cap height

// y-up, baseline 0, cap 7. Only uppercase, digits, space and common symbols;
// lowercase is mapped to uppercase by textToPaths.
export const STROKE_FONT: Record<string, StrokeGlyph> = {
  ' ': { w: 4, s: [] },
  'A': { w: 7, s: [[[0, 0], [3.5, 7], [7, 0]], [[1, 2], [6, 2]]] },
  'B': { w: 6, s: [[[0, 0], [0, 7], [4, 7], [6, 5.75], [4, 3.5], [0, 3.5]], [[4, 3.5], [6, 1.75], [4, 0], [0, 0]]] },
  'C': { w: 6, s: [[[6, 5.5], [4.5, 7], [1.5, 7], [0, 5.5], [0, 1.5], [1.5, 0], [4.5, 0], [6, 1.5]]] },
  'D': { w: 6, s: [[[0, 0], [0, 7], [3.5, 7], [6, 5], [6, 2], [3.5, 0], [0, 0]]] },
  'E': { w: 5.5, s: [[[5.5, 7], [0, 7], [0, 0], [5.5, 0]], [[0, 3.5], [3.5, 3.5]]] },
  'F': { w: 5.5, s: [[[0, 0], [0, 7], [5.5, 7]], [[0, 3.5], [3.5, 3.5]]] },
  'G': { w: 6, s: [[[6, 5.5], [4.5, 7], [1.5, 7], [0, 5.5], [0, 1.5], [1.5, 0], [4.5, 0], [6, 1.5], [6, 3], [3.5, 3]]] },
  'H': { w: 6, s: [[[0, 0], [0, 7]], [[6, 0], [6, 7]], [[0, 3.5], [6, 3.5]]] },
  'I': { w: 4, s: [[[0, 7], [4, 7]], [[2, 7], [2, 0]], [[0, 0], [4, 0]]] },
  'J': { w: 5, s: [[[5, 7], [5, 1.5], [3.5, 0], [1.5, 0], [0, 1.5]]] },
  'K': { w: 6, s: [[[0, 0], [0, 7]], [[6, 7], [0, 3.5], [6, 0]]] },
  'L': { w: 5.5, s: [[[0, 7], [0, 0], [5.5, 0]]] },
  'M': { w: 7.5, s: [[[0, 0], [0, 7], [3.75, 3], [7.5, 7], [7.5, 0]]] },
  'N': { w: 6, s: [[[0, 0], [0, 7], [6, 0], [6, 7]]] },
  'O': { w: 6, s: [[[1.5, 0], [0, 1.5], [0, 5.5], [1.5, 7], [4.5, 7], [6, 5.5], [6, 1.5], [4.5, 0], [1.5, 0]]] },
  'P': { w: 6, s: [[[0, 0], [0, 7], [4, 7], [6, 5.75], [6, 4.75], [4, 3.5], [0, 3.5]]] },
  'Q': { w: 6, s: [[[1.5, 0], [0, 1.5], [0, 5.5], [1.5, 7], [4.5, 7], [6, 5.5], [6, 1.5], [4.5, 0], [1.5, 0]], [[3.5, 2], [6.5, -0.8]]] },
  'R': { w: 6, s: [[[0, 0], [0, 7], [4, 7], [6, 5.75], [6, 4.75], [4, 3.5], [0, 3.5]], [[3, 3.5], [6, 0]]] },
  'S': { w: 6, s: [[[6, 5.5], [4.5, 7], [1.5, 7], [0, 5.5], [1.5, 3.5], [4.5, 3.5], [6, 1.5], [4.5, 0], [1.5, 0], [0, 1.5]]] },
  'T': { w: 6, s: [[[0, 7], [6, 7]], [[3, 7], [3, 0]]] },
  'U': { w: 6, s: [[[0, 7], [0, 1.5], [1.5, 0], [4.5, 0], [6, 1.5], [6, 7]]] },
  'V': { w: 7, s: [[[0, 7], [3.5, 0], [7, 7]]] },
  'W': { w: 9, s: [[[0, 7], [2, 0], [4.5, 5], [7, 0], [9, 7]]] },
  'X': { w: 6, s: [[[0, 0], [6, 7]], [[0, 7], [6, 0]]] },
  'Y': { w: 6, s: [[[0, 7], [3, 3.5], [6, 7]], [[3, 3.5], [3, 0]]] },
  'Z': { w: 6, s: [[[0, 7], [6, 7], [0, 0], [6, 0]]] },
  '0': { w: 6, s: [[[1.5, 0], [0, 1.5], [0, 5.5], [1.5, 7], [4.5, 7], [6, 5.5], [6, 1.5], [4.5, 0], [1.5, 0]], [[1.5, 1.5], [4.5, 5.5]]] },
  '1': { w: 4, s: [[[1, 5.5], [2.5, 7], [2.5, 0]], [[1, 0], [4, 0]]] },
  '2': { w: 6, s: [[[0, 5.5], [1.5, 7], [4.5, 7], [6, 5.5], [6, 4.25], [0, 0], [6, 0]]] },
  '3': { w: 6, s: [[[0, 5.5], [1.5, 7], [4.5, 7], [6, 5.5], [4.5, 3.5], [6, 1.5], [4.5, 0], [1.5, 0], [0, 1.5]], [[4.5, 3.5], [2.5, 3.5]]] },
  '4': { w: 6, s: [[[4.5, 0], [4.5, 7], [0, 2], [6, 2]]] },
  '5': { w: 6, s: [[[6, 7], [0, 7], [0, 4], [4.5, 4], [6, 2.5], [6, 1.5], [4.5, 0], [1.5, 0], [0, 1.5]]] },
  '6': { w: 6, s: [[[6, 5.5], [4.5, 7], [1.5, 7], [0, 5.5], [0, 1.5], [1.5, 0], [4.5, 0], [6, 1.5], [6, 2.5], [4.5, 3.5], [1.5, 3.5], [0, 2.5]]] },
  '7': { w: 6, s: [[[0, 7], [6, 7], [2, 0]]] },
  '8': { w: 6, s: [[[1.5, 3.5], [0, 4.75], [0, 5.75], [1.5, 7], [4.5, 7], [6, 5.75], [6, 4.75], [4.5, 3.5], [1.5, 3.5], [0, 2.25], [0, 1.25], [1.5, 0], [4.5, 0], [6, 1.25], [6, 2.25], [4.5, 3.5]]] },
  '9': { w: 6, s: [[[0, 1.5], [1.5, 0], [4.5, 0], [6, 1.5], [6, 5.5], [4.5, 7], [1.5, 7], [0, 5.5], [0, 4.5], [1.5, 3.5], [4.5, 3.5], [6, 4.5]]] },
  '.': { w: 2.5, s: [[[1, 0], [1, 0.7]]] },
  ',': { w: 2.5, s: [[[1.3, 0.7], [0.6, -1]]] },
  '!': { w: 2, s: [[[1, 7], [1, 2]], [[1, 0.7], [1, 0]]] },
  '?': { w: 6, s: [[[0, 5.5], [1.5, 7], [4.5, 7], [6, 5.5], [6, 4.5], [3, 3], [3, 2]], [[3, 0.7], [3, 0]]] },
  '-': { w: 6, s: [[[1, 3.5], [5, 3.5]]] },
  '+': { w: 6, s: [[[3, 1.5], [3, 5.5]], [[1, 3.5], [5, 3.5]]] },
  '=': { w: 6, s: [[[1, 4.5], [5, 4.5]], [[1, 2.5], [5, 2.5]]] },
  ':': { w: 2, s: [[[1, 5], [1, 4.3]], [[1, 2], [1, 1.3]]] },
  ';': { w: 2.5, s: [[[1.3, 5], [1.3, 4.3]], [[1.3, 1.7], [0.6, -0.6]]] },
  '/': { w: 6, s: [[[0, 0], [6, 7]]] },
  '\\': { w: 6, s: [[[0, 7], [6, 0]]] },
  "'": { w: 2, s: [[[1, 7], [1, 5.5]]] },
  '"': { w: 4, s: [[[1, 7], [1, 5.5]], [[3, 7], [3, 5.5]]] },
  '(': { w: 3.5, s: [[[3, 7], [1, 5], [1, 2], [3, 0]]] },
  ')': { w: 3.5, s: [[[0.5, 7], [2.5, 5], [2.5, 2], [0.5, 0]]] },
  '*': { w: 6, s: [[[3, 2], [3, 6]], [[1.3, 3], [4.7, 5]], [[4.7, 3], [1.3, 5]]] },
  '#': { w: 7, s: [[[2, 0], [3, 7]], [[4, 0], [5, 7]], [[0.5, 2.3], [6.5, 2.3]], [[0.5, 4.7], [6.5, 4.7]]] },
  '&': { w: 7, s: [[[7, 0], [1.5, 5], [1.5, 6], [3, 7], [4.5, 6], [4.5, 5], [0, 2], [0, 1], [1.5, 0], [3, 0], [5, 2.5]]] },
  '%': { w: 7, s: [[[0, 0], [7, 7]], [[1, 7], [2, 7], [2, 6], [1, 6], [1, 7]], [[5, 1], [6, 1], [6, 0], [5, 0], [5, 1]]] },
};

export interface TextPathStroke {
  name: string;
  points: { x: number; y: number }[];
}

export interface TextToPathsOptions {
  spacing?: number;   // extra gap between glyphs, in grid units (default 1.5)
  letterName?: string; // base name for the generated paths
  center?: { x: number; y: number }; // where to centre the string (default origin)
}

/**
 * Convert a string into editable polyline strokes at the requested cap height.
 * Coordinates are y-up, matching the .vec editor. The result is centred on
 * `center` (origin by default) so it drops into the middle of the drawing.
 */
export function textToPaths(
  text: string,
  height: number,
  opts: TextToPathsOptions = {}
): TextPathStroke[] {
  const spacing = opts.spacing ?? 1.5;
  const scale = height / CAP;
  const base = opts.letterName || 'text';

  // first pass: total advance width in grid units
  let totalW = 0;
  const chars = [...text];
  chars.forEach((ch, i) => {
    const g = STROKE_FONT[ch] || STROKE_FONT[ch.toUpperCase()] || STROKE_FONT[' '];
    totalW += g.w + (i < chars.length - 1 ? spacing : 0);
  });

  const cx = opts.center?.x ?? 0;
  const cy = opts.center?.y ?? 0;
  // origin so the string is centred: left edge at cx - totalW*scale/2,
  // vertical middle (cap/2) at cy
  const x0 = cx - (totalW * scale) / 2;
  const y0 = cy - (CAP * scale) / 2;

  const out: TextPathStroke[] = [];
  let penX = 0; // grid units from the left edge
  chars.forEach((ch, ci) => {
    const g = STROKE_FONT[ch] || STROKE_FONT[ch.toUpperCase()] || STROKE_FONT[' '];
    g.s.forEach((stroke, si) => {
      out.push({
        name: `${base}_${ci}_${si}`,
        points: stroke.map(([gx, gy]) => ({
          x: Math.round((x0 + (penX + gx) * scale) * 100) / 100,
          y: Math.round((y0 + gy * scale) * 100) / 100,
        })),
      });
    });
    penX += g.w + spacing;
  });
  return out;
}
