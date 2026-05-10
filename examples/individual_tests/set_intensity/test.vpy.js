/**
 * test.vpy.js — VPy Test Spec for: set_intensity
 *
 * Tests that the program draws with non-zero intensity (brightness).
 */
'use strict';

module.exports = {
  project: 'examples/individual_tests/set_intensity',
  frames: 1000,

  assert: function(ctx) {
    ctx.expect(ctx.hasDraw(), 'should draw something');
    const bright = ctx.drawList.filter(v => v.color > 0);
    ctx.expect(bright.length > 0, `should have lines with color > 0 (got ${bright.length})`);
  },
};
