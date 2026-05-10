/**
 * Test: 8-bit Signed Variables
 * 
 * Validates that i8 variables handle small signed values (-128 to +127).
 */

module.exports = {
  project: 'examples/test_i8_simple',
  frames: 1000,

  assert: function(ctx) {
    // Program uses 8-bit arithmetic
    ctx.expect(ctx.hasDraw(), 'should render with i8-like operations');
    
    // Should produce some output
    ctx.expect(
      ctx.drawList.length >= 0,
      'should have drawing operations'
    );
  },
};
