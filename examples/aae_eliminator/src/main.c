/* Sega G80 (Z80) AAE game on RP2350 — entry point. See aae_tacscan/src/main.c. */
extern int  init_segag80(void);
extern void run_segag80(void);
extern void run_cpus_to_cycles(void);
extern void init_cpu_config(void);
extern void aae_load_roms(void);
extern void v_init(void);
extern void v_WaitRecal(void);
extern unsigned char v_readButtons(void);
extern void v_readJoystick1Analog(void);
int main(void){
    v_init();
    aae_load_roms();
    init_cpu_config();
    init_segag80();
    for(;;){
        v_WaitRecal();
        v_readButtons();
        v_readJoystick1Analog();
        run_cpus_to_cycles();
        run_segag80();
    }
    return 0;
}
