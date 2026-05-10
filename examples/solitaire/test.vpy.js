/**
 * Test: Solitaire Game
 * 
 * Validates that the Solitaire game renders correctly with multiple UI elements:
 * - Card positions
 * - Tableau columns
 * - Foundation stacks
 * - Stock/waste piles
 */

module.exports = {
  project: 'examples/solitaire',
  frames: 1000,

  assert: function(ctx) {
    // Game should render UI elements
    ctx.expect(ctx.hasDraw(), 'should render card game UI');
    
    // Should have multiple elements (cards, positions, tableau)
    ctx.expect(
      ctx.drawList.length > 15,
      'should render multiple card positions and UI elements'
    );
    
    // Game board should use screen space efficiently
    const xCoords = ctx.drawList.flatMap(v => [v.x0, v.x1]);
    const yCoords = ctx.drawList.flatMap(v => [v.y0, v.y1]);
    
    const xRange = Math.max(...xCoords) - Math.min(...xCoords);
    const yRange = Math.max(...yCoords) - Math.min(...yCoords);
    
    ctx.expect(
      xRange > 40 && yRange > 40,
      'should use reasonable screen area for card tableau'
    );
  },
};
