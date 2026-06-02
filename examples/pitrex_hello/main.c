#include <vectrexInterface.h>

/* newlib stubs required by libc */
void _kill(int pid, int sig) { (void)pid; (void)sig; }
int  _getpid(void) { return 1; }

int main(int argc, char **argv) {
    vectrexinit(1);
    v_init();
    v_setRefresh(50);

    for (;;) {
        v_WaitRecal();
        v_readButtons();
        v_readJoystick1Analog();

        // Draw a rectangle
        v_directDraw32(-10000, -10000, -10000,  10000, 64);
        v_directDraw32(-10000,  10000,  10000,  10000, 64);
        v_directDraw32( 10000,  10000,  10000, -10000, 64);
        v_directDraw32( 10000, -10000, -10000, -10000, 64);

        // Print text
        v_printStringRaster(-30, 10, "HELLO VECTREX", 5, -7, '\0');
    }

    return 0;
}
