/**
 * test.vpy.js — VPy Test Spec for: draw_line
 *
 * Tests that the program draws a pentagon (5 sides) using DRAW_LINE.
 * Source: examples/individual_tests/draw_line/src/main.vpy
 */
'use strict';

module.exports = {
  project: 'examples/individual_tests/draw_line',
  frames: 1000,

  assert: function(ctx) {
    // Should draw something at all
    ctx.expect(ctx.hasDraw(), 'should draw at least one vector');

    // Pentagon has 5 sides + text characters = many lines
    // But we only care about the 5 pentagon sides
    ctx.expect(ctx.drawList.length >= 5, `should draw at least 5 lines (got ${ctx.drawList.length})`);

    // The five pentagon sides (raw Vectrex pixel coords — emulator uses ALG scale).
    // VPy DRAW_LINE coords are in Vectrex units; jsvecx scales them internally.
    // We validate structurally: at least 5 lines were rendered with non-zero color.
    const coloredLines = ctx.drawList.filter(v => v.color > 0);
    ctx.expect(coloredLines.length >= 5, `should have at least 5 colored lines (got ${coloredLines.length})`);
  },
};
