/// Music resource tests
/// Separated from musres.rs to keep production code clean

use vectrex_lang::musres::{MusicResource, NoteEvent};

#[test]
fn test_create_music() {
    let music = MusicResource::new("test-song");
    assert_eq!(music.name, "test-song");
    assert_eq!(music.tempo, 120);
}

#[test]
fn test_midi_to_psg() {
    // Middle C (MIDI 60) = 261.63 Hz
    let period = MusicResource::midi_to_psg_period(60);
    // Formula: 1_411_200 / (16 * 261.63) ≈ 337
    assert!(period >= 330 && period <= 345, "MIDI 60 period was {}", period);

    // A4 (MIDI 69) = 440 Hz
    let period_a4 = MusicResource::midi_to_psg_period(69);
    // Formula: 1_411_200 / (16 * 440) ≈ 200
    assert!(period_a4 >= 195 && period_a4 <= 206, "MIDI 69 period was {}", period_a4);
}

#[test]
fn test_compile_to_asm() {
    let mut music = MusicResource::new("test");
    music.notes.push(NoteEvent {
        id: "note1".to_string(),
        note: 60, // Middle C
        start: 0,
        duration: 48,
        velocity: 12,
        channel: 0,
    });
    
    let symbol_name = music.name.to_uppercase().replace("-", "_").replace(" ", "_");
    let asm = music.compile_to_asm(&symbol_name);
    assert!(asm.contains("_TEST_MUSIC:"));
    assert!(asm.contains("FCB") || asm.contains("FDB")); // ASM directives present
    assert!(asm.contains("; Frame-based PSG")); // Verify format description
}
