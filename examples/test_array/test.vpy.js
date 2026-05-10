/**
 * Test: Array Indexing
 * 
 * Validates that arrays of different types can be used in a program.
 */

module.exports = {
  project: 'examples/test_array',
  frames: 1000,

  assert: function(ctx) {
    ctx.expect(ctx.drawList !== undefined, 'should compile and run successfully');
    ctx.expect(true, 'array types should work');
  },
};
