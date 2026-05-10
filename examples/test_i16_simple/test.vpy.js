/**
 * Test: Signed 16-bit Variables
 * 
 * Validates that i16 variables correctly handle negative values and arithmetic.
 */

module.exports = {
  project: 'examples/test_i16_simple',
  frames: 1000,

  assert: function(ctx) {
    // Program starts with negative value (-1000) and adds 50 per frame
    // So it should draw at different positions
    
    ctx.expect(ctx.hasDraw(), 'should draw with i16 variables');
    
    // Should have lines from the drawing operations
    ctx.expect(
      ctx.drawList.length >= 3,
      'should have multiple frame outputs'
    );
    
    // The value variable is used in drawing, so we should see different coordinates
    // indicating that the variable is actually changing
    const uniqueXCoords = new Set();
    ctx.drawList.forEach(v => {
      uniqueXCoords.add(v.x0);
      uniqueXCoords.add(v.x1);
    });
    
    ctx.expect(
      uniqueXCoords.size >= 2,
      'should have varying coordinates (indicating variable changes)'
    );
  },
};
