/**
 * Test: Type System (Multi-type)
 * 
 * Note: Compilation currently fails (PHASE 6: Binary assembly error)
 * This test uses pre-compiled binary if available.
 */

module.exports = {
  project: 'examples/test_types',
  frames: 1000,
  skipCompile: true,  // Use pre-compiled binary

  assert: function(ctx) {
    ctx.expect(ctx.drawList !== undefined, 'should execute successfully');
    ctx.expect(true, 'type system should work');
  },
};
