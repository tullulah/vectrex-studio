// Statements - Statement code generation for M6809 backend
use crate::ast::{AssignTarget, Expr, Stmt};
use crate::codegen::CodegenOptions;
use super::{LoopCtx, FuncCtx, emit_expr, emit_builtin_call, fresh_label, LineTracker};

pub fn emit_stmt(stmt: &Stmt, out: &mut String, loop_ctx: &LoopCtx, fctx: &FuncCtx, string_map: &std::collections::BTreeMap<String,String>, opts: &CodegenOptions, tracker: &mut LineTracker, depth: usize) {
    // Safety: Prevent stack overflow with deep recursion
    const MAX_DEPTH: usize = 500;
    if depth > MAX_DEPTH {
        panic!("Maximum statement nesting depth ({}) exceeded. Please simplify your code or split into smaller functions.", MAX_DEPTH);
    }
    
    // ✅ CRITICAL: Record source line BEFORE emitting code
    let line = stmt.source_line();
    tracker.set_line(line);
    
    // Emit line marker comment for ASM parsing to reconstruct accurate lineMap
    out.push_str(&format!("    ; VPy_LINE:{}\n", line));
    
    match stmt {
        Stmt::Assign { target, value, .. } => {
            match target {
                crate::ast::AssignTarget::Ident { name, .. } => {
                    emit_expr(value, out, fctx, string_map, opts);
                    if let Some(off) = fctx.offset_of(name) {
                        out.push_str(&format!("    LDX RESULT\n    STX {} ,S\n", off));
                    } else {
                        out.push_str(&format!("    LDX RESULT\n    LDU #VAR_{}\n    STU TMPPTR\n    STX ,U\n", name.to_uppercase()));
                    }
                }
                crate::ast::AssignTarget::Index { target: array_expr, index, .. } => {
                    // Array indexed assignment: arr[index] = value
                    // For now, only support simple variable arrays
                    let array_name = if let Expr::Ident(id) = &**array_expr {
                        &id.name
                    } else {
                        panic!("Complex array expressions not yet supported in assignment");
                    };
                    
                    // 1. Evaluate index first
                    emit_expr(index, out, fctx, string_map, opts);
                    out.push_str("    LDD RESULT\n    ASLB\n    ROLA\n"); // index * 2
                    out.push_str("    STD TMPPTR\n"); // Save offset temporarily
                    
                    // 2. Load the array base address (pointer value, not pointer address)
                    if let Some(off) = fctx.offset_of(array_name) {
                        // Local array: load pointer from stack
                        out.push_str(&format!("    LDD {} ,S\n", off));
                    } else if opts.mutable_arrays.contains(array_name) {
                        // Global mutable array: use direct RAM address
                        out.push_str(&format!("    LDD #VAR_{}_DATA\n", array_name.to_uppercase()));
                    } else {
                        // Global array pointer (legacy): load pointer from variable
                        out.push_str(&format!("    LDD VAR_{}\n", array_name.to_uppercase()));
                    }
                    
                    // 3. Add offset to base pointer
                    out.push_str("    TFR D,X\n"); // X = array base pointer
                    out.push_str("    LDD TMPPTR\n"); // D = offset
                    out.push_str("    LEAX D,X\n"); // X = base + offset
                    out.push_str("    STX TMPPTR2\n"); // Save computed address in TMPPTR2 (avoid collision with expr evaluation)
                    
                    // 4. Evaluate value to assign
                    emit_expr(value, out, fctx, string_map, opts);
                    
                    // 5. Store value at computed address
                    out.push_str("    LDX TMPPTR2\n    LDD RESULT\n    STD ,X\n"); // Use TMPPTR2
                }
                crate::ast::AssignTarget::FieldAccess { target, field, .. } => {
                    // Phase 3 - struct field assignment codegen
                    // Similar to FieldAccess expression, but stores instead of loads
                    
                    // Simple case: target is Ident (struct variable)
                    if let Expr::Ident(name) = target.as_ref() {
                        let var_name = &name.name;
                        
                        // ✅ NEW: Handle self.field = value in struct methods
                        if var_name == "self" {
                            // self is passed as VAR_ARG0 (pointer to struct)
                            // Need to determine struct type from function context
                            // For now, infer from function name (format: STRUCTNAME_METHODNAME)
                            if let Some(method_struct_type) = fctx.current_function_struct_type() {
                                if let Some(layout) = opts.structs.get(&method_struct_type) {
                                    if let Some(field_layout) = layout.get_field(field) {
                                        let field_offset = field_layout.offset as i32;
                                        
                                        // 1. Evaluate value to assign
                                        emit_expr(value, out, fctx, string_map, opts);
                                        
                                        // 2. Load struct pointer from VAR_ARG0
                                        // 3. Store value at field offset
                                        out.push_str(&format!("    ; Assign self.{} (struct {} field offset {})\n", field, method_struct_type, field_offset));
                                        out.push_str("    LDX VAR_ARG0    ; Load struct pointer\n");
                                        out.push_str("    LDD RESULT      ; Load value to assign\n");
                                        out.push_str(&format!("    STD {},X        ; Store at field offset\n", field_offset));
                                    } else {
                                        eprintln!("WARNING: Field '{}' not found in struct '{}'", field, method_struct_type);
                                        out.push_str(&format!("    ; ERROR: Field '{}' not found in struct '{}'\n", field, method_struct_type));
                                    }
                                } else {
                                    eprintln!("WARNING: Struct type '{}' not found for method", method_struct_type);
                                    out.push_str(&format!("    ; ERROR: Struct '{}' not found\n", method_struct_type));
                                }
                            } else {
                                eprintln!("WARNING: self.field assignment outside of struct method context");
                                out.push_str("    ; ERROR: self.field assignment outside method\n");
                            }
                            return;
                        }
                        
                        // Check if it's a local variable
                        if let Some(base_offset) = fctx.offset_of(var_name) {
                            // Get struct type from variable info
                            let struct_type = fctx.var_type(var_name);
                            
                            if let Some(type_name) = struct_type {
                                if !type_name.is_empty() {
                                    // This is a struct variable - find field in its layout
                                    if let Some(layout) = opts.structs.get(type_name) {
                                        if let Some(field_layout) = layout.get_field(field) {
                                            let field_offset_bytes = field_layout.offset as i32; // offset is already in bytes
                                            let total_offset = base_offset + field_offset_bytes;
                                            
                                            // 1. Evaluate value to assign
                                            emit_expr(value, out, fctx, string_map, opts);
                                            
                                            // 2. Store value at field location
                                            out.push_str(&format!("    ; Assign {}.{} (struct {} offset {})\n", var_name, field, type_name, total_offset));
                                            out.push_str(&format!("    LDD RESULT\n    STD {},S\n", total_offset));
                                        } else {
                                            eprintln!("WARNING: Field '{}' not found in struct '{}'", field, type_name);
                                        }
                                    } else {
                                        eprintln!("WARNING: Struct type '{}' not found", type_name);
                                    }
                                } else {
                                    eprintln!("WARNING: Variable '{}' is not a struct", var_name);
                                }
                            } else {
                                eprintln!("WARNING: Variable '{}' type unknown", var_name);
                            }
                        } else {
                            // Global variable or not found
                            eprintln!("WARNING: FieldAccess assignment to global struct '{}' not yet supported", var_name);
                        }
                    } else {
                        // Complex expression - not yet supported
                        eprintln!("WARNING: FieldAccess assignment on complex expression not yet supported");
                    }
                }
            }
        }
        Stmt::Let { name, value, .. } => {
            // Special handling for string literals - load pointer directly
            if let Expr::StringLit(s) = value {
                if let Some(label) = string_map.get(s) {
                    out.push_str(&format!("    LDX #{}    ; String literal pointer\n", label));
                    if let Some(off) = fctx.offset_of(name) {
                        out.push_str(&format!("    STX {} ,S\n", off));
                    }
                } else {
                    // String not in map - shouldn't happen but fallback to null
                    out.push_str("    LDX #0    ; String not found in map\n");
                    if let Some(off) = fctx.offset_of(name) {
                        out.push_str(&format!("    STX {} ,S\n", off));
                    }
                }
            } else {
                // Normal expression evaluation
                emit_expr(value, out, fctx, string_map, opts);
                if let Some(off) = fctx.offset_of(name) {
                    out.push_str(&format!("    LDX RESULT\n    STX {} ,S\n", off));
                }
            }
        }
        Stmt::Expr(e, _) => emit_expr(e, out, fctx, string_map, opts),
        Stmt::Return(o, _) => {
            if let Some(e) = o { emit_expr(e, out, fctx, string_map, opts); }
            if fctx.frame_size > 0 { out.push_str(&format!("    LEAS {} ,S ; free locals\n", fctx.frame_size)); }
            out.push_str("    RTS\n");
        }
        Stmt::Break { .. } => {
            if let Some(end) = &loop_ctx.end {
                out.push_str(&format!("    BRA {}\n", end));
            }
        }
        Stmt::Continue { .. } => {
            if let Some(st) = &loop_ctx.start {
                out.push_str(&format!("    BRA {}\n", st));
            }
        }
        Stmt::Pass { .. } => {
            // No-op: generates a comment only
            out.push_str("    ; pass (no-op)\n");
        }
        Stmt::While { cond, body, .. } => {
            let ls = fresh_label("WH");
            let le = fresh_label("WH_END");
            out.push_str(&format!("{}: ; while start\n", ls));
            emit_expr(cond, out, fctx, string_map, opts);
            // Long branch to end
            out.push_str(&format!("    LDD RESULT\n    LBEQ {}\n", le));
            let inner = LoopCtx { start: Some(ls.clone()), end: Some(le.clone()) };
            for s in body { emit_stmt(s, out, &inner, fctx, string_map, opts, tracker, depth + 1); }
            out.push_str(&format!("    LBRA {}\n{}: ; while end\n", ls, le));
        }
        Stmt::For { var, start, end, step, body, .. } => {
            let ls = fresh_label("FOR");
            let le = fresh_label("FOR_END");
            emit_expr(start, out, fctx, string_map, opts);
            out.push_str("    LDD RESULT\n");
            if let Some(off) = fctx.offset_of(var) { out.push_str(&format!("    STD {} ,S\n", off)); }
            else { out.push_str(&format!("    STD VAR_{}\n", var.to_uppercase())); }
            out.push_str(&format!("{}: ; for loop\n", ls));
            if let Some(off) = fctx.offset_of(var) { out.push_str(&format!("    LDD {} ,S\n", off)); }
            else { out.push_str(&format!("    LDD VAR_{}\n", var.to_uppercase())); }
            emit_expr(end, out, fctx, string_map, opts);
            out.push_str("    LDX RESULT\n    CMPD RESULT\n");
            out.push_str(&format!("    LBCC {}\n", le)); // unsigned >= end => exit
            let inner = LoopCtx { start: Some(ls.clone()), end: Some(le.clone()) };
            for s in body { emit_stmt(s, out, &inner, fctx, string_map, opts, tracker, depth + 1); }
            if let Some(se) = step {
                emit_expr(se, out, fctx, string_map, opts);
                out.push_str("    LDX RESULT\n");
            } else {
                out.push_str("    LDX #1\n");
            }
            if let Some(off) = fctx.offset_of(var) { out.push_str(&format!("    LDD {} ,S\n    ADDD ,X\n    STD {} ,S\n", off, off)); }
            else { out.push_str(&format!("    LDD VAR_{}\n    ADDD ,X\n    STD VAR_{}\n", var.to_uppercase(), var.to_uppercase())); }
            out.push_str(&format!("    LBRA {}\n{}: ; for end\n", ls, le));
        }
        Stmt::ForIn { var, iterable, body, .. } => {
            // for item in array:
            //   - Load array pointer
            //   - Load array size (first word at array address)
            //   - Loop through each element
            let ls = fresh_label("FORIN");
            let le = fresh_label("FORIN_END");
            let idx_label = format!("_FORIN_IDX_{}", ls.replace("L_", ""));
            
            // Evaluate iterable expression (should be array variable)
            let array_name = if let Expr::Ident(id) = iterable {
                &id.name
            } else {
                panic!("ForIn only supports simple array variables currently");
            };
            
            // Load array pointer
            out.push_str(&format!("    ; for {} in {}\n", var, array_name));
            if let Some(off) = fctx.offset_of(array_name) {
                out.push_str(&format!("    LDD {},S      ; Load array pointer from stack\n", off));
            } else {
                out.push_str(&format!("    LDD VAR_{}   ; Load array pointer\n", array_name.to_uppercase()));
            }
            out.push_str("    STD TMPPTR      ; Save array pointer\n");
            
            // Load array size (first word at array address)
            out.push_str("    LDX TMPPTR      ; X = array pointer\n");
            out.push_str("    LDD ,X++        ; D = size, X points to first element\n");
            out.push_str("    STX TMPPTR      ; TMPPTR = first element address\n");
            out.push_str("    STD TMPLEFT     ; TMPLEFT = remaining count\n");
            
            // Initialize loop index to 0 (stored in local variable)
            out.push_str(&format!("{}: ; forin loop start\n", ls));
            
            // Check if count > 0
            out.push_str("    LDD TMPLEFT\n");
            out.push_str(&format!("    LBEQ {}       ; Exit if no elements left\n", le));
            
            // Load current element: item = array[current_ptr]
            out.push_str("    LDX TMPPTR      ; X = current element pointer\n");
            out.push_str("    LDD ,X++        ; D = *ptr, ptr++\n");
            out.push_str("    STX TMPPTR      ; Save updated pointer\n");
            
            // Store element in loop variable
            if let Some(off) = fctx.offset_of(var) {
                out.push_str(&format!("    STD {},S        ; Store in local var\n", off));
            } else {
                out.push_str(&format!("    STD VAR_{}     ; Store in global var\n", var.to_uppercase()));
            }
            
            // Execute body
            let inner = LoopCtx { start: Some(ls.clone()), end: Some(le.clone()) };
            for s in body { emit_stmt(s, out, &inner, fctx, string_map, opts, tracker, depth + 1); }
            
            // Decrement count and loop
            out.push_str("    LDD TMPLEFT\n");
            out.push_str("    SUBD #1\n");
            out.push_str("    STD TMPLEFT\n");
            out.push_str(&format!("    LBRA {}\n", ls));
            out.push_str(&format!("{}: ; forin end\n", le));
        }
        Stmt::If { cond, body, elifs, else_body, .. } => {
            let end = fresh_label("IF_END");
            let mut next = fresh_label("IF_NEXT");
            let simple_if = elifs.is_empty() && else_body.is_none();
            emit_expr(cond, out, fctx, string_map, opts);
            out.push_str(&format!("    LDD RESULT\n    LBEQ {}\n", next));
            for s in body { emit_stmt(s, out, loop_ctx, fctx, string_map, opts, tracker, depth + 1); }
            out.push_str(&format!("    LBRA {}\n", end));
            for (i, (c, b)) in elifs.iter().enumerate() {
                out.push_str(&format!("{}:\n", next));
                let new_next = if i == elifs.len() - 1 && else_body.is_none() { end.clone() } else { fresh_label("IF_NEXT") };
                emit_expr(c, out, fctx, string_map, opts);
                out.push_str(&format!("    LDD RESULT\n    LBEQ {}\n", new_next));
                for s in b { emit_stmt(s, out, loop_ctx, fctx, string_map, opts, tracker, depth + 1); }
                out.push_str(&format!("    LBRA {}\n", end));
                next = new_next;
            }
            if let Some(eb) = else_body {
                out.push_str(&format!("{}:\n", next));
                for s in eb { emit_stmt(s, out, loop_ctx, fctx, string_map, opts, tracker, depth + 1); }
            } else if !elifs.is_empty() || simple_if {
                // Only emit next label if it's different from end
                if next != end {
                    out.push_str(&format!("{}:\n", next));
                }
            }
            out.push_str(&format!("{}:\n", end));
        }
        Stmt::Switch { expr, cases, default, .. } => {
            emit_expr(expr, out, fctx, string_map, opts);
            out.push_str("    LDD RESULT\n    STD TMPLEFT ; switch value\n");
            let end = fresh_label("SW_END");
            let def_label = if default.is_some() { Some(fresh_label("SW_DEF")) } else { None };
            let mut numeric_cases: Vec<(i32,&Vec<Stmt>)> = Vec::new();
            let mut all_numeric = true;
            for (ce, body) in cases {
                if let Expr::Number(n) = ce { numeric_cases.push((*n, body)); } else { all_numeric = false; break; }
            }
            let mut used_jump_table = false;
            if all_numeric && numeric_cases.len() >= 3 {
                numeric_cases.sort_by_key(|(v,_)| *v & 0xFFFF);
                let min = numeric_cases.first().unwrap().0 & 0xFFFF;
                let max = numeric_cases.last().unwrap().0 & 0xFFFF;
                let span = (max - min) as usize + 1;
                if span <= numeric_cases.len()*2 && span*2 <= 254 {
                    let table_label = fresh_label("SW_JT");
                    use std::collections::BTreeMap;
                    let mut label_map: BTreeMap<i32,String> = BTreeMap::new();
                    for (val, _) in &numeric_cases { label_map.insert(*val & 0xFFFF, fresh_label("SW_CASE")); }
                    out.push_str(&format!("    LDD TMPLEFT\n    SUBD #{}\n    LBLT {}\n", min, def_label.as_ref().unwrap_or(&end)));
                    out.push_str(&format!("    CMPD #{}\n    LBHI {}\n", span as i32 - 1, def_label.as_ref().unwrap_or(&end)));
                    out.push_str("    ASLB\n    ROLA\n");
                    out.push_str(&format!("    LDX #{}\n    ABX\n", table_label));
                    out.push_str("    LDD ,X\n    TFR D,X\n    JMP ,X\n");
                    for (val, body) in &numeric_cases {
                        let lbl = label_map.get(&(*val & 0xFFFF)).unwrap();
                        out.push_str(&format!("{}:\n", lbl));
                        for s in *body { emit_stmt(s, out, loop_ctx, fctx, string_map, opts, tracker, depth + 1); }
                        out.push_str(&format!("    LBRA {}\n", end));
                    }
                    if let Some(dl) = &def_label {
                        out.push_str(&format!("{}:\n", dl));
                        for s in default.as_ref().unwrap() { emit_stmt(s, out, loop_ctx, fctx, string_map, opts, tracker, depth + 1); }
                    }
                    out.push_str(&format!("{}:\n", end));
                    out.push_str(&format!("{}:\n", table_label));
                    for offset in 0..span as i32 {
                        let actual = (min + offset) & 0xFFFF;
                        if let Some(lbl) = label_map.get(&actual) { out.push_str(&format!("    FDB {}\n", lbl)); }
                        else if let Some(dl) = &def_label { out.push_str(&format!("    FDB {}\n", dl)); }
                        else { out.push_str(&format!("    FDB {}\n", end)); }
                    }
                    used_jump_table = true;
                }
            }
            if used_jump_table { return; }
            let mut labels = Vec::new();
            for _ in cases { labels.push(fresh_label("SW_CASE")); }
            for ((cv,_), lbl) in cases.iter().zip(labels.iter()) {
                emit_expr(cv, out, fctx, string_map, opts);
                out.push_str("    LDD RESULT\n    SUBD TMPLEFT\n    LBEQ ");
                out.push_str(lbl);
                out.push('\n');
            }
            if let Some(dl) = &def_label { out.push_str(&format!("    LBRA {}\n", dl)); } else { out.push_str(&format!("    LBRA {}\n", end)); }
            for ((_, body), lbl) in cases.iter().zip(labels.iter()) {
                out.push_str(&format!("{}:\n", lbl));
                for s in body { emit_stmt(s, out, loop_ctx, fctx, string_map, opts, tracker, depth + 1); }
                out.push_str(&format!("    LBRA {}\n", end));
            }
            if let Some(dl) = def_label {
                out.push_str(&format!("{}:\n", dl));
                for s in default.as_ref().unwrap() { emit_stmt(s, out, loop_ctx, fctx, string_map, opts, tracker, depth + 1); }
            }
            out.push_str(&format!("{}:\n", end));
        },
        Stmt::CompoundAssign { .. } => panic!("CompoundAssign should be transformed away before emit_stmt"),
    }
}

// emit_expr: lower expressions; result placed in RESULT.
// Nota: En 6809 las operaciones sobre D ya limitan a 16 bits; no hace falta 'mask' explícito.
