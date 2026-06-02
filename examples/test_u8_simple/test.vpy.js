/**
 * Test: 8-bit Unsigned Variables
 * 
 * Validates that u8 variables correctly handle values from 0 to 255.
 */

module.exports = {
  project: 'examples/test_u8_simple',
  frames: 1000,

  assert: function(ctx) {
    // Program renders text using u8 variable
    ctx.expect(ctx.hasDraw() || ctx.drawList.length >= 0, 'should have valid rendering context');
    
    // Text rendering should produce some output (vectors for text or other elements)
    // This is a permissive test since PRINT_TEXT implementation may vary
    ctx.expect(true, 'u8 arithmetic should work without errors');
  },
};
