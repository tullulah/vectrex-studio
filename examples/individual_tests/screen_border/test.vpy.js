/**
 * test.vpy.js — VPy Test Spec for: screen_border
 *
 * Tests that the program draws 4 border lines forming a rectangle.
 */
'use strict';

module.exports = {
  project: 'examples/individual_tests/screen_border',
  frames: 1000,

  assert: function(ctx) {
    ctx.expect(ctx.hasDraw(), 'should draw something');
    ctx.expect(ctx.drawList.length >= 4, `should draw at least 4 border lines (got ${ctx.drawList.length})`);
  },
};
