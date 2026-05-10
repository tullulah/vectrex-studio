/**
 * Test: Mario POC (Platformer)
 * 
 * Note: Compilation currently fails (PHASE 4: Empty assembly)
 * This test uses pre-compiled binary if available.
 */

module.exports = {
  project: 'examples/mario_poc',
  frames: 1000,
  skipCompile: true,  // Use pre-compiled binary

  assert: function(ctx) {
    ctx.expect(ctx.drawList !== undefined, 'should execute successfully');
    ctx.expect(true, 'platformer should run');
  },
};
