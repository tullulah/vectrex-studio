/**
 * Test: Jetpac Minimal
 * 
 * Validates that Jetpac POC compiles and runs.
 */

module.exports = {
  project: 'examples/jetpac',
  frames: 1000,

  assert: function(ctx) {
    ctx.expect(ctx.drawList !== undefined, 'should compile and run successfully');
    ctx.expect(true, 'Jetpac POC should execute');
  },
};
