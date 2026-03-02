//! Drawing Geometric Shapes
//!
//! Builtins for drawing circles, rectangles, polygons, etc.

use std::collections::HashSet;
use vpy_parser::Expr;

/// DRAW_CIRCLE(xc, yc, diam) or DRAW_CIRCLE(xc, yc, diam, intensity)
pub fn emit_draw_circle(
    args: &[Expr],
    out: &mut String,
) {
    if args.len() != 3 && args.len() != 4 {
        out.push_str("    ; ERROR: DRAW_CIRCLE requires 3 or 4 arguments\n");
        return;
    }
    
    // Check if all args are constants - optimize as 16-gon inline
    if args.iter().all(|a| matches!(a, Expr::Number(_))) {
        if let (Expr::Number(xc), Expr::Number(yc), Expr::Number(diam)) = 
            (&args[0], &args[1], &args[2]) {
            let mut intensity: i32 = 0x5F;
            if args.len() == 4 {
                if let Expr::Number(i) = &args[3] {
                    intensity = *i;
                }
            }
            
            let segs = 16; // 16-sided polygon approximation (use DRAW_CIRCLE_SEG for more)
            let r = (*diam as f64) / 2.0;
            let mut verts: Vec<(i32, i32)> = Vec::new();
            
            for k in 0..segs {
                let ang = 2.0 * std::f64::consts::PI * (k as f64) / (segs as f64);
                let x = (*xc as f64) + r * ang.cos();
                let y = (*yc as f64) + r * ang.sin();
                verts.push((x.round() as i32, y.round() as i32));
            }
            
            // Emit inline code (like core does)
            out.push_str("    LDA #$D0\n    TFR A,DP\n    JSR Reset0Ref\n    LDA #$80\n    STA <$04\n");
            if intensity == 0x5F {
                out.push_str("    JSR Intensity_5F\n");
            } else {
                out.push_str(&format!("    LDA #${:02X}\n    JSR Intensity_a\n", intensity & 0xFF));
            }
            
            let (sx, sy) = verts[0];
            out.push_str(&format!("    LDA #${:02X}\n    LDB #${:02X}\n    JSR Moveto_d\n", 
                (sy & 0xFF), (sx & 0xFF)));
            
            for i in 0..segs {
                let (x0, y0) = verts[i];
                let (x1, y1) = verts[(i + 1) % segs];
                let dx = (x1 - x0) & 0xFF;
                let dy = (y1 - y0) & 0xFF;
                out.push_str("    CLR Vec_Misc_Count\n");
                out.push_str(&format!("    LDA #${:02X}\n    LDB #${:02X}\n    JSR Draw_Line_d\n", 
                    dy, dx));
            }
            out.push_str("    LDA #$C8\n    TFR A,DP    ; Restore DP=$C8 after circle drawing\n");
            out.push_str("    LDD #0\n    STD RESULT\n");
            return;
        }
    }
    
    // Variables - use runtime helper
    out.push_str("    ; ERROR: DRAW_CIRCLE with variables requires expressions module access\n");
    out.push_str("    ; Use constant values for now\n");
    out.push_str("    LDD #0\n    STD RESULT\n");
}

/// DRAW_RECT(x, y, width, height[, intensity])
pub fn emit_draw_rect(
    args: &[Expr],
    out: &mut String,
) {
    if args.len() != 4 && args.len() != 5 {
        out.push_str("    ; ERROR: DRAW_RECT requires 4 or 5 arguments\n");
        return;
    }
    
    // Check if all args are constants - optimize as 4 inline lines
    if args.iter().all(|a| matches!(a, Expr::Number(_))) {
        if let (Expr::Number(x), Expr::Number(y), Expr::Number(w), Expr::Number(h)) = 
            (&args[0], &args[1], &args[2], &args[3]) {
            let mut intensity: i32 = 0x5F;
            if args.len() == 5 {
                if let Expr::Number(i) = &args[4] {
                    intensity = *i;
                }
            }
            
            // Four corners
            let x0 = *x;
            let y0 = *y;
            let _x1 = x0 + w;  // Calculated but not used directly
            let _y1 = y0 + h;  // Calculated but not used directly
            
            // Emit inline code
            out.push_str("    LDA #$D0\n    TFR A,DP\n    JSR Reset0Ref\n    LDA #$80\n    STA <$04\n");
            if intensity == 0x5F {
                out.push_str("    JSR Intensity_5F\n");
            } else {
                out.push_str(&format!("    LDA #${:02X}\n    JSR Intensity_a\n", intensity & 0xFF));
            }
            
            // Move to start
            out.push_str(&format!("    LDA #${:02X}\n    LDB #${:02X}\n    JSR Moveto_d\n", 
                (y0 & 0xFF), (x0 & 0xFF)));
            
            // Draw 4 sides
            out.push_str("    CLR Vec_Misc_Count\n");
            out.push_str(&format!("    LDA #$00\n    LDB #${:02X}\n    JSR Draw_Line_d\n", 
                (w & 0xFF)));  // Right
            out.push_str("    CLR Vec_Misc_Count\n");
            out.push_str(&format!("    LDA #${:02X}\n    LDB #$00\n    JSR Draw_Line_d\n", 
                (h & 0xFF)));  // Down
            out.push_str("    CLR Vec_Misc_Count\n");
            let neg_w = (-(*w as i32)) & 0xFF;
            out.push_str(&format!("    LDA #$00\n    LDB #${:02X}\n    JSR Draw_Line_d\n", 
                neg_w));  // Left
            out.push_str("    CLR Vec_Misc_Count\n");
            let neg_h = (-(*h as i32)) & 0xFF;
            out.push_str(&format!("    LDA #${:02X}\n    LDB #$00\n    JSR Draw_Line_d\n", 
                neg_h));  // Up
            
            out.push_str("    LDA #$C8\n    TFR A,DP    ; Restore DP=$C8\n");
            out.push_str("    LDD #0\n    STD RESULT\n");
            return;
        }
    }

    // Variables - use runtime helper
    out.push_str("    ; ERROR: DRAW_RECT with variables requires expressions module access\n");
    out.push_str("    ; Use constant values for now\n");
    out.push_str("    LDD #0\n    STD RESULT\n");
}

/// DRAW_POLYGON(N, [intensity,] x0, y0, x1, y1, ..., xN-1, yN-1)
/// Form A: N, x0, y0, ...           (args.len() == 1 + 2*N)
/// Form B: N, intensity, x0, y0, ... (args.len() == 2 + 2*N)
pub fn emit_draw_polygon(
    args: &[Expr],
    out: &mut String,
) {
    if args.len() < 7 {
        out.push_str("    ; ERROR: DRAW_POLYGON requires at least N + 3 vertices (7+ args)\n");
        return;
    }

    // All-constants path
    if args.iter().all(|a| matches!(a, Expr::Number(_))) {
        if let Expr::Number(nv) = &args[0] {
            let n = *nv as usize;
            let form_a_len = 1 + 2 * n;
            let form_b_len = 2 + 2 * n;
            let mut intensity: i32 = 0x5F;
            let (start_index, ok) = if args.len() == form_a_len {
                (1usize, true)
            } else if args.len() == form_b_len {
                if let Expr::Number(iv) = &args[1] { intensity = *iv; }
                (2usize, true)
            } else {
                (0, false)
            };
            if ok && n >= 3 {
                let mut verts: Vec<(i32, i32)> = Vec::new();
                for i in 0..n {
                    if let (Expr::Number(x), Expr::Number(y)) =
                        (&args[start_index + 2 * i], &args[start_index + 2 * i + 1])
                    {
                        verts.push((*x, *y));
                    }
                }
                if verts.len() == n {
                    out.push_str("    LDA #$D0\n    TFR A,DP\n    JSR Reset0Ref\n    LDA #$80\n    STA <$04\n");
                    if intensity == 0x5F {
                        out.push_str("    JSR Intensity_5F\n");
                    } else {
                        out.push_str(&format!("    LDA #${:02X}\n    JSR Intensity_a\n", intensity & 0xFF));
                    }

                    for i in 0..n {
                        let (x0, y0) = verts[i];
                        let (x1, y1) = verts[(i + 1) % n];
                        let dx_total = x1 - x0;
                        let dy_total = y1 - y0;
                        let need_split = dx_total.abs().max(dy_total.abs()) > 127;
                        let (fdx, fdy, sdx, sdy, split) = if need_split {
                            (dx_total / 2, dy_total / 2,
                             dx_total - dx_total / 2, dy_total - dy_total / 2, true)
                        } else {
                            (dx_total, dy_total, 0, 0, false)
                        };
                        if i == 0 {
                            out.push_str(&format!(
                                "    LDA #${:02X}\n    LDB #${:02X}\n    JSR Moveto_d\n",
                                (y0 & 0xFF) as u8, (x0 & 0xFF) as u8
                            ));
                        }
                        out.push_str("    CLR Vec_Misc_Count\n");
                        out.push_str(&format!(
                            "    LDA #${:02X}\n    LDB #${:02X}\n    JSR Draw_Line_d\n",
                            (fdy & 0xFF) as u8, (fdx & 0xFF) as u8
                        ));
                        if split {
                            out.push_str("    CLR Vec_Misc_Count\n");
                            out.push_str(&format!(
                                "    LDA #${:02X}\n    LDB #${:02X}\n    JSR Draw_Line_d\n",
                                (sdy & 0xFF) as u8, (sdx & 0xFF) as u8
                            ));
                        }
                    }
                    out.push_str("    LDA #$C8\n    TFR A,DP    ; Restore DP=$C8\n");
                    out.push_str("    LDD #0\n    STD RESULT\n");
                    return;
                }
            }
        }
    }

    // Variables - TODO: implement runtime helper (complex: requires array handling)
    out.push_str("    ; ERROR: DRAW_POLYGON with variables not yet implemented\n");
    out.push_str("    LDD #0\n    STD RESULT\n");
}

/// DRAW_CIRCLE_SEG(nseg, xc, yc, diam[, intensity]) - Circle with variable segments
pub fn emit_draw_circle_seg(
    args: &[Expr],
    out: &mut String,
) {
    if args.len() != 4 && args.len() != 5 {
        out.push_str("    ; ERROR: DRAW_CIRCLE_SEG requires 4 or 5 arguments\n");
        return;
    }
    
    // Check if all args are constants
    if args.iter().all(|a| matches!(a, Expr::Number(_))) {
        if let (Expr::Number(nseg), Expr::Number(xc), Expr::Number(yc), Expr::Number(diam)) = 
            (&args[0], &args[1], &args[2], &args[3]) {
            let mut intensity: i32 = 0x5F;
            if args.len() == 5 {
                if let Expr::Number(i) = &args[4] {
                    intensity = *i;
                }
            }
            
            let segs = (*nseg).clamp(3, 64) as usize;
            let r = (*diam as f64) / 2.0;
            let mut verts: Vec<(i32, i32)> = Vec::new();
            
            for k in 0..segs {
                let ang = 2.0 * std::f64::consts::PI * (k as f64) / (segs as f64);
                let x = (*xc as f64) + r * ang.cos();
                let y = (*yc as f64) + r * ang.sin();
                verts.push((x.round() as i32, y.round() as i32));
            }
            
            // Emit inline code
            out.push_str("    LDA #$D0\n    TFR A,DP\n    JSR Reset0Ref\n    LDA #$80\n    STA <$04\n");
            if intensity == 0x5F {
                out.push_str("    JSR Intensity_5F\n");
            } else {
                out.push_str(&format!("    LDA #${:02X}\n    JSR Intensity_a\n", intensity & 0xFF));
            }
            
            let (sx, sy) = verts[0];
            out.push_str(&format!("    LDA #${:02X}\n    LDB #${:02X}\n    JSR Moveto_d\n", 
                (sy & 0xFF), (sx & 0xFF)));
            
            for i in 0..segs {
                let (x0, y0) = verts[i];
                let (x1, y1) = verts[(i + 1) % segs];
                let dx = (x1 - x0) & 0xFF;
                let dy = (y1 - y0) & 0xFF;
                out.push_str("    CLR Vec_Misc_Count\n");
                out.push_str(&format!("    LDA #${:02X}\n    LDB #${:02X}\n    JSR Draw_Line_d\n", 
                    dy, dx));
            }
            out.push_str("    LDD #0\n    STD RESULT\n");
            return;
        }
    }
    
    out.push_str("    ; ERROR: DRAW_CIRCLE_SEG with variables not yet implemented\n");
    out.push_str("    LDD #0\n    STD RESULT\n");
}

/// DRAW_ARC(nseg, xc, yc, radius, start_deg, sweep_deg[, intensity]) - Open arc
pub fn emit_draw_arc(
    args: &[Expr],
    out: &mut String,
) {
    if args.len() != 6 && args.len() != 7 {
        out.push_str("    ; ERROR: DRAW_ARC requires 6 or 7 arguments\n");
        return;
    }
    
    // Check if all args are constants
    if args.iter().all(|a| matches!(a, Expr::Number(_))) {
        if let (Expr::Number(nseg), Expr::Number(xc), Expr::Number(yc), 
                Expr::Number(rad), Expr::Number(startd), Expr::Number(sweepd)) = 
            (&args[0], &args[1], &args[2], &args[3], &args[4], &args[5]) {
            let mut intensity: i32 = 0x5F;
            if args.len() == 7 {
                if let Expr::Number(i) = &args[6] {
                    intensity = *i;
                }
            }
            
            let segs = (*nseg).clamp(1, 96) as usize;
            let start = (*startd as f64) * std::f64::consts::PI / 180.0;
            let sweep = (*sweepd as f64) * std::f64::consts::PI / 180.0;
            let r = (*rad as f64).clamp(4.0, 110.0);
            
            let mut verts: Vec<(i32, i32)> = Vec::new();
            for k in 0..=segs {
                let t = k as f64 / segs as f64;
                let ang = start + sweep * t;
                let x = ((*xc as f64) + r * ang.cos()).clamp(-120.0, 120.0);
                let y = ((*yc as f64) + r * ang.sin()).clamp(-120.0, 120.0);
                verts.push((x.round() as i32, y.round() as i32));
            }
            
            // Emit inline code
            out.push_str("    LDA #$D0\n    TFR A,DP\n    JSR Reset0Ref\n    LDA #$80\n    STA <$04\n");
            if intensity == 0x5F {
                out.push_str("    JSR Intensity_5F\n");
            } else {
                out.push_str(&format!("    LDA #${:02X}\n    JSR Intensity_a\n", intensity & 0xFF));
            }
            
            let (sx, sy) = verts[0];
            out.push_str(&format!("    LDA #${:02X}\n    LDB #${:02X}\n    JSR Moveto_d\n", 
                (sy & 0xFF), (sx & 0xFF)));
            
            for i in 0..segs {
                let (x0, y0) = verts[i];
                let (x1, y1) = verts[i + 1];
                let dx = (x1 - x0) & 0xFF;
                let dy = (y1 - y0) & 0xFF;
                out.push_str("    CLR Vec_Misc_Count\n");
                out.push_str(&format!("    LDA #${:02X}\n    LDB #${:02X}\n    JSR Draw_Line_d\n", 
                    dy, dx));
            }
            out.push_str("    LDD #0\n    STD RESULT\n");
            return;
        }
    }
    
    out.push_str("    ; ERROR: DRAW_ARC with variables not yet implemented\n");
    out.push_str("    LDD #0\n    STD RESULT\n");
}

/// DRAW_FILLED_RECT(x, y, width, height[, intensity]) - Filled rectangle with scanlines
pub fn emit_draw_filled_rect(
    args: &[Expr],
    out: &mut String,
) {
    if args.len() != 4 && args.len() != 5 {
        out.push_str("    ; ERROR: DRAW_FILLED_RECT requires 4 or 5 arguments\n");
        return;
    }
    
    // Check if all args are constants
    if args.iter().all(|a| matches!(a, Expr::Number(_))) {
        if let (Expr::Number(x), Expr::Number(y), Expr::Number(w), Expr::Number(h)) = 
            (&args[0], &args[1], &args[2], &args[3]) {
            let mut intensity: i32 = 0x5F;
            if args.len() == 5 {
                if let Expr::Number(i) = &args[4] {
                    intensity = *i;
                }
            }
            
            let x0 = *x;
            let y0 = *y;
            let width = *w;
            let height = *h;
            
            // Emit inline code
            out.push_str("    LDA #$D0\n    TFR A,DP\n    JSR Reset0Ref\n    LDA #$80\n    STA <$04\n");
            if intensity == 0x5F {
                out.push_str("    JSR Intensity_5F\n");
            } else {
                out.push_str(&format!("    LDA #${:02X}\n    JSR Intensity_a\n", intensity & 0xFF));
            }
            
            // Draw horizontal scanlines using relative Moveto_d between lines
            // (absolute Moveto_d per line would accumulate position error)
            let num_lines = height.abs().min(64);
            // First scanline: absolute position from Reset0Ref origin
            out.push_str(&format!("    LDA #${:02X}\n    LDB #${:02X}\n    JSR Moveto_d\n",
                (y0 & 0xFF), (x0 & 0xFF)));
            out.push_str("    CLR Vec_Misc_Count\n");
            out.push_str(&format!("    LDA #$00\n    LDB #${:02X}\n    JSR Draw_Line_d\n",
                (width & 0xFF)));
            // Subsequent scanlines: relative move (dy=±1, dx=-width) from end of previous line
            let dy_step: i32 = if height >= 0 { 1 } else { -1 };
            let neg_w = (-(width as i32)) & 0xFF;
            let dy_byte = (dy_step & 0xFF) as u8;
            for _ in 1..num_lines {
                out.push_str("    CLR Vec_Misc_Count\n");
                out.push_str(&format!("    LDA #${:02X}\n    LDB #${:02X}\n    JSR Moveto_d\n",
                    dy_byte, neg_w as u8));
                out.push_str("    CLR Vec_Misc_Count\n");
                out.push_str(&format!("    LDA #$00\n    LDB #${:02X}\n    JSR Draw_Line_d\n",
                    (width & 0xFF)));
            }
            out.push_str("    LDA #$C8\n    TFR A,DP    ; Restore DP=$C8\n");
            out.push_str("    LDD #0\n    STD RESULT\n");
            return;
        }
    }
    
    out.push_str("    ; ERROR: DRAW_FILLED_RECT with variables not yet implemented\n");
    out.push_str("    LDD #0\n    STD RESULT\n");
}

/// DRAW_ELLIPSE(xc, yc, rx, ry[, intensity]) - Ellipse approximation
pub fn emit_draw_ellipse(
    args: &[Expr],
    out: &mut String,
) {
    if args.len() != 4 && args.len() != 5 {
        out.push_str("    ; ERROR: DRAW_ELLIPSE requires 4 or 5 arguments\n");
        return;
    }
    
    // Check if all args are constants
    if args.iter().all(|a| matches!(a, Expr::Number(_))) {
        if let (Expr::Number(xc), Expr::Number(yc), Expr::Number(rx), Expr::Number(ry)) = 
            (&args[0], &args[1], &args[2], &args[3]) {
            let mut intensity: i32 = 0x5F;
            if args.len() == 5 {
                if let Expr::Number(i) = &args[4] {
                    intensity = *i;
                }
            }
            
            let segs = 24; // 24-sided polygon approximation
            let rx_f = *rx as f64;
            let ry_f = *ry as f64;
            let mut verts: Vec<(i32, i32)> = Vec::new();
            
            for k in 0..segs {
                let ang = 2.0 * std::f64::consts::PI * (k as f64) / (segs as f64);
                let x = (*xc as f64) + rx_f * ang.cos();
                let y = (*yc as f64) + ry_f * ang.sin();
                verts.push((x.round() as i32, y.round() as i32));
            }
            
            // Emit inline code
            out.push_str("    LDA #$D0\n    TFR A,DP\n    JSR Reset0Ref\n    LDA #$80\n    STA <$04\n");
            if intensity == 0x5F {
                out.push_str("    JSR Intensity_5F\n");
            } else {
                out.push_str(&format!("    LDA #${:02X}\n    JSR Intensity_a\n", intensity & 0xFF));
            }
            
            let (sx, sy) = verts[0];
            out.push_str(&format!("    LDA #${:02X}\n    LDB #${:02X}\n    JSR Moveto_d\n", 
                (sy & 0xFF), (sx & 0xFF)));
            
            for i in 0..segs {
                let (x0, y0) = verts[i];
                let (x1, y1) = verts[(i + 1) % segs];
                let dx = (x1 - x0) & 0xFF;
                let dy = (y1 - y0) & 0xFF;
                out.push_str("    CLR Vec_Misc_Count\n");
                out.push_str(&format!("    LDA #${:02X}\n    LDB #${:02X}\n    JSR Draw_Line_d\n", 
                    dy, dx));
            }
            out.push_str("    LDD #0\n    STD RESULT\n");
            return;
        }
    }
    
    out.push_str("    ; ERROR: DRAW_ELLIPSE with variables not yet implemented\n");
    out.push_str("    LDD #0\n    STD RESULT\n");
}

/// DRAW_SPRITE(x, y, sprite_name) - Draw bitmap sprite (placeholder)
pub fn emit_draw_sprite(
    args: &[Expr],
    out: &mut String,
) {
    if args.len() != 3 {
        out.push_str("    ; ERROR: DRAW_SPRITE requires 3 arguments\n");
        return;
    }
    
    // DRAW_SPRITE is complex (requires bitmap data, scanline conversion)
    // For now, placeholder implementation
    out.push_str("    ; TODO: DRAW_SPRITE implementation\n");
    out.push_str("    ; Requires bitmap asset system and raster conversion\n");
    out.push_str("    LDD #0\n    STD RESULT\n");
}

/// Emit runtime helpers for drawing builtins
/// Only emits helpers that are actually used in the code (tree shaking)
pub fn emit_runtime_helpers(out: &mut String, needed: &HashSet<String>) {
    // DRAW_CIRCLE_RUNTIME: Draw circle with runtime parameters
    // Uses 8-segment octagon approximation (simple but effective)
    // Copied verbatim from core/src/backend/m6809/emission.rs
    if needed.contains("DRAW_CIRCLE_RUNTIME") {
        out.push_str(
            "; ============================================================================\n\
        ; DRAW_CIRCLE_RUNTIME - Draw circle with runtime parameters\n\
        ; ============================================================================\n\
        ; Follows Draw_Sync_List_At pattern: read params BEFORE DP change\n\
        ; Inputs: DRAW_CIRCLE_XC, DRAW_CIRCLE_YC, DRAW_CIRCLE_DIAM, DRAW_CIRCLE_INTENSITY (bytes in RAM)\n\
        ; Uses 16-segment polygon (same as constant path) via MUL scaling of fixed fractions\n\
        ; 4 unique delta fractions of radius r (16-gon, vertices at k*22.5 deg):\n\
        ;   a = 0.3827*r (sin22.5) via MUL #98 /256, stored at DRAW_CIRCLE_TEMP+2\n\
        ;   b = 0.3244*r (sin45-sin22.5) via MUL #83 /256, stored at DRAW_CIRCLE_TEMP+3\n\
        ;   c = 0.2168*r via MUL #56 /256, stored at DRAW_CIRCLE_TEMP+4\n\
        ;   d = 0.0761*r via MUL #19 /256, stored at DRAW_CIRCLE_TEMP+5\n\
        ; DRAW_CIRCLE_TEMP layout: [radius16][a][b][c][d][--][--]\n\
        DRAW_CIRCLE_RUNTIME:\n\
        ; Read ALL parameters into registers/stack BEFORE changing DP (critical!)\n\
        ; (These are byte variables, use LDB not LDD)\n\
        LDB DRAW_CIRCLE_INTENSITY\n\
        PSHS B                 ; Save intensity on stack\n\
        \n\
        LDB DRAW_CIRCLE_DIAM\n\
        SEX                    ; Sign-extend to 16-bit (diameter is unsigned 0..255)\n\
        LSRA                   ; Divide by 2 to get radius\n\
        RORB\n\
        STD DRAW_CIRCLE_TEMP   ; DRAW_CIRCLE_TEMP = radius (16-bit, big-endian: +0=hi, +1=lo)\n\
        \n\
        LDB DRAW_CIRCLE_XC     ; xc (signed -128..127)\n\
        SEX\n\
        STD DRAW_CIRCLE_TEMP+2 ; Save xc (16-bit, reused for 'a' after Moveto)\n\
        \n\
        LDB DRAW_CIRCLE_YC     ; yc (signed -128..127)\n\
        SEX\n\
        STD DRAW_CIRCLE_TEMP+4 ; Save yc (16-bit, reused for 'c' after Moveto)\n\
        \n\
        ; NOW safe to setup BIOS (all params are in DRAW_CIRCLE_TEMP+stack)\n\
        LDA #$D0\n\
        TFR A,DP\n\
        JSR Reset0Ref\n\
        LDA #$80\n\
        STA <$04           ; VIA_t1_cnt_lo = $80 (ensure correct scale)\n\
        \n\
        ; Set intensity (from stack)\n\
        PULS A                 ; Get intensity from stack\n\
        CMPA #$5F\n\
        BEQ DCR_intensity_5F\n\
        JSR Intensity_a\n\
        BRA DCR_after_intensity\n\
DCR_intensity_5F:\n\
        JSR Intensity_5F\n\
DCR_after_intensity:\n\
        \n\
        ; Move to start position: (xc + radius, yc)  [vertex 0 of 16-gon = rightmost]\n\
        ; radius = DRAW_CIRCLE_TEMP, xc = DRAW_CIRCLE_TEMP+2, yc = DRAW_CIRCLE_TEMP+4\n\
        LDD DRAW_CIRCLE_TEMP   ; D = radius (16-bit)\n\
        ADDD DRAW_CIRCLE_TEMP+2 ; D = xc + radius\n\
        TFR B,B                ; Keep X in B (low byte)\n\
        PSHS B                 ; Save X on stack\n\
        LDD DRAW_CIRCLE_TEMP+4 ; Load yc\n\
        TFR B,A                ; Y to A\n\
        PULS B                 ; X to B\n\
        JSR Moveto_d\n\
        \n\
        ; Precompute 4 delta fractions using MUL (same fractions as constant 16-gon path)\n\
        ; radius is at DRAW_CIRCLE_TEMP+1 (low byte, 0..127)\n\
        ; DRAW_CIRCLE_TEMP+2..5 now free to reuse for a,b,c,d\n\
        ; MUL: A * B -> D (unsigned); A_after = floor(frac * r) when frac byte = round(frac*256)\n\
        LDB DRAW_CIRCLE_TEMP+1 ; radius\n\
        LDA #98                ; 98/256 = 0.3828 ~ sin(22.5 deg) = 0.3827\n\
        MUL                    ; A = floor(0.3828 * r) = a\n\
        STA DRAW_CIRCLE_TEMP+2 ; Store a\n\
        LDB DRAW_CIRCLE_TEMP+1 ; radius\n\
        LDA #83                ; 83/256 = 0.3242 ~ 0.3244\n\
        MUL                    ; A = b\n\
        STA DRAW_CIRCLE_TEMP+3 ; Store b\n\
        LDB DRAW_CIRCLE_TEMP+1 ; radius\n\
        LDA #56                ; 56/256 = 0.2188 ~ 0.2168\n\
        MUL                    ; A = c\n\
        STA DRAW_CIRCLE_TEMP+4 ; Store c\n\
        LDB DRAW_CIRCLE_TEMP+1 ; radius\n\
        LDA #19                ; 19/256 = 0.0742 ~ 0.0761\n\
        MUL                    ; A = d\n\
        STA DRAW_CIRCLE_TEMP+5 ; Store d\n\
        \n\
        ; Draw 16 unrolled segments - 16-gon counterclockwise from (xc+r, yc)\n\
        ; Draw_Line_d(A=dy, B=dx). Symmetry pattern by quadrant:\n\
        ;   Q1 (0->90):   (+a,-d), (+b,-c), (+c,-b), (+d,-a)\n\
        ;   Q2 (90->180): (-d,-a), (-c,-b), (-b,-c), (-a,-d)\n\
        ;   Q3 (180->270):(-a,+d), (-b,+c), (-c,+b), (-d,+a)\n\
        ;   Q4 (270->360):(+d,+a), (+c,+b), (+b,+c), (+a,+d)\n\
        \n\
        ; --- Q1 ---\n\
        ; Seg 0: dy=+a, dx=-d\n\
        CLR Vec_Misc_Count\n\
        LDA DRAW_CIRCLE_TEMP+2  ; a\n\
        LDB DRAW_CIRCLE_TEMP+5  ; d\n\
        NEGB\n\
        JSR Draw_Line_d\n\
        ; Seg 1: dy=+b, dx=-c\n\
        CLR Vec_Misc_Count\n\
        LDA DRAW_CIRCLE_TEMP+3  ; b\n\
        LDB DRAW_CIRCLE_TEMP+4  ; c\n\
        NEGB\n\
        JSR Draw_Line_d\n\
        ; Seg 2: dy=+c, dx=-b\n\
        CLR Vec_Misc_Count\n\
        LDA DRAW_CIRCLE_TEMP+4  ; c\n\
        LDB DRAW_CIRCLE_TEMP+3  ; b\n\
        NEGB\n\
        JSR Draw_Line_d\n\
        ; Seg 3: dy=+d, dx=-a\n\
        CLR Vec_Misc_Count\n\
        LDA DRAW_CIRCLE_TEMP+5  ; d\n\
        LDB DRAW_CIRCLE_TEMP+2  ; a\n\
        NEGB\n\
        JSR Draw_Line_d\n\
        \n\
        ; --- Q2 ---\n\
        ; Seg 4: dy=-d, dx=-a\n\
        CLR Vec_Misc_Count\n\
        LDA DRAW_CIRCLE_TEMP+5  ; d\n\
        NEGA\n\
        LDB DRAW_CIRCLE_TEMP+2  ; a\n\
        NEGB\n\
        JSR Draw_Line_d\n\
        ; Seg 5: dy=-c, dx=-b\n\
        CLR Vec_Misc_Count\n\
        LDA DRAW_CIRCLE_TEMP+4  ; c\n\
        NEGA\n\
        LDB DRAW_CIRCLE_TEMP+3  ; b\n\
        NEGB\n\
        JSR Draw_Line_d\n\
        ; Seg 6: dy=-b, dx=-c\n\
        CLR Vec_Misc_Count\n\
        LDA DRAW_CIRCLE_TEMP+3  ; b\n\
        NEGA\n\
        LDB DRAW_CIRCLE_TEMP+4  ; c\n\
        NEGB\n\
        JSR Draw_Line_d\n\
        ; Seg 7: dy=-a, dx=-d\n\
        CLR Vec_Misc_Count\n\
        LDA DRAW_CIRCLE_TEMP+2  ; a\n\
        NEGA\n\
        LDB DRAW_CIRCLE_TEMP+5  ; d\n\
        NEGB\n\
        JSR Draw_Line_d\n\
        \n\
        ; --- Q3 ---\n\
        ; Seg 8: dy=-a, dx=+d\n\
        CLR Vec_Misc_Count\n\
        LDA DRAW_CIRCLE_TEMP+2  ; a\n\
        NEGA\n\
        LDB DRAW_CIRCLE_TEMP+5  ; d (positive)\n\
        JSR Draw_Line_d\n\
        ; Seg 9: dy=-b, dx=+c\n\
        CLR Vec_Misc_Count\n\
        LDA DRAW_CIRCLE_TEMP+3  ; b\n\
        NEGA\n\
        LDB DRAW_CIRCLE_TEMP+4  ; c (positive)\n\
        JSR Draw_Line_d\n\
        ; Seg 10: dy=-c, dx=+b\n\
        CLR Vec_Misc_Count\n\
        LDA DRAW_CIRCLE_TEMP+4  ; c\n\
        NEGA\n\
        LDB DRAW_CIRCLE_TEMP+3  ; b (positive)\n\
        JSR Draw_Line_d\n\
        ; Seg 11: dy=-d, dx=+a\n\
        CLR Vec_Misc_Count\n\
        LDA DRAW_CIRCLE_TEMP+5  ; d\n\
        NEGA\n\
        LDB DRAW_CIRCLE_TEMP+2  ; a (positive)\n\
        JSR Draw_Line_d\n\
        \n\
        ; --- Q4 ---\n\
        ; Seg 12: dy=+d, dx=+a\n\
        CLR Vec_Misc_Count\n\
        LDA DRAW_CIRCLE_TEMP+5  ; d (positive)\n\
        LDB DRAW_CIRCLE_TEMP+2  ; a (positive)\n\
        JSR Draw_Line_d\n\
        ; Seg 13: dy=+c, dx=+b\n\
        CLR Vec_Misc_Count\n\
        LDA DRAW_CIRCLE_TEMP+4  ; c (positive)\n\
        LDB DRAW_CIRCLE_TEMP+3  ; b (positive)\n\
        JSR Draw_Line_d\n\
        ; Seg 14: dy=+b, dx=+c\n\
        CLR Vec_Misc_Count\n\
        LDA DRAW_CIRCLE_TEMP+3  ; b (positive)\n\
        LDB DRAW_CIRCLE_TEMP+4  ; c (positive)\n\
        JSR Draw_Line_d\n\
        ; Seg 15: dy=+a, dx=+d\n\
        CLR Vec_Misc_Count\n\
        LDA DRAW_CIRCLE_TEMP+2  ; a (positive)\n\
        LDB DRAW_CIRCLE_TEMP+5  ; d (positive)\n\
        JSR Draw_Line_d\n\
        \n\
        LDA #$C8\n\
        TFR A,DP           ; Restore DP=$C8 before return\n\
        RTS\n\
        \n"
        );
    }

    // DRAW_RECT_RUNTIME: Draw rectangle with runtime parameters
    if needed.contains("DRAW_RECT_RUNTIME") {
        out.push_str("DRAW_RECT_RUNTIME:\n");
        out.push_str("    ; Input: DRAW_RECT_X, DRAW_RECT_Y, DRAW_RECT_WIDTH, DRAW_RECT_HEIGHT, DRAW_RECT_INTENSITY\n");
        out.push_str("    ; Draws 4 sides of rectangle\n");
        out.push_str("    \n");
        out.push_str("    ; Save parameters to stack before DP change\n");
        out.push_str("    LDB DRAW_RECT_INTENSITY\n");
        out.push_str("    PSHS B\n");
        out.push_str("    LDB DRAW_RECT_HEIGHT\n");
        out.push_str("    PSHS B\n");
        out.push_str("    LDB DRAW_RECT_WIDTH\n");
        out.push_str("    PSHS B\n");
        out.push_str("    LDB DRAW_RECT_Y\n");
        out.push_str("    PSHS B\n");
        out.push_str("    LDB DRAW_RECT_X\n");
        out.push_str("    PSHS B\n");
        out.push_str("    \n");
        out.push_str("    ; Setup BIOS\n");
        out.push_str("    LDA #$D0\n");
        out.push_str("    TFR A,DP\n");
        out.push_str("    JSR Reset0Ref\n");
        out.push_str("    LDA #$80\n");
        out.push_str("    STA <$04            ; VIA_t1_cnt_lo = $80 (ensure correct scale)\n");
        out.push_str("    \n");
        out.push_str("    ; Set intensity\n");
        out.push_str("    LDA 4,S             ; intensity\n");
        out.push_str("    JSR Intensity_a\n");
        out.push_str("    \n");
        out.push_str("    ; Move to starting position (x, y)\n");
        out.push_str("    LDA 1,S             ; y\n");
        out.push_str("    LDB ,S              ; x\n");
        out.push_str("    JSR Moveto_d_7F\n");
        out.push_str("    \n");
        out.push_str("    ; Draw right side\n");
        out.push_str("    CLR Vec_Misc_Count\n");
        out.push_str("    LDA #0\n");
        out.push_str("    LDB 2,S             ; width\n");
        out.push_str("    JSR Draw_Line_d\n");
        out.push_str("    \n");
        out.push_str("    ; Draw down side\n");
        out.push_str("    CLR Vec_Misc_Count\n");
        out.push_str("    LDA 3,S             ; height\n");
        out.push_str("    NEGA                ; -height\n");
        out.push_str("    LDB #0\n");
        out.push_str("    JSR Draw_Line_d\n");
        out.push_str("    \n");
        out.push_str("    ; Draw left side\n");
        out.push_str("    CLR Vec_Misc_Count\n");
        out.push_str("    LDA #0\n");
        out.push_str("    LDB 2,S             ; width\n");
        out.push_str("    NEGB                ; -width\n");
        out.push_str("    JSR Draw_Line_d\n");
        out.push_str("    \n");
        out.push_str("    ; Draw up side\n");
        out.push_str("    CLR Vec_Misc_Count\n");
        out.push_str("    LDA 2,S             ; height\n");
        out.push_str("    NEGA                ; -height\n");
        out.push_str("    LDB #0\n");
        out.push_str("    JSR Draw_Line_d\n");
        out.push_str("    \n");
        out.push_str("    LDA #$C8\n");
        out.push_str("    TFR A,DP            ; Restore DP=$C8 before return\n");
        out.push_str("    LEAS 5,S            ; Clean stack\n");
        out.push_str("    RTS\n\n");
    }

    // DRAW_LINE_WRAPPER: Only emit if DRAW_LINE is used
    // CRITICAL FIX (2026-01-18): Copy exact implementation from core
    // The previous version was missing DP setup ($D0 for BIOS) and VIA_cntl initialization
    // Without DP=$D0, Intensity_a and Moveto_d write to wrong memory locations
    // FIX 2026-01-19: Use extended addressing (>) for ALL RAM accesses when DP=$D0
    if needed.contains("DRAW_LINE_WRAPPER") {
        out.push_str("; DRAW_LINE unified wrapper - handles 16-bit signed coordinates\n");
        out.push_str("; Args: DRAW_LINE_ARGS+0=x0, +2=y0, +4=x1, +6=y1, +8=intensity\n");
        out.push_str("; Resets beam to center, moves to (x0,y0), draws to (x1,y1)\n");
        out.push_str("DRAW_LINE_WRAPPER:\n");
        out.push_str("    ; Set DP to hardware registers\n");
        out.push_str("    LDA #$D0\n");
        out.push_str("    TFR A,DP\n");
        out.push_str("    JSR Reset0Ref   ; Reset beam to center (0,0) before positioning\n");
        out.push_str("    LDA #$80\n");
        out.push_str("    STA <$04        ; VIA_t1_cnt_lo = $80 (ensure correct scale regardless of prior builtins)\n");

        // Set intensity and move to start - USE EXTENDED ADDRESSING (>)
        out.push_str("    ; ALWAYS set intensity (no optimization)\n");
        out.push_str("    LDA >DRAW_LINE_ARGS+8+1  ; intensity (low byte) - EXTENDED addressing\n");
        out.push_str("    JSR Intensity_a\n");
        out.push_str("    ; Move to start position (y in A, x in B) - use low bytes (8-bit signed -127..+127)\n");
        out.push_str("    LDA >DRAW_LINE_ARGS+2+1  ; Y start (low byte) - EXTENDED addressing\n");
        out.push_str("    ADDA >VPY_MOVE_Y         ; Add MOVE Y offset\n");
        out.push_str("    LDB >DRAW_LINE_ARGS+0+1  ; X start (low byte) - EXTENDED addressing\n");
        out.push_str("    ADDB >VPY_MOVE_X         ; Add MOVE X offset\n");
        out.push_str("    JSR Moveto_d\n");
        
        // Compute deltas - USE EXTENDED ADDRESSING (>)
        out.push_str("    ; Compute deltas using 16-bit arithmetic\n");
        out.push_str("    ; dx = x1 - x0 (treating as signed 16-bit)\n");
        out.push_str("    LDD >DRAW_LINE_ARGS+4    ; x1 (16-bit) - EXTENDED\n");
        out.push_str("    SUBD >DRAW_LINE_ARGS+0   ; subtract x0 (16-bit) - EXTENDED\n");
        out.push_str("    STD >VLINE_DX_16 ; Store full 16-bit dx - EXTENDED\n");
        out.push_str("    ; dy = y1 - y0 (treating as signed 16-bit)\n");
        out.push_str("    LDD >DRAW_LINE_ARGS+6    ; y1 (16-bit) - EXTENDED\n");
        out.push_str("    SUBD >DRAW_LINE_ARGS+2   ; subtract y0 (16-bit) - EXTENDED\n");
        out.push_str("    STD >VLINE_DY_16 ; Store full 16-bit dy - EXTENDED\n");
        
        // SEGMENT 1: Clamp and draw first segment - USE EXTENDED ADDRESSING
        out.push_str("    ; SEGMENT 1: Clamp dy to ±127 and draw\n");
        out.push_str("    LDD >VLINE_DY_16 ; Load full dy - EXTENDED\n");
        out.push_str("    CMPD #127\n");
        out.push_str("    BLE DLW_SEG1_DY_LO\n");
        out.push_str("    LDA #127        ; dy > 127: use 127\n");
        out.push_str("    BRA DLW_SEG1_DY_READY\n");
        out.push_str("DLW_SEG1_DY_LO:\n");
        out.push_str("    CMPD #-128\n");
        out.push_str("    BGE DLW_SEG1_DY_NO_CLAMP  ; -128 <= dy <= 127: use original (sign-extended)\n");
        out.push_str("    LDA #$80        ; dy < -128: use -128\n");
        out.push_str("    BRA DLW_SEG1_DY_READY\n");
        out.push_str("DLW_SEG1_DY_NO_CLAMP:\n");
        out.push_str("    LDA >VLINE_DY_16+1  ; Use original low byte - EXTENDED\n");
        out.push_str("DLW_SEG1_DY_READY:\n");
        out.push_str("    STA >VLINE_DY    ; Save clamped dy for segment 1 - EXTENDED\n");
        
        // Clamp dx for segment 1 - USE EXTENDED ADDRESSING
        out.push_str("    ; Clamp dx to ±127\n");
        out.push_str("    LDD >VLINE_DX_16  ; EXTENDED\n");
        out.push_str("    CMPD #127\n");
        out.push_str("    BLE DLW_SEG1_DX_LO\n");
        out.push_str("    LDB #127        ; dx > 127: use 127\n");
        out.push_str("    BRA DLW_SEG1_DX_READY\n");
        out.push_str("DLW_SEG1_DX_LO:\n");
        out.push_str("    CMPD #-128\n");
        out.push_str("    BGE DLW_SEG1_DX_NO_CLAMP  ; -128 <= dx <= 127: use original (sign-extended)\n");
        out.push_str("    LDB #$80        ; dx < -128: use -128\n");
        out.push_str("    BRA DLW_SEG1_DX_READY\n");
        out.push_str("DLW_SEG1_DX_NO_CLAMP:\n");
        out.push_str("    LDB >VLINE_DX_16+1  ; Use original low byte - EXTENDED\n");
        out.push_str("DLW_SEG1_DX_READY:\n");
        out.push_str("    STB >VLINE_DX    ; Save clamped dx for segment 1 - EXTENDED\n");
        
        // Draw segment 1 - USE EXTENDED ADDRESSING
        out.push_str("    ; Draw segment 1\n");
        out.push_str("    CLR Vec_Misc_Count\n");
        out.push_str("    LDA >VLINE_DY  ; EXTENDED\n");
        out.push_str("    LDB >VLINE_DX  ; EXTENDED\n");
        out.push_str("    JSR Draw_Line_d ; Beam moves automatically\n");
        
        // Check if we need segment 2 - for dy OR dx outside ±127/±128 range
        out.push_str("    ; Check if we need SEGMENT 2 (dy OR dx outside ±127 range)\n");
        out.push_str("    LDD >VLINE_DY_16 ; Reload original dy - EXTENDED\n");
        out.push_str("    CMPD #127\n");
        out.push_str("    BGT DLW_NEED_SEG2  ; dy > 127: needs segment 2\n");
        out.push_str("    CMPD #-128\n");
        out.push_str("    BLT DLW_NEED_SEG2  ; dy < -128: needs segment 2\n");
        out.push_str("    LDD >VLINE_DX_16 ; Also check dx - EXTENDED\n");
        out.push_str("    CMPD #127\n");
        out.push_str("    BGT DLW_NEED_SEG2  ; dx > 127: needs segment 2\n");
        out.push_str("    CMPD #-128\n");
        out.push_str("    BLT DLW_NEED_SEG2  ; dx < -128: needs segment 2\n");
        out.push_str("    BRA DLW_DONE       ; both dy and dx in range: no segment 2\n");
        out.push_str("DLW_NEED_SEG2:\n");
        
        // SEGMENT 2: Handle remaining dy AND dx - USE EXTENDED ADDRESSING
        out.push_str("    ; SEGMENT 2: Draw remaining dy and dx\n");
        out.push_str("    ; Calculate remaining dy\n");
        out.push_str("    LDD >VLINE_DY_16 ; Load original full dy - EXTENDED\n");
        out.push_str("    CMPD #127\n");
        out.push_str("    BGT DLW_SEG2_DY_POS  ; dy > 127: remaining = dy - 127\n");
        out.push_str("    CMPD #-128\n");
        out.push_str("    BGE DLW_SEG2_DY_NO_REMAIN  ; -128 <= dy <= 127: no remaining dy\n");
        out.push_str("    ; dy < -128, so we drew -128 in segment 1\n");
        out.push_str("    ; remaining = dy - (-128) = dy + 128\n");
        out.push_str("    ADDD #128       ; Add back the -128 we already drew\n");
        out.push_str("    BRA DLW_SEG2_DY_DONE\n");
        out.push_str("DLW_SEG2_DY_NO_REMAIN:\n");
        out.push_str("    LDD #0          ; dy in range: no remaining\n");
        out.push_str("    BRA DLW_SEG2_DY_DONE\n");
        out.push_str("DLW_SEG2_DY_POS:\n");
        out.push_str("    ; dy > 127, so we drew 127 in segment 1\n");
        out.push_str("    ; remaining = dy - 127\n");
        out.push_str("    SUBD #127       ; Subtract 127 we already drew\n");
        out.push_str("DLW_SEG2_DY_DONE:\n");
        out.push_str("    STD >VLINE_DY_REMAINING  ; Store remaining dy (16-bit) - EXTENDED\n");
        
        // Also calculate remaining dx - USE EXTENDED ADDRESSING
        out.push_str("    ; Calculate remaining dx\n");
        out.push_str("    LDD >VLINE_DX_16 ; Load original full dx - EXTENDED\n");
        out.push_str("    CMPD #127\n");
        out.push_str("    BLE DLW_SEG2_DX_CHECK_NEG\n");
        out.push_str("    ; dx > 127, so we drew 127 in segment 1\n");
        out.push_str("    ; remaining = dx - 127\n");
        out.push_str("    SUBD #127\n");
        out.push_str("    BRA DLW_SEG2_DX_DONE\n");
        out.push_str("DLW_SEG2_DX_CHECK_NEG:\n");
        out.push_str("    CMPD #-128\n");
        out.push_str("    BGE DLW_SEG2_DX_NO_REMAIN  ; -128 <= dx <= 127: no remaining dx\n");
        out.push_str("    ; dx < -128, so we drew -128 in segment 1\n");
        out.push_str("    ; remaining = dx - (-128) = dx + 128\n");
        out.push_str("    ADDD #128\n");
        out.push_str("    BRA DLW_SEG2_DX_DONE\n");
        out.push_str("DLW_SEG2_DX_NO_REMAIN:\n");
        out.push_str("    LDD #0          ; No remaining dx\n");
        out.push_str("DLW_SEG2_DX_DONE:\n");
        out.push_str("    STD >VLINE_DX_REMAINING  ; Store remaining dx (16-bit) - EXTENDED\n");
        
        // Draw segment 2 with both remaining dx and dy - USE EXTENDED ADDRESSING
        out.push_str("    ; Setup for Draw_Line_d: A=dy, B=dx (CRITICAL: order matters!)\n");
        out.push_str("    LDA >VLINE_DY_REMAINING+1  ; Low byte of remaining dy - EXTENDED\n");
        out.push_str("    LDB >VLINE_DX_REMAINING+1  ; Low byte of remaining dx - EXTENDED\n");
        out.push_str("    CLR Vec_Misc_Count\n");
        out.push_str("    JSR Draw_Line_d ; Beam continues from segment 1 endpoint\n");
        
        // Cleanup
        out.push_str("DLW_DONE:\n");
        out.push_str("    LDA #$C8       ; CRITICAL: Restore DP to $C8 for our code\n");
        out.push_str("    TFR A,DP\n");
        out.push_str("    RTS\n\n");
    }
    
    // Draw_Sync_List_At_With_Mirrors - CRITICAL FOR DRAW_VECTOR
    // Only emit if DRAW_VECTOR or DRAW_VECTOR_EX is used
    // COPY-PASTE FROM core/src/backend/m6809/emission.rs lines 1136-1315
    if needed.contains("DRAW_VECTOR") || needed.contains("DRAW_VECTOR_EX") {
        out.push_str(
            "Draw_Sync_List_At_With_Mirrors:\n\
        ; Unified mirror support using flags: MIRROR_X and MIRROR_Y\n\
            ; Conditionally negates X and/or Y coordinates and deltas\n\
            ; NOTE: Caller must ensure DP=$D0 for VIA access\n\
            ; CRITICAL: Do NOT call JSR $F2AB (Intensity_a) here! With DP=$D0,\n\
            ; Intensity_a does STA <$32 which hits $D032 = VIA DDRB (reg $02),\n\
            ; setting PB0 as input and breaking the X/Y integrator mux entirely.\n\
            ; Fix: write Vec_Misc_Count ($C832) directly via extended addressing.\n\
            LDA >DRAW_VEC_INTENSITY ; Check if intensity override is set\n\
            BNE DSWM_USE_OVERRIDE   ; If non-zero, use override\n\
            LDA ,X+                 ; Otherwise, read intensity from vector data\n\
            BRA DSWM_SET_INTENSITY\n\
DSWM_USE_OVERRIDE:\n\
            LEAX 1,X                ; Skip intensity byte in vector data\n\
DSWM_SET_INTENSITY:\n\
            STA >$C832              ; Set Vec_Misc_Count directly (DP-safe, no DDRB corruption)\n\
            LDB ,X+                 ; y_start from .vec (already relative to center)\n\
            ; Check if Y mirroring is enabled\n\
            TST >MIRROR_Y\n\
            BEQ DSWM_NO_NEGATE_Y\n\
            NEGB                    ; ← Negate Y if flag set\n\
DSWM_NO_NEGATE_Y:\n\
            ADDB >DRAW_VEC_Y        ; Add Y offset\n\
            LDA ,X+                 ; x_start from .vec (already relative to center)\n\
            ; Check if X mirroring is enabled\n\
            TST >MIRROR_X\n\
            BEQ DSWM_NO_NEGATE_X\n\
            NEGA                    ; ← Negate X if flag set\n\
DSWM_NO_NEGATE_X:\n\
            ADDA >DRAW_VEC_X        ; Add X offset\n\
            STD >TEMP_YX            ; Save adjusted position\n\
            ; Reset completo\n\
            CLR VIA_shift_reg\n\
            LDA #$CC\n\
            STA VIA_cntl\n\
            CLR VIA_port_a\n\
            LDA #$03\n\
            STA VIA_port_b          ; PB=$03: disable mux (Reset_Pen step 1)\n\
            LDA #$02\n\
            STA VIA_port_b          ; PB=$02: enable mux (Reset_Pen step 2)\n\
            LDA #$02\n\
            STA VIA_port_b          ; repeat\n\
            LDA #$01\n\
            STA VIA_port_b          ; PB=$01: disable mux (integrators zeroed)\n\
            ; Moveto (BIOS Moveto_d: Y->PA, CLR PB, settle, #CE, CLR SR, INC PB, X->PA)\n\
            LDD >TEMP_YX\n\
            STB VIA_port_a          ; Y to DAC (PB=1: integrators hold)\n\
            CLR VIA_port_b          ; PB=0: enable mux, beam tracks Y\n\
            PSHS A                  ; ~4 cycle settling delay for Y\n\
            LDA #$CE\n\
            STA VIA_cntl            ; PCR=$CE: /ZERO high, integrators active\n\
            CLR VIA_shift_reg       ; SR=0: no draw during moveto\n\
            INC VIA_port_b          ; PB=1: disable mux, lock direction at Y\n\
            PULS A                  ; Restore X\n\
            STA VIA_port_a          ; X to DAC\n\
            ; Timing setup: use Vec_Misc_Count ($C832) so per-path intensity from .vec is honoured\n\
            LDA >$C832\n\
            STA VIA_t1_cnt_lo\n\
            CLR VIA_t1_cnt_hi\n\
            LEAX 2,X                ; Skip next_y, next_x\n\
            ; Wait for move to complete (PB=1 on exit)\n\
            DSWM_W1:\n\
            LDA VIA_int_flags\n\
            ANDA #$40\n\
            BEQ DSWM_W1\n\
            ; PB stays 1 — draw loop begins with PB=1\n\
            ; Loop de dibujo (conditional mirrors)\n\
            DSWM_LOOP:\n\
            LDA ,X+                 ; Read flag\n\
            CMPA #2                 ; Check end marker\n\
            LBEQ DSWM_DONE\n\
            CMPA #1                 ; Check next path marker\n\
            LBEQ DSWM_NEXT_PATH\n\
            ; Draw line with conditional negations\n\
            LDB ,X+                 ; dy\n\
            ; Check if Y mirroring is enabled\n\
            TST >MIRROR_Y\n\
            BEQ DSWM_NO_NEGATE_DY\n\
            NEGB                    ; ← Negate dy if flag set\n\
DSWM_NO_NEGATE_DY:\n\
            LDA ,X+                 ; dx\n\
            ; Check if X mirroring is enabled\n\
            TST >MIRROR_X\n\
            BEQ DSWM_NO_NEGATE_DX\n\
            NEGA                    ; ← Negate dx if flag set\n\
DSWM_NO_NEGATE_DX:\n\
            ; B=DY_final, A=DX_final, PB=1 on entry (from moveto or previous segment)\n\
            STB VIA_port_a          ; DY to DAC (PB=1: integrators hold position)\n\
            CLR VIA_port_b          ; PB=0: enable mux, beam tracks DY direction\n\
            NOP                     ; settling 1 (per BIOS Draw_Line_d: LEAX+NOP = ~7 cycles)\n\
            NOP                     ; settling 2\n\
            NOP                     ; settling 3\n\
            INC VIA_port_b          ; PB=1: disable mux, lock direction at DY\n\
            STA VIA_port_a          ; DX to DAC\n\
            LDA #$FF\n\
            STA VIA_shift_reg       ; beam ON first (ramp still off from T1PB7)\n\
            CLR VIA_t1_cnt_hi       ; THEN start T1 -> ramp ON (BIOS order)\n\
            ; Wait for line draw\n\
            DSWM_W2:\n\
            LDA VIA_int_flags\n\
            ANDA #$40\n\
            BEQ DSWM_W2\n\
            CLR VIA_shift_reg       ; beam off (PB stays 1 for next segment)\n\
            LBRA DSWM_LOOP          ; Long branch\n\
            ; Next path: repeat mirror logic for new path header\n\
            DSWM_NEXT_PATH:\n\
            TFR X,D\n\
            PSHS D\n\
            ; Check intensity override (same logic as start)\n\
            LDA >DRAW_VEC_INTENSITY ; Check if intensity override is set\n\
            BNE DSWM_NEXT_USE_OVERRIDE   ; If non-zero, use override\n\
            LDA ,X+                 ; Otherwise, read intensity from vector data\n\
            BRA DSWM_NEXT_SET_INTENSITY\n\
DSWM_NEXT_USE_OVERRIDE:\n\
            LEAX 1,X                ; Skip intensity byte in vector data\n\
DSWM_NEXT_SET_INTENSITY:\n\
            PSHS A\n\
            LDB ,X+                 ; y_start\n\
            TST >MIRROR_Y\n\
            BEQ DSWM_NEXT_NO_NEGATE_Y\n\
            NEGB\n\
DSWM_NEXT_NO_NEGATE_Y:\n\
            ADDB >DRAW_VEC_Y        ; Add Y offset\n\
            LDA ,X+                 ; x_start\n\
            TST >MIRROR_X\n\
            BEQ DSWM_NEXT_NO_NEGATE_X\n\
            NEGA\n\
DSWM_NEXT_NO_NEGATE_X:\n\
            ADDA >DRAW_VEC_X        ; Add X offset\n\
            STD >TEMP_YX\n\
            PULS A                  ; Get intensity back\n\
            STA >$C832              ; Set Vec_Misc_Count directly (DP-safe, no DDRB corruption)\n\
            PULS D\n\
            ADDD #3\n\
            TFR D,X\n\
            ; Reset to zero\n\
            CLR VIA_shift_reg\n\
            LDA #$CC\n\
            STA VIA_cntl\n\
            CLR VIA_port_a\n\
            LDA #$03\n\
            STA VIA_port_b          ; PB=$03: disable mux (Reset_Pen step 1)\n\
            LDA #$02\n\
            STA VIA_port_b          ; PB=$02: enable mux (Reset_Pen step 2)\n\
            LDA #$02\n\
            STA VIA_port_b          ; repeat\n\
            LDA #$01\n\
            STA VIA_port_b          ; PB=$01: disable mux (integrators zeroed)\n\
            ; Moveto new start position (BIOS Moveto_d order)\n\
            LDD >TEMP_YX\n\
            STB VIA_port_a          ; Y to DAC (PB=1: integrators hold)\n\
            CLR VIA_port_b          ; PB=0: enable mux, beam tracks Y\n\
            PSHS A                  ; ~4 cycle settling delay for Y\n\
            LDA #$CE\n\
            STA VIA_cntl            ; PCR=$CE: /ZERO high, integrators active\n\
            CLR VIA_shift_reg       ; SR=0: no draw during moveto\n\
            INC VIA_port_b          ; PB=1: disable mux, lock direction at Y\n\
            PULS A\n\
            STA VIA_port_a          ; X to DAC\n\
            LDA >$C832              ; Use Vec_Misc_Count so per-path intensity is honoured\n\
            STA VIA_t1_cnt_lo\n\
            CLR VIA_t1_cnt_hi\n\
            LEAX 2,X\n\
            ; Wait for move (PB=1 on exit)\n\
            DSWM_W3:\n\
            LDA VIA_int_flags\n\
            ANDA #$40\n\
            BEQ DSWM_W3\n\
            ; PB stays 1 — draw loop continues with PB=1\n\
            LBRA DSWM_LOOP          ; Long branch\n\
            DSWM_DONE:\n\
            RTS\n"
        );
    }
}
