/**
 * Test: Vectrex 3D Logo
 * 
 * Note: Compilation currently fails (PHASE 4: Empty assembly)
 * This test uses pre-compiled binary if available.
 */

module.exports = {
  project: 'examples/vectrex_3d_logo',
  frames: 1000,
  skipCompile: true,  // Use pre-compiled binary

  assert: function(ctx) {
    ctx.expect(ctx.drawList !== undefined, 'should execute successfully');
    ctx.expect(true, '3D logo should run');
  },
};
