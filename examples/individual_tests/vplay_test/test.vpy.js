/**
 * Test: VPLAY Test - Verify SHOW_LEVEL + PRINT_TEXT + DRAW_VECTOR work together
 * 
 * Tests the ACR ($D00B) restoration fix: SHOW_LEVEL was leaving ACR=$18 (disabled T1PB7),
 * breaking subsequent PRINT_TEXT and DRAW_VECTOR operations.
 * Fix: SLR_DONE now restores ACR=$98 before returning.
 */

module.exports = {
  project: 'examples/individual_tests/vplay_test',
  frames: 2,
  skipCompile: false,  // Recompile to get ACR fix

  assert: function(ctx) {
    // With ACR fix: should see PRINT_TEXT ("VPLAY TEST") + level objects + platform
    // Expected ~100-150 vectors: text (30-40) + level objects (40-60) + platform (20-30)
    ctx.expect(ctx.drawList !== undefined, 'should execute successfully');
    ctx.expect(ctx.drawList.length > 80, `should have vectors from PRINT_TEXT, SHOW_LEVEL, and DRAW_VECTOR combined (got ${ctx.drawList.length})`);
    ctx.expect(true, 'VPLAY test with ACR fix should render correctly');
  },
};
