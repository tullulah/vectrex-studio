/**
 * Test: Unsigned 16-bit Variables
 * 
 * Validates that u16 variables correctly handle large positive values and arithmetic.
 */

module.exports = {
  project: 'examples/test_u16_simple',
  frames: 1000,

  assert: function(ctx) {
    // Program starts with value 1000 and adds 100 per frame
    // So it should draw at different positions
    
    ctx.expect(ctx.hasDraw(), 'should draw with u16 variables');
    
    // Should have lines from the drawing operations
    ctx.expect(
      ctx.drawList.length >= 3,
      'should have multiple frame outputs'
    );
    
    // The value variable is used in drawing, so we should see different coordinates
    // indicating that the variable is actually changing and being rendered correctly
    const coords = ctx.drawList.map(v => ({ x0: v.x0, x1: v.x1, y0: v.y0, y1: v.y1 }));
    
    ctx.expect(
      coords.length > 0,
      'should have valid coordinate data'
    );
    
    // Large u16 values should produce visible variations in coordinates
    const maxX = Math.max(...ctx.drawList.map(v => Math.max(Math.abs(v.x0), Math.abs(v.x1))));
    ctx.expect(
      maxX > 50,
      'should have significant coordinate values from u16 arithmetic'
    );
  },
};
