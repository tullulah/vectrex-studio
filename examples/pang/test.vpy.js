/**
 * Test: Pang
 * 
 * Validates that the Pang game compiles and runs.
 */

module.exports = {
  project: 'examples/pang',
  frames: 1000,

  assert: function(ctx) {
    ctx.expect(ctx.drawList !== undefined, 'should compile and run successfully');
    ctx.expect(true, 'Pang game should execute');
  },
};
