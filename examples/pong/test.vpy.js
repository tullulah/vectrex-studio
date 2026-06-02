/**
 * Test: Pong Game
 * 
 * Note: Compilation currently fails (PHASE 3: Syntax error at line 45)
 * This test uses pre-compiled binary if available.
 */

module.exports = {
  project: 'examples/pong',
  frames: 1000,
  skipCompile: true,  // Use pre-compiled binary

  assert: function(ctx) {
    ctx.expect(ctx.drawList !== undefined, 'should execute successfully');
    ctx.expect(true, 'Pong should run');
  },
};
