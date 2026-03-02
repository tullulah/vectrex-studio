use vectrex_emulator::CPU;

#[test]
fn inca_wraps_and_sets_zero() {
    let mut cpu = CPU::default();
    cpu.pc = 0x0100;
    cpu.a = 0xFF;
    cpu.bus.mem[0x0100] = 0x4C;
    cpu.bus.mem[0x0100] = 0x4C; // INCA
    cpu.step();
    assert_eq!(cpu.a, 0x00, "INCA should wrap 0xFF->0x00");
    assert!(cpu.cc_z, "Z flag set after result 0");
}

#[test]
fn decb_wraps_and_sets_negative() {
    let mut cpu = CPU::default();
    cpu.pc = 0x0100;
    cpu.b = 0x00;
    cpu.bus.mem[0x0100] = 0x5A;
    cpu.bus.mem[0x0100] = 0x5A; // DECB
    cpu.step();
    assert_eq!(cpu.b, 0xFF, "DECB 0x00 -> 0xFF wrap");
    assert!(cpu.cc_n, "N flag set after 0xFF (bit7=1)");
}
