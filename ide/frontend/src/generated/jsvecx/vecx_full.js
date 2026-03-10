/* jsvecx bundle 2025-09-21T11:04:36.328Z */
console.log('[JSVecx] ✓ PATCHED VERSION LOADED - Button fix active (2026-01-03)');

/* BEGIN utils.js */
/*
JSVecX : JavaScript port of the VecX emulator by raz0red.
         Copyright (C) 2010-2019 raz0red

The original C version was written by Valavan Manohararajah
(http://valavan.net/vectrex.html).
*/

/*
  Emulation of the AY-3-8910 / YM2149 sound chip.

  Based on various code snippets by Ville Hallik, Michael Cuddy,
  Tatsuyuki Satoh, Fabrice Frances, Nicola Salmoria.
*/

function fptr( value )
{
    this.value = value;
}

function Utils()
{
    this.errorCount = 1;
    this.logCount = 500;

    this.showError = function( error )
    {
        if( this.errorCount > 0 )
        {
            console.log(error);
            this.errorCount--;
        }
    }

    this.initArray = function( arr, value )
    {
        for( var i = 0; i < arr.length; i++ )
        {
            arr[i] = value;
        }
    }
}

var utils = new Utils();

/* END utils.js */

/* BEGIN globals.js */
/*
JSVecX : JavaScript port of the VecX emulator by raz0red.
         Copyright (C) 2010-2019 raz0red

The original C version was written by Valavan Manohararajah
(http://valavan.net/vectrex.html).
*/

/*
  Emulation of the AY-3-8910 / YM2149 sound chip.

  Based on various code snippets by Ville Hallik, Michael Cuddy,
  Tatsuyuki Satoh, Fabrice Frances, Nicola Salmoria.
*/

var Globals =
{
    romdata: null, /* The vectrex rom */
    cartdata: null, /* The cartridge rom */

    VECTREX_MHZ: 1500000, /* speed of the vectrex being emulated */
    VECTREX_COLORS: 128,     /* number of possible colors ... grayscale */
    ALG_MAX_X: 33000,
    ALG_MAX_Y: 41000,
    VECTREX_PDECAY: 30, /* phosphor decay rate */
    VECTOR_HASH: 65521,
    SCREEN_X_DEFAULT: 330,
    SCREEN_Y_DEFAULT: 410
}

/* number of 6809 cycles before a frame redraw */
Globals.FCYCLES_INIT = Globals.VECTREX_MHZ / Globals.VECTREX_PDECAY >> 0; // raz

/* max number of possible vectors that maybe on the screen at one time.
 * one only needs VECTREX_MHZ / VECTREX_PDECAY but we need to also store
 * deleted vectors in a single table
 */
Globals.VECTOR_CNT = Globals.VECTREX_MHZ / Globals.VECTREX_PDECAY >> 0; // raz

/* END globals.js */

/* BEGIN vector_t.js */
/*
JSVecX : JavaScript port of the VecX emulator by raz0red.
         Copyright (C) 2010-2019 raz0red

The original C version was written by Valavan Manohararajah
(http://valavan.net/vectrex.html).
*/

/*
  Emulation of the AY-3-8910 / YM2149 sound chip.

  Based on various code snippets by Ville Hallik, Michael Cuddy,
  Tatsuyuki Satoh, Fabrice Frances, Nicola Salmoria.
*/

function vector_t()
{
    //long x0, y0; /* start coordinate */
    this.x0 = 0;
    this.y0 = 0;
    //long x1, y1; /* end coordinate */
    this.x1 = 0;
    this.y1 = 0;

    /* color [0, VECTREX_COLORS - 1], if color = VECTREX_COLORS, then this is
     * an invalid entry and must be ignored.
     */
    //unsigned char color;
    this.color = 0;

    this.reset = function()
    {
        this.x0 = this.y0 = this.x1 = this.y1 = this.color = 0;        
    }
}

/* END vector_t.js */

/* BEGIN header.js */
/*
JSVecX : JavaScript port of the VecX emulator by raz0red.
         Copyright (C) 2010-2019 raz0red

The original C version was written by Valavan Manohararajah
(http://valavan.net/vectrex.html).
*/

/*
  Emulation of the AY-3-8910 / YM2149 sound chip.

  Based on various code snippets by Ville Hallik, Michael Cuddy,
  Tatsuyuki Satoh, Fabrice Frances, Nicola Salmoria.
*/


/* END header.js */

/* BEGIN e6809.js */
/*
JSVecX : JavaScript port of the VecX emulator by raz0red.
         Copyright (C) 2010-2019 raz0red

The original C version was written by Valavan Manohararajah
(http://valavan.net/vectrex.html).
*/

/*
  Emulation of the AY-3-8910 / YM2149 sound chip.

  Based on various code snippets by Ville Hallik, Michael Cuddy,
  Tatsuyuki Satoh, Fabrice Frances, Nicola Salmoria.
*/

function e6809()
{
    this.vecx = null;

    this.FLAG_E = 0x80;
    this.FLAG_F = 0x40;
    this.FLAG_H = 0x20;
    this.FLAG_I = 0x10;
    this.FLAG_N = 0x08;
    this.FLAG_Z = 0x04;
    this.FLAG_V = 0x02;
    this.FLAG_C = 0x01;
    this.IRQ_NORMAL = 0;
    this.IRQ_SYNC = 1;
    this.IRQ_CWAI = 2;

    /* index registers */

    //static unsigned reg_x;
    this.reg_x = new fptr(0);
    //static unsigned reg_y;
    this.reg_y = new fptr(0);

    /* user stack pointer */

    //static unsigned reg_u;
    this.reg_u = new fptr(0);

    /* hardware stack pointer */

    //static unsigned reg_s;
    this.reg_s = new fptr(0);

    /* program counter */

    //static unsigned reg_pc;
    this.reg_pc = 0;

    /* accumulators */

    //static unsigned reg_a;
    this.reg_a = 0;
    //static unsigned reg_b;
    this.reg_b = 0;

    /* direct page register */

    //static unsigned reg_dp;
    this.reg_dp = 0;

    /* condition codes */

    //static unsigned reg_cc;
    this.reg_cc = 0;

    /* flag to see if interrupts should be handled (sync/cwai). */

    //static unsigned irq_status;
    this.irq_status = 0;

    /*
        static unsigned *rptr_xyus[4] = {
            &reg_x,
            &reg_y,
            &reg_u,
            &reg_s
        };
    */

    this.rptr_xyus = [ this.reg_x,  this.reg_y,  this.reg_u,  this.reg_s ];

    /* obtain a particular condition code. returns 0 or 1. */

//    //static einline unsigned get_cc (unsigned flag)
//    this.get_cc = function( flag )
//    {
//        return ( this.reg_cc / flag >> 0 ) & 1;
//    }
const GETCC = (flag) => (((this.reg_cc/flag>>0)&1));

    /*
    * set a particular condition code to either 0 or 1.
    * value parameter must be either 0 or 1.
    */

//    //static einline void set_cc (unsigned flag, unsigned value)
//    this.set_cc = function( flag, value )
//    {
//        this.reg_cc &= ~flag;
//        this.reg_cc |= value * flag;
//    }
const SETCC = (flag, value) => (this.reg_cc=((this.reg_cc&~flag)|(value*flag)));

    /* test carry */

    //static einline unsigned test_c (unsigned i0, unsigned i1,
    //unsigned r, unsigned sub)
    this.test_c = function( i0, i1, r, sub )
    {
        var flag = (i0 | i1) & ~r;
        /* one of the inputs is 1 and output is 0 */
        flag |= (i0 & i1);
        /* both inputs are 1 */
        flag = (flag >> 7) & 1;
        flag ^= sub;
        /* on a sub, carry is opposite the carry of an add */

        return flag;
    }

    /* test negative */

//    //static einline unsigned test_n (unsigned r)
//    this.test_n = function( r )
//    {
//        return (r >> 7) & 1;
//    }
const TESTN = (r) => (((r>>7)&1));

    /* test for zero in lower 8 bits */

    //static einline unsigned test_z8 (unsigned r)
    this.test_z8 = function( r )
    {
        var flag = ~r;
        flag = (flag >> 4) & (flag & 0xf);
        flag = (flag >> 2) & (flag & 0x3);
        flag = (flag >> 1) & (flag & 0x1);

        return flag;
    }

    /* test for zero in lower 16 bits */

    //static einline unsigned test_z16 (unsigned r)
    this.test_z16 = function( r )
    {
        var flag = ~r;
        flag = (flag >> 8) & (flag & 0xff);
        flag = (flag >> 4) & (flag & 0xf);
        flag = (flag >> 2) & (flag & 0x3);
        flag = (flag >> 1) & (flag & 0x1);

        return flag;
    }

    /* overflow is set whenever the sign bits of the inputs are the same
     * but the sign bit of the result is not same as the sign bits of the
     * inputs.
     */

    //static einline unsigned test_v (unsigned i0, unsigned i1, unsigned r)
    this.test_v = function( i0, i1, r )
    {
        var flag = ~(i0 ^ i1);
        /* input sign bits are the same */
        flag &= (i0 ^ r);
        /* input sign and output sign not same */
        flag = (flag >> 7) & 1;

        return flag;
    }
const TESTV = (i0, i1, r) => (((((~(i0^i1))&(i0^r))>>7)&1));

//    //static einline unsigned get_reg_d (void)
//    this.get_reg_d = function()
//    {
//        return (this.reg_a << 8) | (this.reg_b & 0xff);
//    }
const GETREGD = () => (((this.reg_a<<8)|(this.reg_b&0xff)));

    //static einline void set_reg_d (unsigned value)
    this.set_reg_d = function( value )
    {
        this.reg_a = (value >> 8);
        this.reg_b = value;
    }

    /* read a byte ... the returned value has the lower 8-bits set to the byte
     * while the upper bits are all zero.
     */

//    //static einline unsigned read8 (unsigned address)
//    this.read8 = function( address )
//    {
//        //return this.e6809_read8( address & 0xffff );
//        return this.vecx.read8(address & 0xffff);
//    }

    /* write a byte ... only the lower 8-bits of the unsigned data
     * is written. the upper bits are ignored.
     */

//    //static einline void write8 (unsigned address, unsigned data)
//    this.write8 = function( address, data )
//    {
//        this.vecx.write8(address & 0xffff, data & 0xff);
//    }

    //static einline unsigned read16 (unsigned address)
    this.read16 = function( address )
    {
        var datahi = this.vecx.read8(address);
        var datalo = this.vecx.read8(address + 1);

        return (datahi << 8) | datalo;
    }

    //static einline void write16 (unsigned address, unsigned data)
    this.write16 = function( address, data )
    {
        this.vecx.write8(address, data >> 8);
        this.vecx.write8(address + 1, data);
    }

    //static einline void push8 (unsigned *sp, unsigned data)
    this.push8 = function( sp, data )
    {
        //(*sp)--;
        sp.value--;
        //write8 (*sp, data);
        this.vecx.write8(sp.value, data);
    }

//    //static einline unsigned pull8 (unsigned *sp)
//    this.pull8 = function( sp )
//    {
//        //unsigned data;
//        return this.vecx.read8(sp.value++);
//        //(*sp)++;
//    }
const PULL8 = (sp) => ((this.vecx.read8(sp.value++)));

    //static einline void push16 (unsigned *sp, unsigned data)
    this.push16 = function( sp, data )
    {
        /*
        this.push8(sp, data);
        this.push8(sp, data >> 8);
        */
        sp.value--;
        this.vecx.write8(sp.value, data);
        sp.value--;
        this.vecx.write8(sp.value, data >> 8 );
    }

    //static einline unsigned pull16 (unsigned *sp)
    this.pull16 = function( sp )
    {
        //unsigned datahi, datalo;

        var datahi = this.vecx.read8(sp.value++);
        var datalo = this.vecx.read8(sp.value++);

        return (datahi << 8) | datalo;
    }

    /* read a byte from the address pointed to by the pc */

//    //static einline unsigned pc_read8 (void)
//    this.pc_read8 = function()
//    {
//        return this.vecx.read8(this.reg_pc++);
//    }

    /* read a word from the address pointed to by the pc */

    //static einline unsigned pc_read16 (void)
    this.pc_read16 = function()
    {
        //unsigned data;

        var data = this.read16(this.reg_pc);
        this.reg_pc += 2;

        return data;
    }

    /* sign extend an 8-bit quantity into a 16-bit quantity */

    //static einline unsigned sign_extend (unsigned data)
    this.sign_extend = function( data )
    {
        return (~(data & 0x80) + 1) | (data & 0xff);
    }

    /* direct addressing, upper byte of the address comes from
     * the direct page register, and the lower byte comes from the
     * instruction itself.
     */

//    //static einline unsigned ea_direct (void)
//    this.ea_direct = function()
//    {
//        return (this.reg_dp << 8) | this.vecx.read8(this.reg_pc++);
//    }
const EADIRECT = () => (((this.reg_dp<<8)|this.vecx.read8(this.reg_pc++)));

    /*
    * extended addressing, address is obtained from 2 bytes following
    * the instruction.
    */

    //static einline unsigned ea_extended (void)
//    this.ea_extended = function()
//    {
//        return this.pc_read16();
//    }

    /* indexed addressing */

    //static einline unsigned ea_indexed (unsigned *cycles)
    this.ea_indexed = function( cycles )
    {
        //unsigned r, op, ea;
        var ea = 0;
        var op = 0;
        var r = 0;

        /* post byte */

        op = this.vecx.read8(this.reg_pc++);
        r = (op >> 5) & 3;

        switch( op )
        {
            case 0x00: case 0x01: case 0x02: case 0x03:
            case 0x04: case 0x05: case 0x06: case 0x07:
            case 0x08: case 0x09: case 0x0a: case 0x0b:
            case 0x0c: case 0x0d: case 0x0e: case 0x0f:
            case 0x20: case 0x21: case 0x22: case 0x23:
            case 0x24: case 0x25: case 0x26: case 0x27:
            case 0x28: case 0x29: case 0x2a: case 0x2b:
            case 0x2c: case 0x2d: case 0x2e: case 0x2f:
            case 0x40: case 0x41: case 0x42: case 0x43:
            case 0x44: case 0x45: case 0x46: case 0x47:
            case 0x48: case 0x49: case 0x4a: case 0x4b:
            case 0x4c: case 0x4d: case 0x4e: case 0x4f:
            case 0x60: case 0x61: case 0x62: case 0x63:
            case 0x64: case 0x65: case 0x66: case 0x67:
            case 0x68: case 0x69: case 0x6a: case 0x6b:
            case 0x6c: case 0x6d: case 0x6e: case 0x6f:
            /* R, +[0, 15] */

                //ea = *rptr_xyus[r] + (op & 0xf);
                ea = this.rptr_xyus[r].value + (op & 0xf);
                //(*cycles)++;
                cycles.value++;
                break;
            case 0x10: case 0x11: case 0x12: case 0x13:
            case 0x14: case 0x15: case 0x16: case 0x17:
            case 0x18: case 0x19: case 0x1a: case 0x1b:
            case 0x1c: case 0x1d: case 0x1e: case 0x1f:
            case 0x30: case 0x31: case 0x32: case 0x33:
            case 0x34: case 0x35: case 0x36: case 0x37:
            case 0x38: case 0x39: case 0x3a: case 0x3b:
            case 0x3c: case 0x3d: case 0x3e: case 0x3f:
            case 0x50: case 0x51: case 0x52: case 0x53:
            case 0x54: case 0x55: case 0x56: case 0x57:
            case 0x58: case 0x59: case 0x5a: case 0x5b:
            case 0x5c: case 0x5d: case 0x5e: case 0x5f:
            case 0x70: case 0x71: case 0x72: case 0x73:
            case 0x74: case 0x75: case 0x76: case 0x77:
            case 0x78: case 0x79: case 0x7a: case 0x7b:
            case 0x7c: case 0x7d: case 0x7e: case 0x7f:
            /* R, +[-16, -1] */

                //ea = *rptr_xyus[r] + (op & 0xf) - 0x10;
                ea = this.rptr_xyus[r].value + (op & 0xf) - 0x10;
                //(*cycles)++;
                cycles.value++;
                break;
            case 0x80: case 0x81:
            case 0xa0: case 0xa1:
            case 0xc0: case 0xc1:
            case 0xe0: case 0xe1:
            /* ,R+ / ,R++ */

                //ea = *rptr_xyus[r];
                ea = this.rptr_xyus[r].value;
                //*rptr_xyus[r] += 1 + (op & 1);
                this.rptr_xyus[r].value+=(1 + (op & 1));
                //*cycles += 2 + (op & 1);
                cycles.value+=(2 + (op & 1));
                break;
            case 0x90: case 0x91:
            case 0xb0: case 0xb1:
            case 0xd0: case 0xd1:
            case 0xf0: case 0xf1:
            /* [,R+] ??? / [,R++] */

                //ea = read16 (*rptr_xyus[r]);
                ea = this.read16(this.rptr_xyus[r].value);
                //*rptr_xyus[r] += 1 + (op & 1);
                this.rptr_xyus[r].value+=(1 + (op & 1));
                //*cycles += 5 + (op & 1);
                cycles.value+=(5 + (op & 1));
                break;
            case 0x82: case 0x83:
            case 0xa2: case 0xa3:
            case 0xc2: case 0xc3:
            case 0xe2: case 0xe3:
            /* ,-R / ,--R */

                //*rptr_xyus[r] -= 1 + (op & 1);
                this.rptr_xyus[r].value-=(1 + (op & 1));
                //ea = *rptr_xyus[r];
                ea = this.rptr_xyus[r].value;
                //*cycles += 2 + (op & 1);
                cycles.value+=(2 + (op & 1));
                break;
            case 0x92: case 0x93:
            case 0xb2: case 0xb3:
            case 0xd2: case 0xd3:
            case 0xf2: case 0xf3:
            /* [,-R] ??? / [,--R] */

                //*rptr_xyus[r] -= 1 + (op & 1);
                this.rptr_xyus[r].value-=(1 + (op & 1));
                //ea = read16 (*rptr_xyus[r]);
                ea = this.read16(this.rptr_xyus[r].value);
                //*cycles += 5 + (op & 1);
                cycles.value+=(5 + (op & 1));
                break;
            case 0x84: case 0xa4:
            case 0xc4: case 0xe4:
            /* ,R */

                //ea = *rptr_xyus[r];
                ea = this.rptr_xyus[r].value;
                break;
            case 0x94: case 0xb4:
            case 0xd4: case 0xf4:
            /* [,R] */

                //ea = read16 (*rptr_xyus[r]);
                ea = this.read16(this.rptr_xyus[r].value);
                //*cycles += 3;
                cycles.value+=(3);
                break;
            case 0x85: case 0xa5:
            case 0xc5: case 0xe5:
            /* B,R */

                //ea = *rptr_xyus[r] + sign_extend (reg_b);
                ea = this.rptr_xyus[r].value + this.sign_extend(this.reg_b);
                //*cycles += 1;
                cycles.value+=(1);
                break;
            case 0x95: case 0xb5:
            case 0xd5: case 0xf5:
            /* [B,R] */

                //ea = read16 (*rptr_xyus[r] + sign_extend (reg_b));
                ea = this.read16(this.rptr_xyus[r].value + this.sign_extend(this.reg_b));
                //*cycles += 4;
                cycles.value+=(4);
                break;
            case 0x86: case 0xa6:
            case 0xc6: case 0xe6:
            /* A,R */

                //ea = *rptr_xyus[r] + sign_extend (reg_a);
                ea = this.rptr_xyus[r].value + this.sign_extend(this.reg_a);
                //*cycles += 1;
                cycles.value+=(1);
                break;
            case 0x96: case 0xb6:
            case 0xd6: case 0xf6:
            /* [A,R] */

                //ea = read16 (*rptr_xyus[r] + sign_extend (reg_a));
                ea = this.read16(this.rptr_xyus[r].value + this.sign_extend(this.reg_a));
                //*cycles += 4;
                cycles.value+=(4);
            break;
            case 0x88: case 0xa8:
            case 0xc8: case 0xe8:
            /* byte,R */

                //ea = *rptr_xyus[r] + sign_extend (pc_read8 ());
                ea = this.rptr_xyus[r].value + this.sign_extend(this.vecx.read8(this.reg_pc++));
                //*cycles += 1;
                cycles.value+=(1);
                break;
            case 0x98: case 0xb8:
            case 0xd8: case 0xf8:
            /* [byte,R] */

                //ea = read16 (*rptr_xyus[r] + sign_extend (pc_read8 ()));
                ea = this.read16(this.rptr_xyus[r].value + this.sign_extend(this.vecx.read8(this.reg_pc++)));
                //*cycles += 4;
                cycles.value+=(4);
                break;
            case 0x89: case 0xa9:
            case 0xc9: case 0xe9:
            /* word,R */

                //ea = *rptr_xyus[r] + pc_read16 ();
                ea = this.rptr_xyus[r].value + this.pc_read16();
                //*cycles += 4;
                cycles.value+=(4);
                break;
            case 0x99: case 0xb9:
            case 0xd9: case 0xf9:
            /* [word,R] */

                //ea = read16 (*rptr_xyus[r] + pc_read16 ());
                ea = this.read16(this.rptr_xyus[r].value + this.pc_read16());
                //*cycles += 7;
                cycles.value+=(7);
                break;
            case 0x8b: case 0xab:
            case 0xcb: case 0xeb:
            /* D,R */

                //ea = *rptr_xyus[r] + get_reg_d ();
                ea = this.rptr_xyus[r].value + GETREGD();
                //*cycles += 4;
                cycles.value+=(4);
                break;
            case 0x9b: case 0xbb:
            case 0xdb: case 0xfb:
                /* [D,R] */

                //ea = read16 (*rptr_xyus[r] + get_reg_d ());
                ea = this.read16(this.rptr_xyus[r].value + GETREGD());
                //*cycles += 7;
                cycles.value+=(7);
                break;
            case 0x8c: case 0xac:
            case 0xcc: case 0xec:
            /* byte, PC */

                //r = sign_extend (pc_read8 ());
                r = this.sign_extend(this.vecx.read8(this.reg_pc++));
                //ea = reg_pc + r;
                ea = this.reg_pc + r;
                //*cycles += 1;
                cycles.value+=(1);
                break;
            case 0x9c: case 0xbc:
            case 0xdc: case 0xfc:
            /* [byte, PC] */

                //r = sign_extend (pc_read8 ());
                r = this.sign_extend(this.vecx.read8(this.reg_pc++));
                //ea = read16 (reg_pc + r);
                ea = this.read16(this.reg_pc + r);
                //*cycles += 4;
                cycles.value+=(4);
                break;
            case 0x8d: case 0xad:
            case 0xcd: case 0xed:
            /* word, PC */

                //r = pc_read16 ();
                r = this.pc_read16();
                //ea = reg_pc + r;
                ea = this.reg_pc + r;
                //*cycles += 5;
                cycles.value+=(5);
                break;
            case 0x9d: case 0xbd:
            case 0xdd: case 0xfd:
            /* [word, PC] */

                //r = pc_read16 ();
                r = this.pc_read16();
                //ea = read16 (reg_pc + r);
                ea = this.read16(this.reg_pc + r);
                //*cycles += 8;
                cycles.value+=(8);
                break;
            case 0x9f:
            /* [address] */

                //ea = read16 (pc_read16 ());
                ea = this.read16(this.pc_read16());
                //*cycles += 5;
                cycles.value+=(5);
                break;
            default:
                //printf ("undefined post-byte\n");
                console.log("⚠️ UNDEFINED POST-BYTE ERROR:");
                console.log("  PC: 0x" + this.reg_pc.toString(16).toUpperCase().padStart(4, '0'));
                console.log("  Post-byte: 0x" + pb.toString(16).toUpperCase().padStart(2, '0') + " (" + pb + ")");
                console.log("  Registers:");
                console.log("    A: 0x" + this.reg_a.toString(16).toUpperCase().padStart(2, '0'));
                console.log("    B: 0x" + this.reg_b.toString(16).toUpperCase().padStart(2, '0'));
                console.log("    X: 0x" + this.reg_x.value.toString(16).toUpperCase().padStart(4, '0'));
                console.log("    Y: 0x" + this.reg_y.value.toString(16).toUpperCase().padStart(4, '0'));
                console.log("    U: 0x" + this.reg_u.value.toString(16).toUpperCase().padStart(4, '0'));
                console.log("    S: 0x" + this.reg_s.value.toString(16).toUpperCase().padStart(4, '0'));
                console.log("    DP: 0x" + (this.reg_dp & 0xFF).toString(16).toUpperCase().padStart(2, '0'));
                console.log("    CC: 0x" + this.reg_cc.toString(16).toUpperCase().padStart(2, '0'));
                break;
        }

        return ea;
    }

    /* instruction: neg
     * essentially (0 - data).
     */

    //einline unsigned inst_neg (unsigned data)
    this.inst_neg = function( data )
    {
        //unsigned i0, i1, r;

        var i0 = 0;
        var i1 = (~data) & 0xffff; // raz
        var r = i0 + i1 + 1;

        SETCC(this.FLAG_H, this.test_c(i0 << 4, i1 << 4, r << 4, 0));
        SETCC(this.FLAG_N, TESTN(r));
        SETCC(this.FLAG_Z, this.test_z8(r));
        SETCC(this.FLAG_V, TESTV(i0, i1, r));
        SETCC(this.FLAG_C, this.test_c(i0, i1, r, 1));

        return r;
    }

    /* instruction: com */

    //einline unsigned inst_com (unsigned data)
    this.inst_com = function( data )
    {
        var r = (~data) & 0xffff; // raz

        SETCC(this.FLAG_N, TESTN(r));
        SETCC(this.FLAG_Z, this.test_z8(r));
        SETCC(this.FLAG_V, 0);
        SETCC(this.FLAG_C, 1);

        return r;
    }

    /* instruction: lsr
     * cannot be faked as an add or substract.
     */
    //einline unsigned inst_lsr (unsigned data)
    this.inst_lsr = function( data )
    {
        //unsigned r;

        var r = (data >> 1) & 0x7f;

        SETCC(this.FLAG_N, 0);
        SETCC(this.FLAG_Z, this.test_z8(r));
        SETCC(this.FLAG_C, data & 1);

        return r;
    }

    /* instruction: ror
     * cannot be faked as an add or substract.
     */
    //einline unsigned inst_ror (unsigned data)
    this.inst_ror = function( data )
    {
        //unsigned r, c;

        var c = GETCC(this.FLAG_C);
        var r = ((data >> 1) & 0x7f) | (c << 7);

        SETCC(this.FLAG_N, TESTN(r));
        SETCC(this.FLAG_Z, this.test_z8(r));
        SETCC(this.FLAG_C, data & 1);

        return r;
    }

    /* instruction: asr
     * cannot be faked as an add or substract.
     */
    //einline unsigned inst_asr (unsigned data)
    this.inst_asr = function( data )
    {
        //unsigned r;

        var r = ((data >> 1) & 0x7f) | (data & 0x80);

        SETCC(this.FLAG_N, TESTN(r));
        SETCC(this.FLAG_Z, this.test_z8(r));
        SETCC(this.FLAG_C, data & 1);

        return r;
    }

    /* instruction: asl
     * essentially (data + data). simple addition.
     */
    //einline unsigned inst_asl (unsigned data)
    this.inst_asl = function( data )
    {
        //unsigned i0, i1, r;

        var i0 = data;
        var i1 = data;
        var r = i0 + i1;

        SETCC(this.FLAG_H, this.test_c(i0 << 4, i1 << 4, r << 4, 0));
        SETCC(this.FLAG_N, TESTN(r));
        SETCC(this.FLAG_Z, this.test_z8(r));
        SETCC(this.FLAG_V, TESTV(i0, i1, r));
        SETCC(this.FLAG_C, this.test_c(i0, i1, r, 0));

        return r;
    }

    /* instruction: rol
     * essentially (data + data + carry). addition with carry.
     */
    //einline unsigned inst_rol (unsigned data)
    this.inst_rol = function( data )
    {
        //unsigned i0, i1, c, r;

        var i0 = data;
        var i1 = data;
        var c = GETCC(this.FLAG_C);
        var r = i0 + i1 + c;

        SETCC(this.FLAG_N, TESTN(r));
        SETCC(this.FLAG_Z, this.test_z8(r));
        SETCC(this.FLAG_V, TESTV(i0, i1, r));
        SETCC(this.FLAG_C, this.test_c(i0, i1, r, 0));

        return r;
    }

    /* instruction: dec
     * essentially (data - 1).
     */
    //einline unsigned inst_dec (unsigned data)
    this.inst_dec = function( data )
    {
        //unsigned i0, i1, r;

        var i0 = data;
        var i1 = 0xff;
        var r = i0 + i1;

        SETCC(this.FLAG_N, TESTN(r));
        SETCC(this.FLAG_Z, this.test_z8(r));
        SETCC(this.FLAG_V, TESTV(i0, i1, r));

        return r;
    }

    /* instruction: inc
     * essentially (data + 1).
     */
    //einline unsigned inst_inc (unsigned data)
    this.inst_inc = function( data )
    {
        //unsigned i0, i1, r;

        var i0 = data;
        var i1 = 1;
        var r = i0 + i1;

        SETCC(this.FLAG_N, TESTN(r));
        SETCC(this.FLAG_Z, this.test_z8(r));
        SETCC(this.FLAG_V, TESTV(i0, i1, r));

        return r;
    }

    /* instruction: tst */
    //einline void inst_tst8 (unsigned data)
    this.inst_tst8 = function( data )
    {
        SETCC(this.FLAG_N, TESTN(data));
        SETCC(this.FLAG_Z, this.test_z8(data));
        SETCC(this.FLAG_V, 0);
    }

    //einline void inst_tst16 (unsigned data)
    this.inst_tst16 = function( data )
    {
        SETCC(this.FLAG_N, TESTN(data >> 8));
        SETCC(this.FLAG_Z, this.test_z16(data));
        SETCC(this.FLAG_V, 0);
    }

    /* instruction: clr */
    //einline void inst_clr (void)
    this.inst_clr = function()
    {
        SETCC(this.FLAG_N, 0);
        SETCC(this.FLAG_Z, 1);
        SETCC(this.FLAG_V, 0);
        SETCC(this.FLAG_C, 0);
    }

    /* instruction: suba/subb */

    //einline unsigned inst_sub8 (unsigned data0, unsigned data1)
    this.inst_sub8 = function( data0, data1 )
    {
        //unsigned i0, i1, r;

        var i0 = data0;
        var i1 = (~data1) & 0xffff; // raz
        var r = i0 + i1 + 1;

        SETCC(this.FLAG_H, this.test_c(i0 << 4, i1 << 4, r << 4, 0));
        SETCC(this.FLAG_N, TESTN(r));
        SETCC(this.FLAG_Z, this.test_z8(r));
        SETCC(this.FLAG_V, TESTV(i0, i1, r));
        SETCC(this.FLAG_C, this.test_c(i0, i1, r, 1));

        return r;
    }

    /* instruction: sbca/sbcb/cmpa/cmpb.
     * only 8-bit version, 16-bit version not needed.
     */
    //einline unsigned inst_sbc (unsigned data0, unsigned data1)
    this.inst_sbc = function( data0, data1 )
    {
        //unsigned i0, i1, c, r;

        var i0 = data0;
        var i1 = (~data1) & 0xffff; //raz
        var c = 1 - GETCC(this.FLAG_C);
        var r = i0 + i1 + c;

        SETCC(this.FLAG_H, this.test_c(i0 << 4, i1 << 4, r << 4, 0));
        SETCC(this.FLAG_N, TESTN(r));
        SETCC(this.FLAG_Z, this.test_z8(r));
        SETCC(this.FLAG_V, TESTV(i0, i1, r));
        SETCC(this.FLAG_C, this.test_c(i0, i1, r, 1));

        return r;
    }

    /* instruction: anda/andb/bita/bitb.
     * only 8-bit version, 16-bit version not needed.
     */
    //einline unsigned inst_and (unsigned data0, unsigned data1)
    this.inst_and = function( data0, data1 )
    {
        //unsigned r;
        var r = data0 & data1;
        this.inst_tst8(r);
        return r;
    }

    /* instruction: eora/eorb.
     * only 8-bit version, 16-bit version not needed.
     */
    //einline unsigned inst_eor (unsigned data0, unsigned data1)
    this.inst_eor = function ( data0, data1 )
    {
        //unsigned r;

        var r = data0 ^ data1;
        this.inst_tst8(r);
        return r;
    }

    /* instruction: adca/adcb
     * only 8-bit version, 16-bit version not needed.
     */
    //einline unsigned inst_adc (unsigned data0, unsigned data1)
    this.inst_adc = function ( data0, data1 )
    {
        //unsigned i0, i1, c, r;

        var i0 = data0;
        var i1 = data1;
        var c = GETCC(this.FLAG_C);
        var r = i0 + i1 + c;

        SETCC(this.FLAG_H, this.test_c(i0 << 4, i1 << 4, r << 4, 0));
        SETCC(this.FLAG_N, TESTN(r));
        SETCC(this.FLAG_Z, this.test_z8(r));
        SETCC(this.FLAG_V, TESTV(i0, i1, r));
        SETCC(this.FLAG_C, this.test_c(i0, i1, r, 0));

        return r;
    }

    /* instruction: ora/orb.
     * only 8-bit version, 16-bit version not needed.
     */
    //einline unsigned inst_or (unsigned data0, unsigned data1)
    this.inst_or = function( data0, data1 )
    {
        //unsigned r;
        var r = data0 | data1;
        this.inst_tst8(r);
        return r;
    }

    /* instruction: adda/addb */
    //einline unsigned inst_add8 (unsigned data0, unsigned data1)
    this.inst_add8 = function( data0, data1 )
    {
        //unsigned i0, i1, r;

        var i0 = data0;
        var i1 = data1;
        var r = i0 + i1;

        SETCC(this.FLAG_H, this.test_c(i0 << 4, i1 << 4, r << 4, 0));
        SETCC(this.FLAG_N, TESTN(r));
        SETCC(this.FLAG_Z, this.test_z8(r));
        SETCC(this.FLAG_V, TESTV(i0, i1, r));
        SETCC(this.FLAG_C, this.test_c(i0, i1, r, 0));

        return r;
    }

    /* instruction: addd */
    //einline unsigned inst_add16 (unsigned data0, unsigned data1)
    this.inst_add16 = function( data0, data1 )
    {
        //unsigned i0, i1, r;

        var i0 = data0;
        var i1 = data1;
        var r = i0 + i1;

        SETCC(this.FLAG_N, TESTN(r >> 8));
        SETCC(this.FLAG_Z, this.test_z16(r));
        SETCC(this.FLAG_V, this.test_v(i0 >> 8, i1 >> 8, r >> 8));
        SETCC(this.FLAG_C, this.test_c(i0 >> 8, i1 >> 8, r >> 8, 0));

        return r;
    }

    /* instruction: subd */
    //einline unsigned inst_sub16 (unsigned data0, unsigned data1)
    this.inst_sub16 = function( data0, data1 )
    {
        //unsigned i0, i1, r;

        var i0 = data0;
        var i1 = (~data1) & 0xffff; // raz
        var r = i0 + i1 + 1;

        SETCC(this.FLAG_N, TESTN(r >> 8));
        SETCC(this.FLAG_Z, this.test_z16(r));
        SETCC(this.FLAG_V, this.test_v(i0 >> 8, i1 >> 8, r >> 8));
        SETCC(this.FLAG_C, this.test_c(i0 >> 8, i1 >> 8, r >> 8, 1));

        return r;
    }

    /* instruction: 8-bit offset branch */
    //einline void inst_bra8 (unsigned test, unsigned op, unsigned *cycles)
    this.inst_bra8 = function ( test, op, cycles )
    {
        //unsigned offset, mask;

        var offset = this.vecx.read8(this.reg_pc++);

        /* trying to avoid an if statement */

        var mask = (test ^ (op & 1)) - 1;
        /* 0xffff when taken, 0 when not taken */
        this.reg_pc += this.sign_extend(offset) & mask;

        //*cycles += 3;        
        cycles.value+=(3);
    }

    /* instruction: 16-bit offset branch */

    //einline void inst_bra16 (unsigned test, unsigned op, unsigned *cycles)
    this.inst_bra16 = function( test, op, cycles )
    {
        //unsigned offset, mask;

        var offset = this.pc_read16();

        /* trying to avoid an if statement */

        var mask = (test ^ (op & 1)) - 1;
        /* 0xffff when taken, 0 when not taken */
        this.reg_pc += offset & mask;

        //*cycles += 5 - mask;
        cycles.value+=(5 - mask);
    }

    /* instruction: pshs/pshu */

    //einline void inst_psh (unsigned op, unsigned *sp,
    //unsigned data, unsigned *cycles)
    this.inst_psh = function ( op, sp, data, cycles )
    {
        if( op & 0x80 )
        {
            this.push16(sp, this.reg_pc);
            //*cycles += 2;
            cycles.value+=(2);
        }

        if( op & 0x40 )
        {
            /* either s or u */
            this.push16(sp, data);
            //*cycles += 2;
            cycles.value+=(2);
        }

        if( op & 0x20 )
        {
            this.push16(sp, this.reg_y.value);
            //*cycles += 2;
            cycles.value+=(2);
        }

        if( op & 0x10 )
        {
            this.push16(sp, this.reg_x.value);
            //*cycles += 2;
            cycles.value+=(2);
        }

        if( op & 0x08 )
        {
            this.push8(sp, this.reg_dp);
            //*cycles += 1;
            cycles.value+=(1);
        }

        if( op & 0x04 )
        {
            this.push8(sp, this.reg_b);
            //*cycles += 1;
            cycles.value+=(1);
        }

        if( op & 0x02 )
        {
            this.push8(sp, this.reg_a);
            //*cycles += 1;
            cycles.value+=(1);
        }

        if( op & 0x01 )
        {
            this.push8(sp, this.reg_cc);
            //*cycles += 1;
            cycles.value+=(1);
        }
    }

    /* instruction: puls/pulu */
    //einline void inst_pul (unsigned op, unsigned *sp, unsigned *osp,
    //unsigned *cycles)
    this.inst_pul = function( op, sp, osp, cycles )
    {
        if( op & 0x01 )
        {
            //this.reg_cc;
            this.reg_cc = PULL8(sp);
            //*cycles += 1;
            cycles.value+=(1);
        }

        if( op & 0x02 )
        {
            //this.reg_a;
            this.reg_a = PULL8(sp);
            //*cycles += 1;
            cycles.value+=(1);
        }

        if( op & 0x04 )
        {
            //this.reg_b;
            this.reg_b = PULL8(sp);
            //*cycles += 1;
            cycles.value+=(1);
        }

        if( op & 0x08 )
        {
            //this.reg_dp;
            this.reg_dp = PULL8(sp);
            //*cycles += 1;
            cycles.value+=(1);
        }

        if( op & 0x10 )
        {
            //this.reg_x;
            this.reg_x.value=(this.pull16(sp));
            //*cycles += 2;
            cycles.value+=(2);
        }

        if( op & 0x20 )
        {
            //this.reg_y;
            this.reg_y.value=(this.pull16(sp));
            //*cycles += 2;
            cycles.value+=(2);
        }

        if( op & 0x40 )
        {
            /* either s or u */
            //*osp = pull16 (sp);
            osp.value=(this.pull16(sp));
            //*cycles += 2;
            cycles.value+=(2);
        }

        if( op & 0x80 )
        {
            //this.reg_pc;
            this.reg_pc = this.pull16(sp);
            //*cycles += 2;
            cycles.value+=(2);
        }
    }

    //einline unsigned exgtfr_read (unsigned reg)
    this.exgtfr_read = function( reg )
    {
        //unsigned data;
        var data = 0;

        switch( reg )
        {
            case 0x0:
                data = GETREGD();
                break;
            case 0x1:
                data = this.reg_x.value;
                break;
            case 0x2:
                data = this.reg_y.value;
                break;
            case 0x3:
                data = this.reg_u.value;
                break;
            case 0x4:
                data = this.reg_s.value;
                break;
            case 0x5:
                data = this.reg_pc;
                break;
            case 0x8:
                data = 0xff00 | this.reg_a;
                break;
            case 0x9:
                data = 0xff00 | this.reg_b;
                break;
            case 0xa:
                data = 0xff00 | this.reg_cc;
                break;
            case 0xb:
                data = 0xff00 | this.reg_dp;
                break;
            default:
                data = 0xffff;
                //printf ("illegal exgtfr reg %.1x\n", reg);
                utils.showError("illegal exgtfr reg" + reg);
                break;
        }

        return data;
    }

    //einline void exgtfr_write (unsigned reg, unsigned data)
    this.exgtfr_write = function( reg, data )
    {
        switch( reg )
        {
            case 0x0:
                this.set_reg_d(data);
                break;
            case 0x1:
                this.reg_x.value=(data);
                break;
            case 0x2:
                this.reg_y.value=(data);
                break;
            case 0x3:
                this.reg_u.value=(data);
                break;
            case 0x4:
                this.reg_s.value=(data);
                break;
            case 0x5:
                this.reg_pc = data;
                break;
            case 0x8:
                this.reg_a = data;
                break;
            case 0x9:
                this.reg_b = data;
                break;
            case 0xa:
                this.reg_cc = data;
                break;
            case 0xb:
                this.reg_dp = data;
                break;
            default:
                //printf ("illegal exgtfr reg %.1x\n", reg);
                utils.showError("illegal exgtfr reg " + reg)
                break;
        }
    }

    /* instruction: exg */
    //einline void inst_exg (void)
    this.inst_exg = function()
    {
        //unsigned op, tmp;

        var op = this.vecx.read8(this.reg_pc++);

        var tmp = this.exgtfr_read(op & 0xf);
        this.exgtfr_write(op & 0xf, this.exgtfr_read(op >> 4));
        this.exgtfr_write(op >> 4, tmp);
    }

    /* instruction: tfr */
    //einline void inst_tfr (void)
    this.inst_tfr = function()
    {
        //unsigned op;

        var op = this.vecx.read8(this.reg_pc++);

        this.exgtfr_write(op & 0xf, this.exgtfr_read(op >> 4));
    }

    /* reset the 6809 */

    //void e6809_reset (void)
    this.e6809_reset = function()
    {
        this.reg_x.value=(0);
        this.reg_y.value=(0);
        this.reg_u.value=(0);
        this.reg_s.value=(0);

        this.reg_a = 0;
        this.reg_b = 0;

        this.reg_dp = 0;

        this.reg_cc = this.FLAG_I | this.FLAG_F;
        this.irq_status = this.IRQ_NORMAL;

        this.reg_pc = this.read16(0xfffe);
    }

    this.cycles = new fptr(0);

    /* execute a single instruction or handle interrupts and return */
    //unsigned e6809_sstep (unsigned irq_i, unsigned irq_f)
    this.e6809_sstep = function( irq_i, irq_f )
    {
        //unsigned op;
        //unsigned cycles = 0;
        //unsigned ea, i0, i1, r;        

        var op = 0;
        var cycles = this.cycles;
        cycles.value=(0);
        var ea = 0;
        var i0 = 0;
        var i1 = 0;
        var r = 0;

        if( irq_f )
        {
            if( GETCC(this.FLAG_F) == 0 )
            {
                if( this.irq_status != this.IRQ_CWAI )
                {
                    SETCC(this.FLAG_E, 0);
                    //inst_psh (0x81, &reg_s, reg_u, &cycles);
                    this.inst_psh(0x81, this.reg_s, this.reg_u.value, cycles);
                }

                SETCC(this.FLAG_I, 1);
                SETCC(this.FLAG_F, 1);

                this.reg_pc = this.read16(0xfff6);
                this.irq_status = this.IRQ_NORMAL;
                //cycles += 7;
                cycles.value+=(7);

            }
            else
            {
                if( this.irq_status == this.IRQ_SYNC )
                {
                    this.irq_status = this.IRQ_NORMAL;
                }
            }
        }

        if( irq_i )
        {
            if( GETCC(this.FLAG_I) == 0 )
            {
                if( this.irq_status != this.IRQ_CWAI )
                {
                    SETCC(this.FLAG_E, 1);
                    //inst_psh (0xff, &reg_s, reg_u, &cycles);
                    this.inst_psh(0xff, this.reg_s, this.reg_u.value, cycles);
                }

                SETCC(this.FLAG_I, 1);

                this.reg_pc = this.read16(0xfff8);
                this.irq_status = this.IRQ_NORMAL;
                //cycles += 7;
                cycles.value+=(7);
            }
            else
            {
                if( this.irq_status == this.IRQ_SYNC )
                {
                    this.irq_status = this.IRQ_NORMAL;
                }
            }
        }

        if( this.irq_status != this.IRQ_NORMAL )
        {
            return cycles.value + 1;
        }

        op = this.vecx.read8(this.reg_pc++);

        switch( op )
        {
        /* page 0 instructions */

        /* neg, nega, negb */
            case 0x00:
                ea = EADIRECT();
                r = this.inst_neg(this.vecx.read8(ea));
                this.vecx.write8(ea, r);
                //cycles += 6;
                cycles.value+=(6);
                break;
            case 0x40:
                this.reg_a = this.inst_neg(this.reg_a);
                //cycles += 2;
                cycles.value+=(2);
                break;
            case 0x50:
                this.reg_b = this.inst_neg(this.reg_b);
                //cycles += 2;
                cycles.value+=(2);
                break;
            case 0x60:
                ea = this.ea_indexed(cycles);
                r = this.inst_neg(this.vecx.read8(ea));
                this.vecx.write8(ea, r);
                //cycles += 6;
                cycles.value+=(6);
                break;
            case 0x70:
                ea = this.pc_read16();
                r = this.inst_neg(this.vecx.read8(ea));
                this.vecx.write8(ea, r);
                //cycles += 7;
                cycles.value+=(7);
                break;
            /* com, coma, comb */
            case 0x03:
                ea = EADIRECT();
                r = this.inst_com(this.vecx.read8(ea));
                this.vecx.write8(ea, r);
                //cycles += 6;
                cycles.value+=(6);
                break;
            case 0x43:
                this.reg_a = this.inst_com(this.reg_a);
                //cycles += 2;
                cycles.value+=(2);
                break;
            case 0x53:
                this.reg_b = this.inst_com(this.reg_b);
                //cycles += 2;
                cycles.value+=(2);
                break;
            case 0x63:
                ea = this.ea_indexed(cycles);
                r = this.inst_com(this.vecx.read8(ea));
                this.vecx.write8(ea, r);
                //cycles += 6;
                cycles.value+=(6);
                break;
            case 0x73:
                ea = this.pc_read16();
                r = this.inst_com(this.vecx.read8(ea));
                this.vecx.write8(ea, r);
                //cycles += 7;
                cycles.value+=(7);
                break;
            /* lsr, lsra, lsrb */
            case 0x04:
                ea = EADIRECT();
                r = this.inst_lsr(this.vecx.read8(ea));
                this.vecx.write8(ea, r);
                //cycles += 6;
                cycles.value+=(6);
                break;
            case 0x44:
                this.reg_a = this.inst_lsr(this.reg_a);
                //cycles += 2;
                cycles.value+=(2);
                break;
            case 0x54:
                this.reg_b = this.inst_lsr(this.reg_b);
                //cycles += 2;
                cycles.value+=(2);
                break;
            case 0x64:
                ea = this.ea_indexed(cycles);
                r = this.inst_lsr(this.vecx.read8(ea));
                this.vecx.write8(ea, r);
                //cycles += 6;
                cycles.value+=(6);
                break;
            case 0x74:
                ea = this.pc_read16();
                r = this.inst_lsr(this.vecx.read8(ea));
                this.vecx.write8(ea, r);
                //cycles += 7;
                cycles.value+=(7);
                break;
            /* ror, rora, rorb */
            case 0x06:
                ea = EADIRECT();
                r = this.inst_ror(this.vecx.read8(ea));
                this.vecx.write8(ea, r);
                //cycles += 6;
                cycles.value+=(6);
                break;
            case 0x46:
                this.reg_a = this.inst_ror(this.reg_a);
                //cycles += 2;
                cycles.value+=(2);
                break;
            case 0x56:
                this.reg_b = this.inst_ror(this.reg_b);
                //cycles += 2;
                cycles.value+=(2);
                break;
            case 0x66:
                ea = this.ea_indexed(cycles);
                r = this.inst_ror(this.vecx.read8(ea));
                this.vecx.write8(ea, r);
                //cycles += 6;
                cycles.value+=(6);
                break;
            case 0x76:
                ea = this.pc_read16();
                r = this.inst_ror(this.vecx.read8(ea));
                this.vecx.write8(ea, r);
                //cycles += 7;
                cycles.value+=(7);
                break;
            /* asr, asra, asrb */
            case 0x07:
                ea = EADIRECT();
                r = this.inst_asr(this.vecx.read8(ea));
                this.vecx.write8(ea, r);
                //cycles += 6;
                cycles.value+=(6);
                break;
            case 0x47:
                this.reg_a = this.inst_asr(this.reg_a);
                //cycles += 2;
                cycles.value+=(2);
                break;
            case 0x57:
                this.reg_b = this.inst_asr(this.reg_b);
                //cycles += 2;
                cycles.value+=(2);
                break;
            case 0x67:
                ea = this.ea_indexed(cycles);
                r = this.inst_asr(this.vecx.read8(ea));
                this.vecx.write8(ea, r);
                //cycles += 6;
                cycles.value+=(6);
                break;
            case 0x77:
                ea = this.pc_read16();
                r = this.inst_asr(this.vecx.read8(ea));
                this.vecx.write8(ea, r);
                //cycles += 7;
                cycles.value+=(7);
                break;
            /* asl, asla, aslb */
            case 0x08:
                ea = EADIRECT();
                r = this.inst_asl(this.vecx.read8(ea));
                this.vecx.write8(ea, r);
                //cycles += 6;
                cycles.value+=(6);
                break;
            case 0x48:
                this.reg_a = this.inst_asl(this.reg_a);
            //cycles += 2;
                cycles.value+=(2);
                break;
            case 0x58:
                this.reg_b = this.inst_asl(this.reg_b);
                //cycles += 2;
                cycles.value+=(2);
                break;
            case 0x68:
                ea = this.ea_indexed(cycles);
                r = this.inst_asl(this.vecx.read8(ea));
                this.vecx.write8(ea, r);
                //cycles += 6;
                cycles.value+=(6);
                break;
            case 0x78:
                ea = this.pc_read16();
                r = this.inst_asl(this.vecx.read8(ea));
                this.vecx.write8(ea, r);
                //cycles += 7;
                cycles.value+=(7);
                break;
            /* rol, rola, rolb */
            case 0x09:
                ea = EADIRECT();
                r = this.inst_rol(this.vecx.read8(ea));
                this.vecx.write8(ea, r);
                //cycles += 6;
                cycles.value+=(6);
                break;
            case 0x49:
                this.reg_a = this.inst_rol(this.reg_a);
                //cycles += 2;
                cycles.value+=(2);
                break;
            case 0x59:
                this.reg_b = this.inst_rol(this.reg_b);
                //cycles += 2;
                cycles.value+=(2);
                break;
            case 0x69:
                ea = this.ea_indexed(cycles);
                r = this.inst_rol(this.vecx.read8(ea));
                this.vecx.write8(ea, r);
                //cycles += 6;
                cycles.value+=(6);
                break;
            case 0x79:
                ea = this.pc_read16();
                r = this.inst_rol(this.vecx.read8(ea));
                this.vecx.write8(ea, r);
                //cycles += 7;
                cycles.value+=(7);
                break;
            /* dec, deca, decb */
            case 0x0a:
                ea = EADIRECT();
                r = this.inst_dec(this.vecx.read8(ea));
                this.vecx.write8(ea, r);
                //cycles += 6;
                cycles.value+=(6);
                break;
            case 0x4a:
                this.reg_a = this.inst_dec(this.reg_a);
                //cycles += 2;
                cycles.value+=(2);
                break;
            case 0x5a:
                this.reg_b = this.inst_dec(this.reg_b);
                //cycles += 2;
                cycles.value+=(2);
                break;
            case 0x6a:
                ea = this.ea_indexed(cycles);
                r = this.inst_dec(this.vecx.read8(ea));
                this.vecx.write8(ea, r);
                //cycles += 6;
                cycles.value+=(6);
                break;
            case 0x7a:
                ea = this.pc_read16();
                r = this.inst_dec(this.vecx.read8(ea));
                this.vecx.write8(ea, r);
                //cycles += 7;
                cycles.value+=(7);
                break;
            /* inc, inca, incb */
            case 0x0c:
                ea = EADIRECT();
                r = this.inst_inc(this.vecx.read8(ea));
                this.vecx.write8(ea, r);
                //cycles += 6;
                cycles.value+=(6);
                break;
            case 0x4c:
                this.reg_a = this.inst_inc(this.reg_a);
                //cycles += 2;
                cycles.value+=(2);
                break;
            case 0x5c:
                this.reg_b = this.inst_inc(this.reg_b);
                //cycles += 2;
                cycles.value+=(2);
                break;
            case 0x6c:
                ea = this.ea_indexed(cycles);
                r = this.inst_inc(this.vecx.read8(ea));
                this.vecx.write8(ea, r);
                //cycles += 6;
                cycles.value+=(6);
                break;
            case 0x7c:
                ea = this.pc_read16();
                r = this.inst_inc(this.vecx.read8(ea));
                this.vecx.write8(ea, r);
                //cycles += 7;
                cycles.value+=(7);
                break;
            /* tst, tsta, tstb */
            case 0x0d:
                ea = EADIRECT();
                this.inst_tst8(this.vecx.read8(ea));
                //cycles += 6;
                cycles.value+=(6);
                break;
            case 0x4d:
                this.inst_tst8(this.reg_a);
                //cycles += 2;
                cycles.value+=(2);
                break;
            case 0x5d:
                this.inst_tst8(this.reg_b);
                //cycles += 2;
                cycles.value+=(2);
                break;
            case 0x6d:
                ea = this.ea_indexed(cycles);
                this.inst_tst8(this.vecx.read8(ea));
                //cycles += 6;
                cycles.value+=(6);
                break;
            case 0x7d:
                ea = this.pc_read16();
                this.inst_tst8(this.vecx.read8(ea));
                //cycles += 7;
                cycles.value+=(7);
                break;
            /* jmp */
            case 0x0e:
                this.reg_pc = EADIRECT();
                //cycles += 3;
                cycles.value+=(3);
                break;
            case 0x6e:
                this.reg_pc = this.ea_indexed(cycles);
                //cycles += 3;
                cycles.value+=(3);
                break;
            case 0x7e:
                this.reg_pc = this.pc_read16();
                //cycles += 4;
                cycles.value+=(4);
                break;
            /* clr */
            case 0x0f:
                ea = EADIRECT();
                this.inst_clr();
                this.vecx.write8(ea, 0);
                //cycles += 6;
                cycles.value+=(6);
                break;
            case 0x4f:
                this.inst_clr();
                this.reg_a = 0;
                //cycles += 2;
                cycles.value+=(2);
                break;
            case 0x5f:
                this.inst_clr();
                this.reg_b = 0;
                //cycles += 2;
                cycles.value+=(2);
                break;
            case 0x6f:
                ea = this.ea_indexed(cycles);
                this.inst_clr();
                this.vecx.write8(ea, 0);
                //cycles += 6;
                cycles.value+=(6);
                break;
            case 0x7f:
                ea = this.pc_read16();
                this.inst_clr();
                this.vecx.write8(ea, 0);
                //cycles += 7;
                cycles.value+=(7);
                break;
            /* suba */
            case 0x80:
                this.reg_a = this.inst_sub8(this.reg_a, this.vecx.read8(this.reg_pc++));
                //cycles += 2;
                cycles.value+=(2);
                break;
            case 0x90:
                ea = EADIRECT();
                this.reg_a = this.inst_sub8(this.reg_a, this.vecx.read8(ea));
                //cycles += 4;
                cycles.value+=(4);
                break;
            case 0xa0:
                ea = this.ea_indexed(cycles);
                this.reg_a = this.inst_sub8(this.reg_a, this.vecx.read8(ea));
                //cycles += 4;
                cycles.value+=(4);
                break;
            case 0xb0:
                ea = this.pc_read16();
                this.reg_a = this.inst_sub8(this.reg_a, this.vecx.read8(ea));
                //cycles += 5;
                cycles.value+=(5);
                break;
            /* subb */
            case 0xc0:
                this.reg_b = this.inst_sub8(this.reg_b, this.vecx.read8(this.reg_pc++));
                //cycles += 2;
                cycles.value+=(2);
                break;
            case 0xd0:
                ea = EADIRECT();
                this.reg_b = this.inst_sub8(this.reg_b, this.vecx.read8(ea));
                //cycles += 4;
                cycles.value+=(4);
                break;
            case 0xe0:
                ea = this.ea_indexed(cycles);
                this.reg_b = this.inst_sub8(this.reg_b, this.vecx.read8(ea));
                //cycles += 4;
                cycles.value+=(4);
                break;
            case 0xf0:
                ea = this.pc_read16();
                this.reg_b = this.inst_sub8(this.reg_b, this.vecx.read8(ea));
                //cycles += 5;
                cycles.value+=(5);
                break;
            /* cmpa */
            case 0x81:
                this.inst_sub8(this.reg_a, this.vecx.read8(this.reg_pc++));
                //cycles += 2;
                cycles.value+=(2);
                break;
            case 0x91:
                ea = EADIRECT();
                this.inst_sub8(this.reg_a, this.vecx.read8(ea));
                //cycles += 4;
                cycles.value+=(4);
                break;
            case 0xa1:
                ea = this.ea_indexed(cycles);
                this.inst_sub8(this.reg_a, this.vecx.read8(ea));
                //cycles += 4;
                cycles.value+=(4);
                break;
            case 0xb1:
                ea = this.pc_read16();
                this.inst_sub8(this.reg_a, this.vecx.read8(ea));
                //cycles += 5;
                cycles.value+=(5);
                break;
            /* cmpb */
            case 0xc1:
                this.inst_sub8(this.reg_b, this.vecx.read8(this.reg_pc++));
                //cycles += 2;
                cycles.value+=(2);
                break;
            case 0xd1:
                ea = EADIRECT();
                this.inst_sub8(this.reg_b, this.vecx.read8(ea));
                //cycles += 4;
                cycles.value+=(4);
                break;
            case 0xe1:
                ea = this.ea_indexed(cycles);
                this.inst_sub8(this.reg_b, this.vecx.read8(ea));
                //cycles += 4;
                cycles.value+=(4);
                break;
            case 0xf1:
                ea = this.pc_read16();
                this.inst_sub8(this.reg_b, this.vecx.read8(ea));
                //cycles += 5;
                cycles.value+=(5);
                break;
            /* sbca */
            case 0x82:
                this.reg_a = this.inst_sbc(this.reg_a, this.vecx.read8(this.reg_pc++));
                //cycles += 2;
                cycles.value+=(2);
                break;
            case 0x92:
                ea = EADIRECT();
                this.reg_a = this.inst_sbc(this.reg_a, this.vecx.read8(ea));
                //cycles += 4;
                cycles.value+=(4);
                break;
            case 0xa2:
                ea = this.ea_indexed(cycles);
                this.reg_a = this.inst_sbc(this.reg_a, this.vecx.read8(ea));
                //cycles += 4;
                cycles.value+=(4);
                break;
            case 0xb2:
                ea = this.pc_read16();
                this.reg_a = this.inst_sbc(this.reg_a, this.vecx.read8(ea));
                //cycles += 5;
                cycles.value+=(5);
                break;
            /* sbcb */
            case 0xc2:
                this.reg_b = this.inst_sbc(this.reg_b, this.vecx.read8(this.reg_pc++));
                //cycles += 2;
                cycles.value+=(2);
                break;
            case 0xd2:
                ea = EADIRECT();
                this.reg_b = this.inst_sbc(this.reg_b, this.vecx.read8(ea));
                //cycles += 4;
                cycles.value+=(4);
                break;
            case 0xe2:
                ea = this.ea_indexed(cycles);
                this.reg_b = this.inst_sbc(this.reg_b, this.vecx.read8(ea));
                //cycles += 4;
                cycles.value+=(4);
                break;
            case 0xf2:
                ea = this.pc_read16();
                this.reg_b = this.inst_sbc(this.reg_b, this.vecx.read8(ea));
                //cycles += 5;
                cycles.value+=(5);
                break;
            /* anda */
            case 0x84:
                this.reg_a = this.inst_and(this.reg_a, this.vecx.read8(this.reg_pc++));
                //cycles += 2;
                cycles.value+=(2);
                break;
            case 0x94:
                ea = EADIRECT();
                this.reg_a = this.inst_and(this.reg_a, this.vecx.read8(ea));
                //cycles += 4;
                cycles.value+=(4);
                break;
            case 0xa4:
                ea = this.ea_indexed(cycles);
                this.reg_a = this.inst_and(this.reg_a, this.vecx.read8(ea));
                //cycles += 4;
                cycles.value+=(4);
                break;
            case 0xb4:
                ea = this.pc_read16();
                this.reg_a = this.inst_and(this.reg_a, this.vecx.read8(ea));
                //cycles += 5;
                cycles.value+=(5);
                break;
            /* andb */
            case 0xc4:
                this.reg_b = this.inst_and(this.reg_b, this.vecx.read8(this.reg_pc++));
                //cycles += 2;
                cycles.value+=(2);
                break;
            case 0xd4:
                ea = EADIRECT();
                this.reg_b = this.inst_and(this.reg_b, this.vecx.read8(ea));
                //cycles += 4;
                cycles.value+=(4);
                break;
            case 0xe4:
                ea = this.ea_indexed(cycles);
                this.reg_b = this.inst_and(this.reg_b, this.vecx.read8(ea));
                //cycles += 4;
                cycles.value+=(4);
                break;
            case 0xf4:
                ea = this.pc_read16();
                this.reg_b = this.inst_and(this.reg_b, this.vecx.read8(ea));
                //cycles += 5;
                cycles.value+=(5);
                break;
            /* bita */
            case 0x85:
                this.inst_and(this.reg_a, this.vecx.read8(this.reg_pc++));
                //cycles += 2;
                cycles.value+=(2);
                break;
            case 0x95:
                ea = EADIRECT();
                this.inst_and(this.reg_a, this.vecx.read8(ea));
                //cycles += 4;
                cycles.value+=(4);
                break;
            case 0xa5:
                ea = this.ea_indexed(cycles);
                this.inst_and(this.reg_a, this.vecx.read8(ea));
                //cycles += 4;
                cycles.value+=(4);
                break;
            case 0xb5:
                ea = this.pc_read16();
                this.inst_and(this.reg_a, this.vecx.read8(ea));
                //cycles += 5;
                cycles.value+=(5);
                break;
            /* bitb */
            case 0xc5:
                this.inst_and(this.reg_b, this.vecx.read8(this.reg_pc++));
                //cycles += 2;
                cycles.value+=(2);
                break;
            case 0xd5:
                ea = EADIRECT();
                this.inst_and(this.reg_b, this.vecx.read8(ea));
                //cycles += 4;
                cycles.value+=(4);
                break;
            case 0xe5:
                ea = this.ea_indexed(cycles);
                this.inst_and(this.reg_b, this.vecx.read8(ea));
                //cycles += 4;
                cycles.value+=(4);
                break;
            case 0xf5:
                ea = this.pc_read16();
                this.inst_and(this.reg_b, this.vecx.read8(ea));
                //cycles += 5;
                cycles.value+=(5);
                break;
            /* lda */
            case 0x86:
                this.reg_a = this.vecx.read8(this.reg_pc++);
                this.inst_tst8(this.reg_a);
                //cycles += 2;
                cycles.value+=(2);
                break;
            case 0x96:
                ea = EADIRECT();
                this.reg_a = this.vecx.read8(ea);
                this.inst_tst8(this.reg_a);
                //cycles += 4;
                cycles.value+=(4);
                break;
            case 0xa6:
                ea = this.ea_indexed(cycles);
                this.reg_a = this.vecx.read8(ea);
                this.inst_tst8(this.reg_a);
                //cycles += 4;
                cycles.value+=(4);
                break;
            case 0xb6:
                ea = this.pc_read16();
                this.reg_a = this.vecx.read8(ea);
                this.inst_tst8(this.reg_a);
                //cycles += 5;
                cycles.value+=(5);
                break;
            /* ldb */
            case 0xc6:
                this.reg_b = this.vecx.read8(this.reg_pc++);
                this.inst_tst8(this.reg_b);
                //cycles += 2;
                cycles.value+=(2);
                break;
            case 0xd6:
                ea = EADIRECT();
                this.reg_b = this.vecx.read8(ea);
                this.inst_tst8(this.reg_b);
                //cycles += 4;
                cycles.value+=(4);
                break;
            case 0xe6:
                ea = this.ea_indexed(cycles);
                this.reg_b = this.vecx.read8(ea);
                this.inst_tst8(this.reg_b);
                //cycles += 4;
                cycles.value+=(4);
                break;
            case 0xf6:
                ea = this.pc_read16();
                this.reg_b = this.vecx.read8(ea);
                this.inst_tst8(this.reg_b);
                //cycles += 5;
                cycles.value+=(5);
                break;
            /* sta */
            case 0x97:
                ea = EADIRECT();
                this.vecx.write8(ea, this.reg_a);
                this.inst_tst8(this.reg_a);
                //cycles += 4;
                cycles.value+=(4);
                break;
            case 0xa7:
                ea = this.ea_indexed(cycles);
                this.vecx.write8(ea, this.reg_a);
                this.inst_tst8(this.reg_a);
                //cycles += 4;
                cycles.value+=(4);
                break;
            case 0xb7:
                ea = this.pc_read16();
                this.vecx.write8(ea, this.reg_a);
                this.inst_tst8(this.reg_a);
                //cycles += 5;
                cycles.value+=(5);
                break;
            /* stb */
            case 0xd7:
                ea = EADIRECT();
                this.vecx.write8(ea, this.reg_b);
                this.inst_tst8(this.reg_b);
                //cycles += 4;
                cycles.value+=(4);
                break;
            case 0xe7:
                ea = this.ea_indexed(cycles);
                this.vecx.write8(ea, this.reg_b);
                this.inst_tst8(this.reg_b);
                //cycles += 4;
                cycles.value+=(4);
                break;
            case 0xf7:
                ea = this.pc_read16();
                this.vecx.write8(ea, this.reg_b);
                this.inst_tst8(this.reg_b);
                //cycles += 5;
                cycles.value+=(5);
                break;
            /* eora */
            case 0x88:
                this.reg_a = this.inst_eor(this.reg_a, this.vecx.read8(this.reg_pc++));
                //cycles += 2;
                cycles.value+=(2);
                break;
            case 0x98:
                ea = EADIRECT();
                this.reg_a = this.inst_eor(this.reg_a, this.vecx.read8(ea));
                //cycles += 4;
                cycles.value+=(4);
                break;
            case 0xa8:
                ea = this.ea_indexed(cycles);
                this.reg_a = this.inst_eor(this.reg_a, this.vecx.read8(ea));
                //cycles += 4;
                cycles.value+=(4);
                break;
            case 0xb8:
                ea = this.pc_read16();
                this.reg_a = this.inst_eor(this.reg_a, this.vecx.read8(ea));
                //cycles += 5;
                cycles.value+=(5);
                break;
            /* eorb */
            case 0xc8:
                this.reg_b = this.inst_eor(this.reg_b, this.vecx.read8(this.reg_pc++));
                //cycles += 2;
                cycles.value+=(2);
                break;
            case 0xd8:
                ea = EADIRECT();
                this.reg_b = this.inst_eor(this.reg_b, this.vecx.read8(ea));
                //cycles += 4;
                cycles.value+=(4);
                break;
            case 0xe8:
                ea = this.ea_indexed(cycles);
                this.reg_b = this.inst_eor(this.reg_b, this.vecx.read8(ea));
                //cycles += 4;
                cycles.value+=(4);
                break;
            case 0xf8:
                ea = this.pc_read16();
                this.reg_b = this.inst_eor(this.reg_b, this.vecx.read8(ea));
                //cycles += 5;
                cycles.value+=(5);
                break;
            /* adca */
            case 0x89:
                this.reg_a = this.inst_adc(this.reg_a, this.vecx.read8(this.reg_pc++));
                //cycles += 2;
                cycles.value+=(2);
                break;
            case 0x99:
                ea = EADIRECT();
                this.reg_a = this.inst_adc(this.reg_a, this.vecx.read8(ea));
                //cycles += 4;
                cycles.value+=(4);
                break;
            case 0xa9:
                ea = this.ea_indexed(cycles);
                this.reg_a = this.inst_adc(this.reg_a, this.vecx.read8(ea));
                //cycles += 4;
                cycles.value+=(4);
                break;
            case 0xb9:
                ea = this.pc_read16();
                this.reg_a = this.inst_adc(this.reg_a, this.vecx.read8(ea));
                //cycles += 5;
                cycles.value+=(5);
                break;
            /* adcb */
            case 0xc9:
                this.reg_b = this.inst_adc(this.reg_b, this.vecx.read8(this.reg_pc++));
                //cycles += 2;
                cycles.value+=(2);
                break;
            case 0xd9:
                ea = EADIRECT();
                this.reg_b = this.inst_adc(this.reg_b, this.vecx.read8(ea));
                //cycles += 4;
                cycles.value+=(4);
                break;
            case 0xe9:
                ea = this.ea_indexed(cycles);
                this.reg_b = this.inst_adc(this.reg_b, this.vecx.read8(ea));
                //cycles += 4;
                cycles.value+=(4);
                break;
            case 0xf9:
                ea = this.pc_read16();
                this.reg_b = this.inst_adc(this.reg_b, this.vecx.read8(ea));
                //cycles += 5;
                cycles.value+=(5);
                break;
            /* ora */
            case 0x8a:
                this.reg_a = this.inst_or(this.reg_a, this.vecx.read8(this.reg_pc++));
                //cycles += 2;
                cycles.value+=(2);
                break;
            case 0x9a:
                ea = EADIRECT();
                this.reg_a = this.inst_or(this.reg_a, this.vecx.read8(ea));
                //cycles += 4;
                cycles.value+=(4);
                break;
            case 0xaa:
                ea = this.ea_indexed(cycles);
                this.reg_a = this.inst_or(this.reg_a, this.vecx.read8(ea));
                //cycles += 4;
                cycles.value+=(4);
                break;
            case 0xba:
                ea = this.pc_read16();
                this.reg_a = this.inst_or(this.reg_a, this.vecx.read8(ea));
                //cycles += 5;
                cycles.value+=(5);
                break;
            /* orb */
            case 0xca:
                this.reg_b = this.inst_or(this.reg_b, this.vecx.read8(this.reg_pc++));
                //cycles += 2;
                cycles.value+=(2);
                break;
            case 0xda:
                ea = EADIRECT();
                this.reg_b = this.inst_or(this.reg_b, this.vecx.read8(ea));
                //cycles += 4;
                cycles.value+=(4);
                break;
            case 0xea:
                ea = this.ea_indexed(cycles);
                this.reg_b = this.inst_or(this.reg_b, this.vecx.read8(ea));
                //cycles += 4;
                cycles.value+=(4);
                break;
            case 0xfa:
                ea = this.pc_read16();
                this.reg_b = this.inst_or(this.reg_b, this.vecx.read8(ea));
                //cycles += 5;
                cycles.value+=(5);
                break;
            /* adda */
            case 0x8b:
                this.reg_a = this.inst_add8(this.reg_a, this.vecx.read8(this.reg_pc++));
                //cycles += 2;
                cycles.value+=(2);
                break;
            case 0x9b:
                ea = EADIRECT();
                this.reg_a = this.inst_add8(this.reg_a, this.vecx.read8(ea));
                //cycles += 4;
                cycles.value+=(4);
                break;
            case 0xab:
                ea = this.ea_indexed(cycles);
                this.reg_a = this.inst_add8(this.reg_a, this.vecx.read8(ea));
                //cycles += 4;
                cycles.value+=(4);
                break;
            case 0xbb:
                ea = this.pc_read16();
                this.reg_a = this.inst_add8(this.reg_a, this.vecx.read8(ea));
                //cycles += 5;
                cycles.value+=(5);
                break;
            /* addb */
            case 0xcb:
                this.reg_b = this.inst_add8(this.reg_b, this.vecx.read8(this.reg_pc++));
                //cycles += 2;
                cycles.value+=(2);
                break;
            case 0xdb:
                ea = EADIRECT();
                this.reg_b = this.inst_add8(this.reg_b, this.vecx.read8(ea));
                //cycles += 4;
                cycles.value+=(4);
                break;
            case 0xeb:
                ea = this.ea_indexed(cycles);
                this.reg_b = this.inst_add8(this.reg_b, this.vecx.read8(ea));
                //cycles += 4;
                cycles.value+=(4);
                break;
            case 0xfb:
                ea = this.pc_read16();
                this.reg_b = this.inst_add8(this.reg_b, this.vecx.read8(ea));
                //cycles += 5;
                cycles.value+=(5);
                break;
            /* subd */
            case 0x83:
                this.set_reg_d(this.inst_sub16(GETREGD(), this.pc_read16()));
                //cycles += 4;
                cycles.value+=(4);
                break;
            case 0x93:
                ea = EADIRECT();
                this.set_reg_d(this.inst_sub16(GETREGD(), this.read16(ea)));
                //cycles += 6;
                cycles.value+=(6);
                break;
            case 0xa3:
                ea = this.ea_indexed(cycles);
                this.set_reg_d(this.inst_sub16(GETREGD(), this.read16(ea)));
                //cycles += 6;
                cycles.value+=(6);
                break;
            case 0xb3:
                ea = this.pc_read16();
                this.set_reg_d(this.inst_sub16(GETREGD(), this.read16(ea)));
                //cycles += 7;
                cycles.value+=(7);
                break;
            /* cmpx */
            case 0x8c:
                this.inst_sub16(this.reg_x.value, this.pc_read16());
                //cycles += 4;
                cycles.value+=(4);
                break;
            case 0x9c:
                ea = EADIRECT();
                this.inst_sub16(this.reg_x.value, this.read16(ea));
                //cycles += 6;
                cycles.value+=(6);
                break;
            case 0xac:
                ea = this.ea_indexed(cycles);
                this.inst_sub16(this.reg_x.value, this.read16(ea));
                //cycles += 6;
                cycles.value+=(6);
                break;
            case 0xbc:
                ea = this.pc_read16();
                this.inst_sub16(this.reg_x.value, this.read16(ea));
                //cycles += 7;
                cycles.value+=(7);
                break;
            /* ldx */
            case 0x8e:
                this.reg_x.value=(this.pc_read16());
                this.inst_tst16(this.reg_x.value);
                //cycles += 3;
                cycles.value+=(3);
                break;
            case 0x9e:
                ea = EADIRECT();
                this.reg_x.value=(this.read16(ea));
                this.inst_tst16(this.reg_x.value);
                //cycles += 5;
                cycles.value+=(5);
                break;
            case 0xae:
                ea = this.ea_indexed(cycles);
                this.reg_x.value=(this.read16(ea));
                this.inst_tst16(this.reg_x.value);
                //cycles += 5;
                cycles.value+=(5);
                break;
            case 0xbe:
                ea = this.pc_read16();
                this.reg_x.value=(this.read16(ea));
                this.inst_tst16(this.reg_x.value);
                //cycles += 6;
                cycles.value+=(6);
                break;
            /* ldu */
            case 0xce:
                this.reg_u.value=(this.pc_read16());
                this.inst_tst16(this.reg_u.value);
                //cycles += 3;
                cycles.value+=(3);
                break;
            case 0xde:
                ea = EADIRECT();
                this.reg_u.value=(this.read16(ea));
                this.inst_tst16(this.reg_u.value);
                //cycles += 5;
                cycles.value+=(5);
                break;
            case 0xee:
                ea = this.ea_indexed(cycles);
                this.reg_u.value=(this.read16(ea));
                this.inst_tst16(this.reg_u.value);
                //cycles += 5;
                cycles.value+=(5);
                break;
            case 0xfe:
                ea = this.pc_read16();
                this.reg_u.value=(this.read16(ea));
                this.inst_tst16(this.reg_u.value);
                //cycles += 6;
                cycles.value+=(6);
                break;
            /* stx */
            case 0x9f:
                ea = EADIRECT();
                this.write16(ea, this.reg_x.value);
                this.inst_tst16(this.reg_x.value);
                //cycles += 5;
                cycles.value+=(5);
                break;
            case 0xaf:
                ea = this.ea_indexed(cycles);
                this.write16(ea, this.reg_x.value);
                this.inst_tst16(this.reg_x.value);
                //cycles += 5;
                cycles.value+=(5);
                break;
            case 0xbf:
                ea = this.pc_read16();
                this.write16(ea, this.reg_x.value);
                this.inst_tst16(this.reg_x.value);
                //cycles += 6;
                cycles.value+=(6);
                break;
            /* stu */
            case 0xdf:
                ea = EADIRECT();
                this.write16(ea, this.reg_u.value);
                this.inst_tst16(this.reg_u.value);
                //cycles += 5;
                cycles.value+=(5);
                break;
            case 0xef:
                ea = this.ea_indexed(cycles);
                this.write16(ea, this.reg_u.value);
                this.inst_tst16(this.reg_u.value);
                //cycles += 5;
                cycles.value+=(5);
                break;
            case 0xff:
                ea = this.pc_read16();
                this.write16(ea, this.reg_u.value);
                this.inst_tst16(this.reg_u.value);
                //cycles += 6;
                cycles.value+=(6);
                break;
            /* addd */
            case 0xc3:
                this.set_reg_d(this.inst_add16(GETREGD(), this.pc_read16()));
                //cycles += 4;
                cycles.value+=(4);
                break;
            case 0xd3:
                ea = EADIRECT();
                this.set_reg_d(this.inst_add16(GETREGD(), this.read16(ea)));
                //cycles += 6;
                cycles.value+=(6);
                break;
            case 0xe3:
                ea = this.ea_indexed(cycles);
                this.set_reg_d(this.inst_add16(GETREGD(), this.read16(ea)));
                //cycles += 6;
                cycles.value+=(6);
                break;
            case 0xf3:
                ea = this.pc_read16();
                this.set_reg_d(this.inst_add16(GETREGD(), this.read16(ea)));
                //cycles += 7;
                cycles.value+=(7);
                break;
            /* ldd */
            case 0xcc:
                this.set_reg_d(this.pc_read16());
                this.inst_tst16(GETREGD());
                //cycles += 3;
                cycles.value+=(3);
                break;
            case 0xdc:
                ea = EADIRECT();
                this.set_reg_d(this.read16(ea));
                this.inst_tst16(GETREGD());
                //cycles += 5;
                cycles.value+=(5);
                break;
            case 0xec:
                ea = this.ea_indexed(cycles);
                this.set_reg_d(this.read16(ea));
                this.inst_tst16(GETREGD());
                //cycles += 5;
                cycles.value+=(5);
                break;
            case 0xfc:
                ea = this.pc_read16();
                this.set_reg_d(this.read16(ea));
                this.inst_tst16(GETREGD());
                //cycles += 6;
                cycles.value+=(6);
                break;
            /* std */
            case 0xdd:
                ea = EADIRECT();
                this.write16(ea, GETREGD());
                this.inst_tst16(GETREGD());
                //cycles += 5;
                cycles.value+=(5);
                break;
            case 0xed:
                ea = this.ea_indexed(cycles);
                this.write16(ea, GETREGD());
                this.inst_tst16(GETREGD());
                //cycles += 5;
                cycles.value+=(5);
                break;
            case 0xfd:
                ea = this.pc_read16();
                this.write16(ea, GETREGD());
                this.inst_tst16(GETREGD());
                //cycles += 6;
                cycles.value+=(6);
                break;
            /* nop */
            case 0x12:
                //cycles += 2;
                cycles.value+=(2);
                break;
            /* mul */
            case 0x3d:
                r = (this.reg_a & 0xff) * (this.reg_b & 0xff);
                this.set_reg_d(r);

                SETCC(this.FLAG_Z, this.test_z16(r));
                SETCC(this.FLAG_C, (r >> 7) & 1);

                //cycles += 11;
                cycles.value+=(11);
                break;
            /* bra */
            case 0x20:
            /* brn */
            case 0x21:
                this.inst_bra8(0, op, cycles);
                break;
            /* bhi */
            case 0x22:
            /* bls */
            case 0x23:
                this.inst_bra8(GETCC(this.FLAG_C) | GETCC(this.FLAG_Z), op, cycles);
                break;
            /* bhs/bcc */
            case 0x24:
            /* blo/bcs */
            case 0x25:
                this.inst_bra8(GETCC(this.FLAG_C), op, cycles);
                break;
            /* bne */
            case 0x26:
            /* beq */
            case 0x27:
                this.inst_bra8(GETCC(this.FLAG_Z), op, cycles);
                break;
            /* bvc */
            case 0x28:
            /* bvs */
            case 0x29:
                this.inst_bra8(GETCC(this.FLAG_V), op, cycles);
                break;
            /* bpl */
            case 0x2a:
            /* bmi */
            case 0x2b:
                this.inst_bra8(GETCC(this.FLAG_N), op, cycles);
                break;
            /* bge */
            case 0x2c:
            /* blt */
            case 0x2d:
                this.inst_bra8(GETCC(this.FLAG_N) ^ GETCC(this.FLAG_V), op, cycles);
                break;
            /* bgt */
            case 0x2e:
            /* ble */
            case 0x2f:
                this.inst_bra8(GETCC(this.FLAG_Z) |
                               (GETCC(this.FLAG_N) ^ GETCC(this.FLAG_V)), op, cycles);
                break;
            /* lbra */
            case 0x16:
                r = this.pc_read16();
                this.reg_pc += r;
                //cycles += 5;
                cycles.value+=(5);
                break;
            /* lbsr */
            case 0x17:
                r = this.pc_read16();
                this.push16(this.reg_s, this.reg_pc);
                this.reg_pc += r;
                //cycles += 9;
                cycles.value+=(9);
                break;
            /* bsr */
            case 0x8d:
                r = this.vecx.read8(this.reg_pc++);
                this.push16(this.reg_s, this.reg_pc);
                this.reg_pc += this.sign_extend(r);
                //cycles += 7;
                cycles.value+=(7);
                break;
            /* jsr */
            case 0x9d:
                ea = EADIRECT();
                this.push16(this.reg_s, this.reg_pc);
                this.reg_pc = ea;
                //cycles += 7;
                cycles.value+=(7);
                break;
            case 0xad:
                ea = this.ea_indexed(cycles);
                this.push16(this.reg_s, this.reg_pc);
                this.reg_pc = ea;
                //cycles += 7;
                cycles.value+=(7);
                break;
            case 0xbd:
                ea = this.pc_read16();
                this.push16(this.reg_s, this.reg_pc);
                this.reg_pc = ea;
                //cycles += 8;
                cycles.value+=(8);
                break;
            /* leax */
            case 0x30:
                this.reg_x.value=(this.ea_indexed(cycles));
                SETCC(this.FLAG_Z, this.test_z16(this.reg_x.value));
                //cycles += 4;
                cycles.value+=(4);
                break;
            /* leay */
            case 0x31:
                this.reg_y.value=(this.ea_indexed(cycles));
                SETCC(this.FLAG_Z, this.test_z16(this.reg_y.value));
                //cycles += 4;
                cycles.value+=(4);
                break;
            /* leas */
            case 0x32:
                this.reg_s.value=(this.ea_indexed(cycles));
                //cycles += 4;
                cycles.value+=(4);
                break;
            /* leau */
            case 0x33:
                this.reg_u.value=(this.ea_indexed(cycles));
                //cycles += 4;
                cycles.value+=(4);
                break;
            /* pshs */
            case 0x34:
                this.inst_psh(this.vecx.read8(this.reg_pc++), this.reg_s, this.reg_u.value, cycles);
                //cycles += 5;
                cycles.value+=(5);
                break;
            /* puls */
            case 0x35:
                this.inst_pul(this.vecx.read8(this.reg_pc++), this.reg_s, this.reg_u, cycles);
                //cycles += 5;
                cycles.value+=(5);
                break;
            /* pshu */
            case 0x36:
                this.inst_psh(this.vecx.read8(this.reg_pc++), this.reg_u, this.reg_s.value, cycles);
                //cycles += 5;
                cycles.value+=(5);
                break;
            /* pulu */
            case 0x37:
                this.inst_pul(this.vecx.read8(this.reg_pc++), this.reg_u, this.reg_s, cycles);
                //cycles += 5;
                cycles.value+=(5);
                break;
            /* rts */
            case 0x39:
                this.reg_pc = this.pull16(this.reg_s);
                //cycles += 5;
                cycles.value+=(5);
                break;
            /* abx */
            case 0x3a:
                this.reg_x.value+=(this.reg_b & 0xff);
                //cycles += 3;
                cycles.value+=(3);
                break;
            /* orcc */
            case 0x1a:
                this.reg_cc |= this.vecx.read8(this.reg_pc++);
                //cycles += 3;
                cycles.value+=(3);
                break;
            /* andcc */
            case 0x1c:
                this.reg_cc &= this.vecx.read8(this.reg_pc++);
                //cycles += 3;
                cycles.value+=(3);
                break;
            /* sex */
            case 0x1d:
                this.set_reg_d(this.sign_extend(this.reg_b));
                SETCC(this.FLAG_N, TESTN(this.reg_a));
                SETCC(this.FLAG_Z, this.test_z16(GETREGD()));
                //cycles += 2;
                cycles.value+=(2);
                break;
            /* exg */
            case 0x1e:
                this.inst_exg();
                //cycles += 8;
                cycles.value+=(8);
                break;
            /* tfr */
            case 0x1f:
                this.inst_tfr();
                //cycles += 6;
                cycles.value+=(6);
                break;
            /* rti */
            case 0x3b:
                if( GETCC(this.FLAG_E) )
                {
                    this.inst_pul(0xff, this.reg_s, this.reg_u, cycles);
                }
                else
                {
                    this.inst_pul(0x81, this.reg_s, this.reg_u, cycles);
                }

                //cycles += 3;
                cycles.value+=(3);
                break;
            /* swi */
            case 0x3f:
                SETCC(this.FLAG_E, 1);
                this.inst_psh(0xff, this.reg_s, this.reg_u.value, cycles);
                SETCC(this.FLAG_I, 1);
                SETCC(this.FLAG_F, 1);
                this.reg_pc = this.read16(0xfffa);
                //cycles += 7;
                cycles.value+=(7);
                break;
            /* sync */
            case 0x13:
                this.irq_status = this.IRQ_SYNC;
                //cycles += 2;
                cycles.value+=(2);
                break;
            /* daa */
            case 0x19:
                i0 = this.reg_a;
                i1 = 0;

                if( (this.reg_a & 0x0f) > 0x09 || GETCC(this.FLAG_H) == 1 )
                {
                    i1 |= 0x06;
                }

                if( (this.reg_a & 0xf0) > 0x80 && (this.reg_a & 0x0f) > 0x09 )
                {
                    i1 |= 0x60;
                }

                if( (this.reg_a & 0xf0) > 0x90 || GETCC(this.FLAG_C) == 1 )
                {
                    i1 |= 0x60;
                }

                this.reg_a = i0 + i1;

                SETCC(this.FLAG_N, TESTN(this.reg_a));
                SETCC(this.FLAG_Z, this.test_z8(this.reg_a));
                SETCC(this.FLAG_V, 0);
                SETCC(this.FLAG_C, this.test_c(i0, i1, this.reg_a, 0));
                //cycles += 2;
                cycles.value+=(2);
                break;
            /* cwai */
            case 0x3c:
                //this.reg_cc &= this.vecx.read8(this.reg_pc++);
                var val = this.vecx.read8(this.reg_pc++);  // Bedlam fix
                SETCC(this.FLAG_E, 1);
                this.inst_psh(0xff, this.reg_s, this.reg_u.value, cycles);
                this.irq_status = this.IRQ_CWAI;
                this.reg_cc &= val; // Bedlam fix
                //cycles += 4;
                cycles.value+=(4);
                break;

            /* page 1 instructions */

            case 0x10:
                op = this.vecx.read8(this.reg_pc++);

                switch( op )
                    {
                /* lbra */
                    case 0x20:
                    /* lbrn */
                    case 0x21:
                        this.inst_bra16(0, op, cycles);
                        break;
                    /* lbhi */
                    case 0x22:
                    /* lbls */
                    case 0x23:
                        this.inst_bra16(GETCC(this.FLAG_C) | GETCC(this.FLAG_Z), op, cycles);
                        break;
                    /* lbhs/lbcc */
                    case 0x24:
                    /* lblo/lbcs */
                    case 0x25:
                        this.inst_bra16(GETCC(this.FLAG_C), op, cycles);
                        break;
                    /* lbne */
                    case 0x26:
                    /* lbeq */
                    case 0x27:
                        this.inst_bra16(GETCC(this.FLAG_Z), op, cycles);
                        break;
                    /* lbvc */
                    case 0x28:
                    /* lbvs */
                    case 0x29:
                        this.inst_bra16(GETCC(this.FLAG_V), op, cycles);
                        break;
                    /* lbpl */
                    case 0x2a:
                    /* lbmi */
                    case 0x2b:
                        this.inst_bra16(GETCC(this.FLAG_N), op, cycles);
                        break;
                    /* lbge */
                    case 0x2c:
                    /* lblt */
                    case 0x2d:
                        this.inst_bra16(GETCC(this.FLAG_N) ^ GETCC(this.FLAG_V), op, cycles);
                        break;
                    /* lbgt */
                    case 0x2e:
                    /* lble */
                    case 0x2f:
                        this.inst_bra16(GETCC(this.FLAG_Z) |
                                        (GETCC(this.FLAG_N) ^ GETCC(this.FLAG_V)), op, cycles);
                        break;
                    /* cmpd */
                    case 0x83:
                        this.inst_sub16(GETREGD(), this.pc_read16());
                        //cycles += 5;
                        cycles.value+=(5);
                        break;
                    case 0x93:
                        ea = EADIRECT();
                        this.inst_sub16(GETREGD(), this.read16(ea));
                        //cycles += 7;
                        cycles.value+=(7);
                        break;
                    case 0xa3:
                        ea = this.ea_indexed(cycles);
                        this.inst_sub16(GETREGD(), this.read16(ea));
                        //cycles += 7;
                        cycles.value+=(7);
                        break;
                    case 0xb3:
                        ea = this.pc_read16();
                        this.inst_sub16(GETREGD(), this.read16(ea));
                        //cycles += 8;
                        cycles.value+=(8);
                        break;
                    /* cmpy */
                    case 0x8c:
                        this.inst_sub16(this.reg_y.value, this.pc_read16());
                        //cycles += 5;
                        cycles.value+=(5);
                        break;
                    case 0x9c:
                        ea = EADIRECT();
                        this.inst_sub16(this.reg_y.value, this.read16(ea));
                        //cycles += 7;
                        cycles.value+=(7);
                        break;
                    case 0xac:
                        ea = this.ea_indexed(cycles);
                        this.inst_sub16(this.reg_y.value, this.read16(ea));
                        //cycles += 7;
                        cycles.value+=(7);
                        break;
                    case 0xbc:
                        ea = this.pc_read16();
                        this.inst_sub16(this.reg_y.value, this.read16(ea));
                        //cycles += 8;
                        cycles.value+=(8);
                        break;
                    /* ldy */
                    case 0x8e:
                        this.reg_y.value=(this.pc_read16());
                        this.inst_tst16(this.reg_y.value);
                        //cycles += 4;
                        cycles.value+=(4);
                        break;
                    case 0x9e:
                        ea = EADIRECT();
                        this.reg_y.value=(this.read16(ea));
                        this.inst_tst16(this.reg_y.value);
                        //cycles += 6;
                        cycles.value+=(6);
                        break;
                    case 0xae:
                        ea = this.ea_indexed(cycles);
                        this.reg_y.value=(this.read16(ea));
                        this.inst_tst16(this.reg_y.value);
                        //cycles += 6;
                        cycles.value+=(6);
                        break;
                    case 0xbe:
                        ea = this.pc_read16();
                        this.reg_y.value=(this.read16(ea));
                        this.inst_tst16(this.reg_y.value);
                        //cycles += 7;
                        cycles.value+=(7);
                        break;
                    /* sty */
                    case 0x9f:
                        ea = EADIRECT();
                        this.write16(ea, this.reg_y.value);
                        this.inst_tst16(this.reg_y.value);
                        //cycles += 6;
                        cycles.value+=(6);
                        break;
                    case 0xaf:
                        ea = this.ea_indexed(cycles);
                        this.write16(ea, this.reg_y.value);
                        this.inst_tst16(this.reg_y.value);
                        //cycles += 6;
                        cycles.value+=(6);
                        break;
                    case 0xbf:
                        ea = this.pc_read16();
                        this.write16(ea, this.reg_y.value);
                        this.inst_tst16(this.reg_y.value);
                        //cycles += 7;
                        cycles.value+=(7);
                        break;
                    /* lds */
                    case 0xce:
                        this.reg_s.value=(this.pc_read16());
                        this.inst_tst16(this.reg_s.value);
                        //cycles += 4;
                        cycles.value+=(4);
                        break;
                    case 0xde:
                        ea = EADIRECT();
                        this.reg_s.value=(this.read16(ea));
                        this.inst_tst16(this.reg_s.value);
                        //cycles += 6;
                        cycles.value+=(6);
                        break;
                    case 0xee:
                        ea = this.ea_indexed(cycles);
                        this.reg_s.value=(this.read16(ea));
                        this.inst_tst16(this.reg_s.value);
                        //cycles += 6;
                        cycles.value+=(6);
                        break;
                    case 0xfe:
                        ea = this.pc_read16();
                        this.reg_s.value=(this.read16(ea));
                        this.inst_tst16(this.reg_s.value);
                        //cycles += 7;
                        cycles.value+=(7);
                        break;
                    /* sts */
                    case 0xdf:
                        ea = EADIRECT();
                        this.write16(ea, this.reg_s.value);
                        this.inst_tst16(this.reg_s.value);
                        //cycles += 6;
                        cycles.value+=(6);
                        break;
                    case 0xef:
                        ea = this.ea_indexed(cycles);
                        this.write16(ea, this.reg_s.value);
                        this.inst_tst16(this.reg_s.value);
                        //cycles += 6;
                        cycles.value+=(6);
                        break;
                    case 0xff:
                        ea = this.pc_read16();
                        this.write16(ea, this.reg_s.value);
                        this.inst_tst16(this.reg_s.value);
                        //cycles += 7;
                        cycles.value+=(7);
                        break;
                    /* swi2 */
                    case 0x3f:
                        SETCC(this.FLAG_E, 1);
                        this.inst_psh(0xff, this.reg_s, this.reg_u.value, cycles);
                        this.reg_pc = this.read16(0xfff4);
                        //cycles += 8;
                        cycles.value+=(8);
                        break;
                    default:
                        //printf ("unknown page-1 op code: %.2x\n", op);
                        utils.showError("unknown page-1 op code: " + op);
                        break;
                }

                break;

            /* page 2 instructions */

            case 0x11:
                op = this.vecx.read8(this.reg_pc++);

                switch( op )
                {
                    /* cmpu */
                    case 0x83:
                        this.inst_sub16(this.reg_u.value, this.pc_read16());
                        //cycles += 5;
                        cycles.value+=(5);
                        break;
                    case 0x93:
                        ea = EADIRECT();
                        this.inst_sub16(this.reg_u.value, this.read16(ea));
                        //cycles += 7;
                        cycles.value+=(7);
                        break;
                    case 0xa3:
                        ea = this.ea_indexed(cycles);
                        this.inst_sub16(this.reg_u.value, this.read16(ea));
                        //cycles += 7;
                        cycles.value+=(7);
                        break;
                    case 0xb3:
                        ea = this.pc_read16();
                        this.inst_sub16(this.reg_u.value, this.read16(ea));
                        //cycles += 8;
                        cycles.value+=(8);
                        break;
                    /* cmps */
                    case 0x8c:
                        this.inst_sub16(this.reg_s.value, this.pc_read16());
                        //cycles += 5;
                        cycles.value+=(5);
                        break;
                    case 0x9c:
                        ea = EADIRECT();
                        this.inst_sub16(this.reg_s.value, this.read16(ea));
                        //cycles += 7;
                        cycles.value+=(7);
                        break;
                    case 0xac:
                        ea = this.ea_indexed(cycles);
                        this.inst_sub16(this.reg_s.value, this.read16(ea));
                        //cycles += 7;
                        cycles.value+=(7);
                        break;
                    case 0xbc:
                        ea = this.pc_read16();
                        this.inst_sub16(this.reg_s.value, this.read16(ea));
                        //cycles += 8;
                        cycles.value+=(8);
                        break;
                    /* swi3 */
                    case 0x3f:
                        SETCC(this.FLAG_E, 1);
                        this.inst_psh(0xff, this.reg_s, this.reg_u.value, cycles);
                        this.reg_pc = this.read16(0xfff2);
                        //cycles += 8;
                        cycles.value+=(8);
                        break;
                    default:
                        //printf ("unknown page-2 op code: %.2x\n", op);
                        utils.showError("unknown page-2 op code: " + op);
                        break;
                }

                break;

            default:
                //printf ("unknown page-0 op code: %.2x\n", op);
                console.log("⚠️ UNKNOWN PAGE-0 OPCODE ERROR:");
                console.log("  PC: 0x" + this.reg_pc.toString(16).toUpperCase().padStart(4, '0'));
                console.log("  Opcode: 0x" + op.toString(16).toUpperCase().padStart(2, '0') + " (" + op + ")");
                console.log("  Registers:");
                console.log("    A: 0x" + this.reg_a.toString(16).toUpperCase().padStart(2, '0'));
                console.log("    B: 0x" + this.reg_b.toString(16).toUpperCase().padStart(2, '0'));
                console.log("    X: 0x" + this.reg_x.value.toString(16).toUpperCase().padStart(4, '0'));
                console.log("    Y: 0x" + this.reg_y.value.toString(16).toUpperCase().padStart(4, '0'));
                console.log("    U: 0x" + this.reg_u.value.toString(16).toUpperCase().padStart(4, '0'));
                console.log("    S: 0x" + this.reg_s.value.toString(16).toUpperCase().padStart(4, '0'));
                console.log("    DP: 0x" + (this.reg_dp & 0xFF).toString(16).toUpperCase().padStart(2, '0'));
                console.log("    CC: 0x" + this.reg_cc.toString(16).toUpperCase().padStart(2, '0'));
                
                // CRITICAL: Set global halt flag to stop emulator immediately
                this.halted = true;
                if (this.vecx) {
                    this.vecx.running = false;
                    this.vecx.halted = true;
                }
                
                // Show error to user
                var errorMsg = "Illegal opcode 0x" + op.toString(16).toUpperCase().padStart(2, '0') + 
                    " at PC=0x" + this.reg_pc.toString(16).toUpperCase().padStart(4, '0') + 
                    " - Emulator stopped";
                console.error(errorMsg);
                
                // Throw exception to break out of emulation loop immediately
                throw new Error(errorMsg);
                break;
        }

        return cycles.value;
    }

    

    this.init = function( vecx )
    {
        this.vecx = vecx;
    }
}

//Globals.e6809 = new e6809();

/* END e6809.js */

/* BEGIN e8910.js */
/***************************************************************************

  ay8910.c

  Emulation of the AY-3-8910 / YM2149 sound chip.

  Based on various code snippets by Ville Hallik, Michael Cuddy,
  Tatsuyuki Satoh, Fabrice Frances, Nicola Salmoria.

***************************************************************************/

// --- Former #define constants converted to const (mantener semántica) ---
const SOUND_FREQ   = 44100; // Fixed: was 22050, causing audio to be too low-pitched
const SOUND_SAMPLE = 512;
const MAX_OUTPUT   = 0x0fff;
const STEP3        = 1;
const STEP2        = length; // (igual que macro original)
const STEP         = 2;

// Register ids (ex-#define)
const AY_AFINE   = 0;
const AY_ACOARSE = 1;
const AY_BFINE   = 2;
const AY_BCOARSE = 3;
const AY_CFINE   = 4;
const AY_CCOARSE = 5;
const AY_NOISEPER= 6;
const AY_ENABLE  = 7;
const AY_AVOL    = 8;
const AY_BVOL    = 9;
const AY_CVOL    = 10;
const AY_EFINE   = 11;
const AY_ECOARSE = 12;
const AY_ESHAPE  = 13;
const AY_PORTA   = 14;
const AY_PORTB   = 15;

function e8910()
{
    // Sustituye el antiguo '#define PSG this.psg'
    this.psg = {
        index: 0,
        ready: 0,
        lastEnable: 0,
        PeriodA: 0,
        PeriodB: 0,
        PeriodC: 0,
        PeriodN: 0,
        PeriodE: 0,
        CountA: 0,
        CountB: 0,
        CountC: 0,
        CountN: 0,
        CountE: 0,
        VolA: 0,
        VolB: 0,
        VolC: 0,
        VolE: 0,
        EnvelopeA: 0,
        EnvelopeB: 0,
        EnvelopeC: 0,
        OutputA: 0,
        OutputB: 0,
        OutputC: 0,
        OutputN: 0,
        CountEnv: 0,
        Hold: 0,
        Alternate: 0,
        Attack: 0,
        Holding: 0,
        RNG: 0,
        VolTable: new Array(32),
        Regs: null
    };

    // Conveniencia local (reemplazo limpio de la macro PSG)
    const PSG = this.psg;

    this.ctx = null;
    this.node = null;
    this.enabled = true;

    this.e8910_build_mixer_table = function()  {
        let i;
        let out;
        out = MAX_OUTPUT;
        for (i = 31; i > 0; i--) {
            PSG.VolTable[i] = (out + 0.5) >>> 0; // round
            out /= 1.188502227; // 1.5 dB step
        }
        PSG.VolTable[0] = 0;
    }

    this.e8910_write = function(r, v) {
        let old;
        PSG.Regs[r] = v;
        switch(r) {
            case AY_AFINE:
            case AY_ACOARSE:
                PSG.Regs[AY_ACOARSE] &= 0x0f;
                old = PSG.PeriodA;
                PSG.PeriodA = (PSG.Regs[AY_AFINE] + 256 * PSG.Regs[AY_ACOARSE]) * STEP3;
                if (PSG.PeriodA === 0) PSG.PeriodA = STEP3;
                PSG.CountA += PSG.PeriodA - old;
                if (PSG.CountA <= 0) PSG.CountA = 1;
                break;
            case AY_BFINE:
            case AY_BCOARSE:
                PSG.Regs[AY_BCOARSE] &= 0x0f;
                old = PSG.PeriodB;
                PSG.PeriodB = (PSG.Regs[AY_BFINE] + 256 * PSG.Regs[AY_BCOARSE]) * STEP3;
                if (PSG.PeriodB === 0) PSG.PeriodB = STEP3;
                PSG.CountB += PSG.PeriodB - old;
                if (PSG.CountB <= 0) PSG.CountB = 1;
                break;
            case AY_CFINE:
            case AY_CCOARSE:
                PSG.Regs[AY_CCOARSE] &= 0x0f;
                old = PSG.PeriodC;
                PSG.PeriodC = (PSG.Regs[AY_CFINE] + 256 * PSG.Regs[AY_CCOARSE]) * STEP3;
                if (PSG.PeriodC === 0) PSG.PeriodC = STEP3;
                PSG.CountC += PSG.PeriodC - old;
                if (PSG.CountC <= 0) PSG.CountC = 1;
                break;
            case AY_NOISEPER:
                PSG.Regs[AY_NOISEPER] &= 0x1f;
                old = PSG.PeriodN;
                PSG.PeriodN = PSG.Regs[AY_NOISEPER] * STEP3;
                if (PSG.PeriodN === 0) PSG.PeriodN = STEP3;
                PSG.CountN += PSG.PeriodN - old;
                if (PSG.CountN <= 0) PSG.CountN = 1;
                break;
            case AY_ENABLE:
                PSG.lastEnable = PSG.Regs[AY_ENABLE];
                break;
            case AY_AVOL:
                PSG.Regs[AY_AVOL] &= 0x1f;
                PSG.EnvelopeA = PSG.Regs[AY_AVOL] & 0x10;
                PSG.VolA = PSG.EnvelopeA
                  ? PSG.VolE
                  : PSG.VolTable[PSG.Regs[AY_AVOL] ? PSG.Regs[AY_AVOL] * 2 + 1 : 0];
                break;
            case AY_BVOL:
                PSG.Regs[AY_BVOL] &= 0x1f;
                PSG.EnvelopeB = PSG.Regs[AY_BVOL] & 0x10;
                PSG.VolB = PSG.EnvelopeB
                  ? PSG.VolE
                  : PSG.VolTable[PSG.Regs[AY_BVOL] ? PSG.Regs[AY_BVOL] * 2 + 1 : 0];
                break;
            case AY_CVOL:
                PSG.Regs[AY_CVOL] &= 0x1f;
                PSG.EnvelopeC = PSG.Regs[AY_CVOL] & 0x10;
                PSG.VolC = PSG.EnvelopeC
                  ? PSG.VolE
                  : PSG.VolTable[PSG.Regs[AY_CVOL] ? PSG.Regs[AY_CVOL] * 2 + 1 : 0];
                break;
            case AY_EFINE:
            case AY_ECOARSE:
                old = PSG.PeriodE;
                PSG.PeriodE = (PSG.Regs[AY_EFINE] + 256 * PSG.Regs[AY_ECOARSE]) * STEP3;
                if (PSG.PeriodE === 0) PSG.PeriodE = STEP3; // (mantiene la variante elegida)
                PSG.CountE += PSG.PeriodE - old;
                if (PSG.CountE <= 0) PSG.CountE = 1;
                break;
            case AY_ESHAPE:
                PSG.Regs[AY_ESHAPE] &= 0x0f;
                PSG.Attack = (PSG.Regs[AY_ESHAPE] & 0x04) ? 0x1f : 0x00;
                if ((PSG.Regs[AY_ESHAPE] & 0x08) === 0) {
                    PSG.Hold = 1;
                    PSG.Alternate = PSG.Attack;
                } else {
                    PSG.Hold = PSG.Regs[AY_ESHAPE] & 0x01;
                    PSG.Alternate = PSG.Regs[AY_ESHAPE] & 0x02;
                }
                PSG.CountE = PSG.PeriodE;
                PSG.CountEnv = 0x1f;
                PSG.Holding = 0;
                PSG.VolE = PSG.VolTable[PSG.CountEnv ^ PSG.Attack];
                if (PSG.EnvelopeA) PSG.VolA = PSG.VolE;
                if (PSG.EnvelopeB) PSG.VolB = PSG.VolE;
                if (PSG.EnvelopeC) PSG.VolC = PSG.VolE;
                break;
            case AY_PORTA:
            case AY_PORTB:
                // Puertos sin lógica extra aquí
                break;
        }
    };

    this.toggleEnabled = function() {
        this.enabled = !this.enabled;
        return this.enabled;
    };

    this.e8910_callback = function(stream, length) {
        let idx = 0;
        let outn = 0;

        if (!PSG.ready || !this.enabled) {
            for (let i = 0; i < length; i++) stream[i] = 0;
            return;
        }

        length = length << 1;

        if (PSG.Regs[AY_ENABLE] & 0x01) {
            if (PSG.CountA <= STEP2) PSG.CountA += STEP2;
            PSG.OutputA = 1;
        } else if (PSG.Regs[AY_AVOL] === 0) {
            if (PSG.CountA <= STEP2) PSG.CountA += STEP2;
        }
        if (PSG.Regs[AY_ENABLE] & 0x02) {
            if (PSG.CountB <= STEP2) PSG.CountB += STEP2;
            PSG.OutputB = 1;
        } else if (PSG.Regs[AY_BVOL] === 0) {
            if (PSG.CountB <= STEP2) PSG.CountB += STEP2;
        }
        if (PSG.Regs[AY_ENABLE] & 0x04) {
            if (PSG.CountC <= STEP2) PSG.CountC += STEP2;
            PSG.OutputC = 1;
        } else if (PSG.Regs[AY_CVOL] === 0) {
            if (PSG.CountC <= STEP2) PSG.CountC += STEP2;
        }

        if ((PSG.Regs[AY_ENABLE] & 0x38) === 0x38)
            if (PSG.CountN <= STEP2) PSG.CountN += STEP2;

        outn = (PSG.OutputN | PSG.Regs[AY_ENABLE]);

        while (length > 0) {
            let vola = 0, volb = 0, volc = 0;
            let left = 2;

            do {
                let nextevent;
                if (PSG.CountN < left) nextevent = PSG.CountN; else nextevent = left;

                // Canal A
                if (outn & 0x08) {
                    if (PSG.OutputA) vola += PSG.CountA;
                    PSG.CountA -= nextevent;
                    while (PSG.CountA <= 0) {
                        PSG.CountA += PSG.PeriodA;
                        if (PSG.CountA > 0) {
                            PSG.OutputA ^= 1;
                            if (PSG.OutputA) vola += PSG.PeriodA;
                            break;
                        }
                        PSG.CountA += PSG.PeriodA;
                        vola += PSG.PeriodA;
                    }
                    if (PSG.OutputA) vola -= PSG.CountA;
                } else {
                    PSG.CountA -= nextevent;
                    while (PSG.CountA <= 0) {
                        PSG.CountA += PSG.PeriodA;
                        if (PSG.CountA > 0) { PSG.OutputA ^= 1; break; }
                        PSG.CountA += PSG.PeriodA;
                    }
                }

                // Canal B
                if (outn & 0x10) {
                    if (PSG.OutputB) volb += PSG.CountB;
                    PSG.CountB -= nextevent;
                    while (PSG.CountB <= 0) {
                        PSG.CountB += PSG.PeriodB;
                        if (PSG.CountB > 0) {
                            PSG.OutputB ^= 1;
                            if (PSG.OutputB) volb += PSG.PeriodB;
                            break;
                        }
                        PSG.CountB += PSG.PeriodB;
                        volb += PSG.PeriodB;
                    }
                    if (PSG.OutputB) volb -= PSG.CountB;
                } else {
                    PSG.CountB -= nextevent;
                    while (PSG.CountB <= 0) {
                        PSG.CountB += PSG.PeriodB;
                        if (PSG.CountB > 0) { PSG.OutputB ^= 1; break; }
                        PSG.CountB += PSG.PeriodB;
                    }
                }

                // Canal C
                if (outn & 0x20) {
                    if (PSG.OutputC) volc += PSG.CountC;
                    PSG.CountC -= nextevent;
                    while (PSG.CountC <= 0) {
                        PSG.CountC += PSG.PeriodC;
                        if (PSG.CountC > 0) {
                            PSG.OutputC ^= 1;
                            if (PSG.OutputC) volc += PSG.PeriodC;
                            break;
                        }
                        PSG.CountC += PSG.PeriodC;
                        volc += PSG.PeriodC;
                    }
                    if (PSG.OutputC) volc -= PSG.CountC;
                } else {
                    PSG.CountC -= nextevent;
                    while (PSG.CountC <= 0) {
                        PSG.CountC += PSG.PeriodC;
                        if (PSG.CountC > 0) { PSG.OutputC ^= 1; break; }
                        PSG.CountC += PSG.PeriodC;
                    }
                }

                PSG.CountN -= nextevent;
                if (PSG.CountN <= 0) {
                    if ((PSG.RNG + 1) & 2) {
                        PSG.OutputN = (~PSG.OutputN & 0xff);
                        outn = (PSG.OutputN | PSG.Regs[AY_ENABLE]);
                    }
                    if (PSG.RNG & 1) {
                        PSG.RNG ^= 0x24000;
                    }
                    PSG.RNG >>= 1;
                    PSG.CountN += PSG.PeriodN;
                }

                left -= nextevent;
            } while (left > 0);

            if (PSG.Holding === 0) {
                PSG.CountE -= STEP;
                if (PSG.CountE <= 0) {
                    do {
                        PSG.CountEnv--;
                        PSG.CountE += PSG.PeriodE;
                    } while (PSG.CountE <= 0);

                    if (PSG.CountEnv < 0) {
                        if (PSG.Hold) {
                            if (PSG.Alternate) PSG.Attack ^= 0x1f;
                            PSG.Holding = 1;
                            PSG.CountEnv = 0;
                        } else {
                            if (PSG.Alternate && (PSG.CountEnv & 0x20))
                                PSG.Attack ^= 0x1f;
                            PSG.CountEnv &= 0x1f;
                        }
                    }

                    PSG.VolE = PSG.VolTable[PSG.CountEnv ^ PSG.Attack];
                    if (PSG.EnvelopeA) PSG.VolA = PSG.VolE;
                    if (PSG.EnvelopeB) PSG.VolB = PSG.VolE;
                    if (PSG.EnvelopeC) PSG.VolC = PSG.VolE;
                }
            }

            const vol = (vola * PSG.VolA + volb * PSG.VolB + volc * PSG.VolC) / (3 * STEP);
            if (--length & 1) {
                const val = vol / MAX_OUTPUT;
                stream[idx++] = val;
            }
        }
    };

    this.init = function(regs) {
        PSG.Regs = regs;
        PSG.RNG  = 1;
        PSG.OutputA = 0;
        PSG.OutputB = 0;
        PSG.OutputC = 0;
        PSG.OutputN = 0xff;
        PSG.ready = 0;
    };

    this.start = function() {
        const self = this;
        if (this.ctx == null && (window.AudioContext || window.webkitAudioContext)) {
            self.e8910_build_mixer_table();
            const ctx = window.AudioContext ?
                new window.AudioContext({ sampleRate: SOUND_FREQ }) :
                new window.webkitAudioContext();
            this.ctx = ctx;
            this.node = this.ctx.createScriptProcessor(SOUND_SAMPLE, 0, 1);
            this.node.onaudioprocess = function(e) {
                self.e8910_callback(e.outputBuffer.getChannelData(0), SOUND_SAMPLE);
            };
            this.node.connect(this.ctx.destination);
            const resumeFunc = function() {
                if (ctx.state !== 'running') ctx.resume();
            };
            document.documentElement.addEventListener('keydown', resumeFunc);
            document.documentElement.addEventListener('click', resumeFunc);
        }
        if (this.ctx) PSG.ready = 1;
    };

    this.stop = function() {
        PSG.ready = 0;
    };
}

/* END e8910.js */

/* BEGIN osint.js */
/*
JSVecX : JavaScript port of the VecX emulator by raz0red.
         Copyright (C) 2010-2019 raz0red

The original C version was written by Valavan Manohararajah
(http://valavan.net/vectrex.html).
*/

/*
  Emulation of the AY-3-8910 / YM2149 sound chip.

  Based on various code snippets by Ville Hallik, Michael Cuddy,
  Tatsuyuki Satoh, Fabrice Frances, Nicola Salmoria.
*/

function osint()
{
    this.vecx = null;

    /* the emulators heart beats at 20 milliseconds */
    this.EMU_TIMER = 20;

    //static long screen_x;
    this.screen_x = 0;
    //static long screen_y;
    this.screen_y = 0;
    //static long scl_factor;
    this.scl_factor = 0;
    //static DWORD color_set[VECTREX_COLORS];
    this.color_set = new Array(Globals.VECTREX_COLORS);

    this.bytes_per_pixel = 4;

    this.osint_updatescale = function()
    {
        //long sclx, scly;
        var sclx = Globals.ALG_MAX_X / this.screen_x >> 0; // raz
        var scly = Globals.ALG_MAX_Y / this.screen_y >> 0; // raz

        if( sclx > scly )
        {
            this.scl_factor = sclx;
        }
        else
        {
            this.scl_factor = scly;
        }
    }

    //static int osint_defaults (void)
    this.osint_defaults = function()
    {
        this.osint_updatescale();

        return 0;
    }

    this.osint_gencolors = function()
    {
        for( var c = 0; c < Globals.VECTREX_COLORS; c++ )
        {
            var rcomp = c * 256 / Globals.VECTREX_COLORS >> 0; // raz
            var gcomp = c * 256 / Globals.VECTREX_COLORS >> 0; // raz
            var bcomp = c * 256 / Globals.VECTREX_COLORS >> 0; // raz

            this.color_set[c] = new Array(3);
            this.color_set[c][0] = rcomp;
            this.color_set[c][1] = gcomp;
            this.color_set[c][2] = bcomp;
        }
    }

    //static einline unsigned char *osint_pixelptr (long x, long y)
    this.osint_pixelindex = function( x, y )
    {
        return ( y * this.lPitch ) + ( x * this.bytes_per_pixel );
    }

    this.osint_clearscreen = function()
    {
        for( var x = 0; x < ( this.screen_y * this.lPitch ); x++ )
        {
            if( ( x + 1 ) % 4 )
            {
                this.imageData.data[x] = 0;
            }
        }

        this.ctx.putImageData(this.imageData, 0, 0);
    }

    /* draw a line with a slope between 0 and 1.
     * x is the "driving" axis. x0 < x1 and y0 < y1.
     */
    //static void osint_linep01 (long x0, long y0, long x1, long y1, unsigned char color)
    this.osint_linep01 = function( x0, y0, x1, y1, color )
    {
        var data = this.data;
        var color_set = this.color_set;
        var lPitch = this.lPitch;
        var bytes_per_pixel = this.bytes_per_pixel;

        var dx = ( x1 - x0 );
        var dy = ( y1 - y0 );
        var i0 = x0 / this.scl_factor >> 0; // raz
        var i1 = x1 / this.scl_factor >> 0; // raz
        var j = y0 / this.scl_factor >> 0; // raz
        var e = dy * (this.scl_factor - (x0 % this.scl_factor)) -
            dx * (this.scl_factor - (y0 % this.scl_factor));
        dx *= this.scl_factor;
        dy *= this.scl_factor;

        var idx = this.osint_pixelindex(i0, j);

        for( ; i0 <= i1; i0++ )
        {
            data[idx] = color_set[color][0];
            data[idx + 1] = color_set[color][1];
            data[idx + 2] = color_set[color][2];

            if( e >= 0 )
            {
                idx += lPitch;
                e -= dx;
            }

            e += dy;
            idx += bytes_per_pixel;
        }
    }

    /* draw a line with a slope between 1 and +infinity.
     * y is the "driving" axis. y0 < y1 and x0 < x1.
     */
    //static void osint_linep1n (long x0, long y0, long x1, long y1, unsigned char color)
    this.osint_linep1n = function( x0, y0, x1, y1, color )
    {
        var data = this.data;
        var color_set = this.color_set;
        var lPitch = this.lPitch;
        var bytes_per_pixel = this.bytes_per_pixel;

        var dx = ( x1 - x0 );
        var dy = ( y1 - y0 );
        var i0 = y0 / this.scl_factor >> 0; // raz
        var i1 = y1 / this.scl_factor >> 0; // raz
        var j = x0 / this.scl_factor >> 0; // raz
        var e = dx * (this.scl_factor - (y0 % this.scl_factor)) -
            dy * (this.scl_factor - (x0 % this.scl_factor));
        dx *= this.scl_factor;
        dy *= this.scl_factor;

        var idx = this.osint_pixelindex(j, i0);

        for( ; i0 <= i1; i0++ )
        {
            data[idx] = color_set[color][0];
            data[idx + 1] = color_set[color][1];
            data[idx + 2] = color_set[color][2];

            if( e >= 0 )
            {
                idx += bytes_per_pixel;
                e -= dy;
            }

            e += dx;
            idx += lPitch;
        }
    }

    /* draw a line with a slope between 0 and -1.
     * x is the "driving" axis. x0 < x1 and y1 < y0.
     */

    //static void osint_linen01 (long x0, long y0, long x1, long y1, unsigned char color)
    this.osint_linen01 = function( x0, y0, x1, y1, color )
    {
        var data = this.data;
        var color_set = this.color_set;
        var lPitch = this.lPitch;
        var bytes_per_pixel = this.bytes_per_pixel;

        var dx = ( x1 - x0 );
        var dy = ( y0 - y1 );
        var i0 = x0 / this.scl_factor >> 0; // raz
        var i1 = x1 / this.scl_factor >> 0; // raz
        var j = y0 / this.scl_factor >> 0; // raz
        var e = dy * (this.scl_factor - (x0 % this.scl_factor)) -
            dx * (y0 % this.scl_factor);
        dx *= this.scl_factor;
        dy *= this.scl_factor;

        var idx = this.osint_pixelindex(i0, j);

        for( ; i0 <= i1; i0++ )
        {
            data[idx] = color_set[color][0];
            data[idx + 1] = color_set[color][1];
            data[idx + 2] = color_set[color][2];

            if( e >= 0 )
            {
                idx -= lPitch;
                e -= dx;
            }

            e += dy;
            idx += bytes_per_pixel;
        }
    }

    /* draw a line with a slope between -1 and -infinity.
     * y is the "driving" axis. y0 < y1 and x1 < x0.
     */

    //static void osint_linen1n (long x0, long y0, long x1, long y1, unsigned char color)
    this.osint_linen1n = function( x0, y0, x1, y1, color )
    {
        var data = this.data;
        var color_set = this.color_set;
        var lPitch = this.lPitch;
        var bytes_per_pixel = this.bytes_per_pixel;

        var dx = ( x0 - x1 );
        var dy = ( y1 - y0 );
        var i0 = y0 / this.scl_factor >> 0; // raz
        var i1 = y1 / this.scl_factor >> 0; // raz
        var j = x0 / this.scl_factor >> 0; // raz
        var e = dx * (this.scl_factor - (y0 % this.scl_factor)) -
            dy * (x0 % this.scl_factor);
        dx *= this.scl_factor;
        dy *= this.scl_factor;

        var idx = this.osint_pixelindex(j, i0);

        for( ; i0 <= i1; i0++ )
        {
            data[idx] = color_set[color][0];
            data[idx + 1] = color_set[color][1];
            data[idx + 2] = color_set[color][2];

            if( e >= 0 )
            {
                idx -= bytes_per_pixel;
                e -= dy;
            }

            e += dx;
            idx += lPitch;
        }
    }

    //static void osint_line (long x0, long y0, long x1, long y1, unsigned char color)
    this.osint_line = function( x0, y0, x1, y1, color )
    {
        if( x1 > x0 )
        {
            if( y1 > y0 )
            {
                if( (x1 - x0) > (y1 - y0) )
                {
                    this.osint_linep01(x0, y0, x1, y1, color);
                }
                else
                {
                    this.osint_linep1n(x0, y0, x1, y1, color);
                }
            }
            else
            {
                if( (x1 - x0) > (y0 - y1) )
                {
                    this.osint_linen01(x0, y0, x1, y1, color);
                }
                else
                {
                    this.osint_linen1n(x1, y1, x0, y0, color);
                }
            }
        }
        else
        {
            if( y1 > y0 )
            {
                if( (x0 - x1) > (y1 - y0) )
                {
                    this.osint_linen01(x1, y1, x0, y0, color);
                }
                else
                {
                    this.osint_linen1n(x0, y0, x1, y1, color);
                }
            }
            else
            {
                if( (x0 - x1) > (y0 - y1) )
                {
                    this.osint_linep01(x1, y1, x0, y0, color);
                }
                else
                {
                    this.osint_linep1n(x1, y1, x0, y0, color);
                }
            }
        }
    }

    this.osint_render = function()
    {
        var vector_erse_cnt = this.vecx.vector_erse_cnt;
        var vectors_erse = this.vecx.vectors_erse;
        var vector_draw_cnt = this.vecx.vector_draw_cnt;
        var vectors_draw = this.vecx.vectors_draw;
        var v = 0;
        var erse = null;
        var draw = null;
        var vectrexColors = Globals.VECTREX_COLORS;

        for( v = 0; v < vector_erse_cnt; v++ )
        {
            erse = vectors_erse[v];
            if( erse.color != vectrexColors )
            {
                this.osint_line(erse.x0, erse.y0, erse.x1, erse.y1, 0);
            }
        }

        for( v = 0; v < vector_draw_cnt; v++ )
        {
            draw = vectors_draw[v];
            console.log(`[Vector ${v}] Drawing line: (${draw.x0}, ${draw.y0}) -> (${draw.x1}, ${draw.y1}), color: ${draw.color}`);
            this.osint_line(draw.x0, draw.y0, draw.x1, draw.y1, draw.color);
        }

        this.ctx.putImageData(this.imageData, 0, 0);
    }

    this.init = function( vecx )
    {
        this.vecx = vecx;

        // Set up the dimensions
        this.screen_x = Globals.SCREEN_X_DEFAULT;
        this.screen_y = Globals.SCREEN_Y_DEFAULT;
        this.lPitch = this.bytes_per_pixel * this.screen_x;

        this.osint_defaults();

        // Graphics
        this.canvas = document.getElementById('screen');
        this.ctx = this.canvas.getContext('2d');
        this.imageData = this.ctx.getImageData(0, 0, this.screen_x, this.screen_y);
        this.data = this.imageData.data;

        /* set alpha to opaque */
        for( var i = 3; i < this.imageData.data.length - 3; i += 4 )
        {
            this.imageData.data[i] = 0xFF;
        }

        /* determine a set of colors to use based */
        this.osint_gencolors();
        this.osint_clearscreen();
    }
}

//Globals.osint = new osint();

/* END osint.js */

/* BEGIN vecx.js */
/*
JSVecX : JavaScript port of the VecX emulator by raz0red.
         Copyright (C) 2010-2019 raz0red

The original C version was written by Valavan Manohararajah
(http://valavan.net/vectrex.html).
*/

/*
  Emulation of the AY-3-8910 / YM2149 sound chip.

  Based on various code snippets by Ville Hallik, Michael Cuddy,
  Tatsuyuki Satoh, Fabrice Frances, Nicola Salmoria.
*/

function VecX()
{
    // Create the system components

    this.osint = new osint();
    this.e6809 = new e6809();
    this.e8910 = new e8910();    

    /* Memory */

    //unsigned char rom[8192];
    this.rom = new Array(0x2000);
    utils.initArray(this.rom, 0);
    //unsigned char cart[32768]; // EXPANDED: Support up to 4MB multi-bank ROMs
    this.cart = new Array(0x400000); // 4MB max (256 banks × 16KB)
    utils.initArray(this.cart, 0);
    this.current_bank = 0; // Current bank mapped to 0x0000-0x3FFF (default: Bank 0)
    //static unsigned char ram[1024];
    this.ram = new Array(0x400);
    utils.initArray(this.ram, 0);

    /* the sound chip registers */

    //unsigned snd_regs[16];
    this.snd_regs = new Array(16);
    this.e8910.init(this.snd_regs);
    
    //static unsigned snd_select;
    this.snd_select = 0;

    /* the via 6522 registers */

    //static unsigned via_ora;
    this.via_ora = 0;
    //static unsigned via_orb;
    this.via_orb = 0;
    //static unsigned via_ddra;
    this.via_ddra = 0;
    //static unsigned via_ddrb;
    this.via_ddrb = 0;
    //static unsigned via_t1on;  /* is timer 1 on? */
    this.via_t1on = 0;
    //static unsigned via_t1int; /* are timer 1 interrupts allowed? */
    this.via_t1int = 0;
    //static unsigned via_t1c;
    this.via_t1c = 0;
    //static unsigned via_t1ll;
    this.via_t1ll = 0;
    //static unsigned via_t1lh;
    this.via_t1lh = 0;
    //static unsigned via_t1pb7; /* timer 1 controlled version of pb7 */
    this.via_t1pb7 = 0;
    //static unsigned via_t2on;  /* is timer 2 on? */
    this.via_t2on = 0;
    //static unsigned via_t2int; /* are timer 2 interrupts allowed? */
    this.via_t2int = 0;
    //static unsigned via_t2c;
    this.via_t2c = 0;
    //static unsigned via_t2ll;
    this.via_t2ll = 0;
    //static unsigned via_sr;
    this.via_sr = 0;
    //static unsigned via_srb;   /* number of bits shifted so far */
    this.via_srb = 0;
    //static unsigned via_src;   /* shift counter */
    this.via_src = 0;
    //static unsigned via_srclk;
    this.via_srclk = 0;
    //static unsigned via_acr;
    this.via_acr = 0;
    //static unsigned via_pcr;
    this.via_pcr = 0;
    //static unsigned via_ifr;
    this.via_ifr = 0;
    //static unsigned via_ier;
    this.via_ier = 0;
    //static unsigned via_ca2;
    this.via_ca2 = 0;
    //static unsigned via_cb2h;  /* basic handshake version of cb2 */
    this.via_cb2h = 0;
    //static unsigned via_cb2s;  /* version of cb2 controlled by the shift register */
    this.via_cb2s = 0;

    /* analog devices */

    //static unsigned alg_rsh;  /* zero ref sample and hold */
    this.alg_rsh = 0;
    //static unsigned alg_xsh;  /* x sample and hold */
    this.alg_xsh = 0;
    //static unsigned alg_ysh;  /* y sample and hold */
    this.alg_ysh = 0;
    //static unsigned alg_zsh;  /* z sample and hold */
    this.alg_zsh = 0;
    //unsigned alg_jch0;		  /* joystick direction channel 0 */
    this.alg_jch0 = 0;
    //unsigned alg_jch1;		  /* joystick direction channel 1 */
    this.alg_jch1 = 0;
    //unsigned alg_jch2;		  /* joystick direction channel 2 */
    this.alg_jch2 = 0;
    //unsigned alg_jch3;		  /* joystick direction channel 3 */
    this.alg_jch3 = 0;
    //static unsigned alg_jsh;  /* joystick sample and hold */
    this.alg_jsh = 0;

    //static unsigned alg_compare;
    this.alg_compare = 0;

    //static long alg_dx;     /* delta x */
    this.alg_dx = 0;
    //static long alg_dy;     /* delta y */
    this.alg_dy = 0;
    //static long alg_curr_x; /* current x position */
    this.alg_curr_x = 0;
    //static long alg_curr_y; /* current y position */
    this.alg_curr_y = 0;

    this.alg_max_x = Globals.ALG_MAX_X >> 1;
    this.alg_max_y = Globals.ALG_MAX_Y >> 1;

    //static unsigned alg_vectoring; /* are we drawing a vector right now? */
    this.alg_vectoring = 0;
    //static long alg_vector_x0;
    this.alg_vector_x0 = 0;
    //static long alg_vector_y0;
    this.alg_vector_y0 = 0;
    //static long alg_vector_x1;
    this.alg_vector_x1 = 0;
    //static long alg_vector_y1;
    this.alg_vector_y1 = 0;
    //static long alg_vector_dx;
    this.alg_vector_dx = 0;
    //static long alg_vector_dy;
    this.alg_vector_dy = 0;
    //static unsigned char alg_vector_color;
    this.alg_vector_color = 0;

    //long vector_draw_cnt;
    this.vector_draw_cnt = 0;
    //long vector_erse_cnt;
    this.vector_erse_cnt = 0;

    //static vector_t vectors_set[2 * VECTOR_CNT];
    //this.vectors_set = new Array(2 * Globals.VECTOR_CNT);

    //vector_t *vectors_draw;
    this.vectors_draw = new Array(Globals.VECTOR_CNT);

    //vector_t *vectors_erse;
    this.vectors_erse = new Array(Globals.VECTOR_CNT);

    //static long vector_hash[VECTOR_HASH];
    this.vector_hash = new Array(Globals.VECTOR_HASH);
    utils.initArray(this.vector_hash, 0);

    //static long fcycles;
    this.fcycles = 0;

    /* update the snd chips internal registers when via_ora/via_orb changes */

    //static einline void snd_update (void)
    this.snd_update = function()
    {
        switch( this.via_orb & 0x18 )
        {
            case 0x00:
                /* the sound chip is disabled */
                break;
            case 0x08:
                /* the sound chip is sending data */
                break;
            case 0x10:
                /* the sound chip is recieving data */

                if( this.snd_select != 14 )
                {
                    this.snd_regs[this.snd_select] = this.via_ora;
                    this.e8910.e8910_write(this.snd_select, this.via_ora);
                    
                    // PSG logging
                    if (window.PSG_LOG_ENABLED) {
                        // Initialize arrays if needed
                        if (!window.PSG_MUSIC_LOG) window.PSG_MUSIC_LOG = [];
                        if (!window.PSG_VECTOR_LOG) window.PSG_VECTOR_LOG = [];
                        if (!window.PSG_WRITE_LOG) window.PSG_WRITE_LOG = [];
                        
                        const limit = window.PSG_LOG_LIMIT || 10000;
                        
                        // Check if PSG_MUSIC_ACTIVE is set (address 0xC8A1)
                        const ramOffset = 0xC8A1 - 0xC800; // Should be 0xA1 (161)
                        const isMusical = this.ram && this.ram[ramOffset] === 1;
                        const targetLog = isMusical ? window.PSG_MUSIC_LOG : window.PSG_VECTOR_LOG;
                        
                        // Debug first write only
                        if (!window._PSG_DEBUG_LOGGED && window.PSG_WRITE_LOG.length === 0) {
                            console.log('[PSG] First write - ram exists:', !!this.ram, 'offset:', ramOffset, 'value:', this.ram ? this.ram[ramOffset] : 'N/A', 'isMusical:', isMusical);
                            window._PSG_DEBUG_LOGGED = true;
                        }
                        
                        if (targetLog.length < limit) {
                            targetLog.push({
                                reg: this.snd_select,
                                value: this.via_ora,
                                frame: window.frame_counter || 0,
                                pc: this.e6809.pc || 0
                            });
                        }
                        
                        // Keep legacy PSG_WRITE_LOG for backward compatibility
                        if (window.PSG_WRITE_LOG.length < limit) {
                            window.PSG_WRITE_LOG.push({
                                reg: this.snd_select,
                                value: this.via_ora,
                                frame: window.frame_counter || 0,
                                pc: this.e6809.pc || 0
                            });
                        }
                    }
                }
                break;
            case 0x18:
                /* the sound chip is latching an address */
                if( (this.via_ora & 0xf0) == 0x00 )
                {
                    this.snd_select = this.via_ora & 0x0f;
                }
                break;
        }
    }

    /* update the various analog values when orb is written. */

    //static einline void alg_update (void)
    this.alg_update = function()
    {
        switch( this.via_orb & 0x06 )
        {
            case 0x00:
                this.alg_jsh = this.alg_jch0;

                if( (this.via_orb & 0x01) == 0x00 )
                {
                    /* demultiplexor is on */
                    this.alg_ysh = this.alg_xsh;
                }

                break;
            case 0x02:
                this.alg_jsh = this.alg_jch1;

                if( (this.via_orb & 0x01) == 0x00 )
                {
                    /* demultiplexor is on */
                    this.alg_rsh = this.alg_xsh;
                }

                break;
            case 0x04:
                this.alg_jsh = this.alg_jch2;

                if( (this.via_orb & 0x01) == 0x00 )
                {
                    /* demultiplexor is on */

                    if( this.alg_xsh > 0x80 )
                    {
                        this.alg_zsh = this.alg_xsh - 0x80;
                    }
                    else
                    {
                        this.alg_zsh = 0;
                    }
                }

                break;
            case 0x06:
                /* sound output line */
                this.alg_jsh = this.alg_jch3;
                break;
        }

        /* compare the current joystick direction with a reference */

        if( this.alg_jsh > this.alg_xsh )
        {
            this.alg_compare = 0x20;
        }
        else
        {
            this.alg_compare = 0;
        }

        /* compute the new "deltas" */
        this.alg_dx = this.alg_xsh - this.alg_rsh;
        this.alg_dy = this.alg_rsh - this.alg_ysh;
    }

    /*
    * update IRQ and bit-7 of the ifr register after making an adjustment to
    * ifr.
    */

//    //static einline void int_update (void)
//    this.int_update = function()
//    {
//        if( (this.via_ifr & 0x7f) & (this.via_ier & 0x7f) )
//        {
//            this.via_ifr |= 0x80;
//        }
//        else
//        {
//            this.via_ifr &= 0x7f;
//        }
//    }

    //unsigned char read8 (unsigned address)
    this.read8 = function( address )
    {
        address &= 0xffff;

        if( (address & 0xe000) == 0xe000 )
        {
            /* rom */
            return this.rom[address & 0x1fff] & 0xff;
            //if( utils.logCount-- > 0 ) console.log( "read8, rom: %d, %d\n", ( address & 0x1fff ), data );
        }

        if( (address & 0xe000) == 0xc000 )
        {
            if( address & 0x800 )
            {
                /* ram */

                return this.ram[address & 0x3ff] & 0xff;
            }

            var data = 0;

            /* io */
            switch( address & 0xf )
            {
                case 0x0:
                /* compare signal is an input so the value does not come from
                 * via_orb.
                 */

                    if( this.via_acr & 0x80 )
                    {
                        /* timer 1 has control of bit 7 */

                        data = ((this.via_orb & 0x5f) | this.via_t1pb7 | this.alg_compare);
                    }
                    else
                    {
                        /* bit 7 is being driven by via_orb */

                        data = ((this.via_orb & 0xdf) | this.alg_compare);
                    }
                    return data & 0xff;
                case 0x1:
                /* register 1 also performs handshakes if necessary */

                    if( (this.via_pcr & 0x0e) == 0x08 )
                    {
                        /* if ca2 is in pulse mode or handshake mode, then it
                        * goes low whenever ira is read.
                        */

                        this.via_ca2 = 0;
                    }

                    /* fall through */
                case 0xf:
                    // DEBUG: Log VIA Port A read
                    if (this.snd_select === 14 && typeof window !== 'undefined' && window.injectedButtonStatePSG !== undefined) {
                        console.log('[JSVecx VIA Read case 0xf] via_orb:', (this.via_orb & 0x18).toString(16), 'snd_select:', this.snd_select);
                    }
                    
                    if( (this.via_orb & 0x18) == 0x08 )
                    {
                        /* the snd chip is driving port a */
                        
                        // PATCH (2026-01-03): For register 14 (buttons), check if frontend injected value
                        if (this.snd_select === 14) {
                            if (typeof window !== 'undefined' && window.injectedButtonStatePSG !== undefined) {
                                data = window.injectedButtonStatePSG;
                                console.log('[JSVecx VIA Read] ✓ Using injected PSG reg 14:', data.toString(16).padStart(2, '0'));
                            } else {
                                data = this.snd_regs[this.snd_select];
                                console.log('[JSVecx VIA Read] ✗ No injected value, using snd_regs[14]:', data.toString(16).padStart(2, '0'));
                            }
                        } else {
                            data = this.snd_regs[this.snd_select];
                        }
                    }
                    else
                    {
                        data = this.via_ora;
                    }
                    return data & 0xff;
                case 0x2:
                    return this.via_ddrb & 0xff;
                case 0x3:
                    return this.via_ddra & 0xff;
                case 0x4:
                /* T1 low order counter */

                    data = this.via_t1c;
                    this.via_ifr &= 0xbf; /* remove timer 1 interrupt flag */

                    this.via_t1on = 0; /* timer 1 is stopped */
                    this.via_t1int = 0;
                    this.via_t1pb7 = 0x80;

                    //this.int_update();
                    // int_update inline begin
                    if( (this.via_ifr & 0x7f) & (this.via_ier & 0x7f) )
                    {
                        this.via_ifr |= 0x80;
                    }
                    else
                    {
                        this.via_ifr &= 0x7f;
                    }
                    // int_update inline end

                    return data & 0xff;
                case 0x5:
                /* T1 high order counter */
                    return (this.via_t1c >> 8) & 0xff;
                case 0x6:
                /* T1 low order latch */
                    return this.via_t1ll & 0xff;
                case 0x7:
                /* T1 high order latch */
                    return this.via_t1lh & 0xff;
                case 0x8:
                /* T2 low order counter */
                    data = this.via_t2c;
                    this.via_ifr &= 0xdf; /* remove timer 2 interrupt flag */
                    this.via_t2on = 0; /* timer 2 is stopped */
                    this.via_t2int = 0;

                    //this.int_update();
                    // int_update inline begin
                    if( (this.via_ifr & 0x7f) & (this.via_ier & 0x7f) )
                    {
                        this.via_ifr |= 0x80;
                    }
                    else
                    {
                        this.via_ifr &= 0x7f;
                    }
                    // int_update inline end

                    return data & 0xff;
                case 0x9:
                /* T2 high order counter */
                    return (this.via_t2c >> 8);
                case 0xa:
                    data = this.via_sr;
                    this.via_ifr &= 0xfb; /* remove shift register interrupt flag */
                    this.via_srb = 0;
                    this.via_srclk = 1;

                    //this.int_update();
                    // int_update inline begin
                    if( (this.via_ifr & 0x7f) & (this.via_ier & 0x7f) )
                    {
                        this.via_ifr |= 0x80;
                    }
                    else
                    {
                        this.via_ifr &= 0x7f;
                    }
                    // int_update inline end

                    return data & 0xff;
                case 0xb:
                    return this.via_acr & 0xff;
                case 0xc:
                    return this.via_pcr & 0xff;
                case 0xd:
                /* interrupt flag register */
                    return this.via_ifr & 0xff;
                case 0xe:
                /* interrupt enable register */
                    return (this.via_ier | 0x80) & 0xff;
            }
        }

        if( address < 0x8000 )
        {
            // Multi-bank ROM support:
            // 0x0000-0x3FFF: Banked window (switchable via current_bank)
            // 0x4000-0x7FFF: Fixed bank #31 (always mapped)
            var physical_address;
            if (address < 0x4000) {
                // Banked window: map to current_bank * 16KB
                physical_address = (this.current_bank * 0x4000) + address;
            } else {
                // Fixed bank: last 16KB of the loaded ROM, always mapped to $4000-$7FFF
                // For single-bank 32KB: last bank at offset 0x4000
                // For 4-bank 64KB: last bank (bank 3) at offset 0x0C000
                var rom_size = this.loaded_rom_size || 0x8000;
                var fixed_bank_offset = (Math.floor(rom_size / 0x4000) - 1) * 0x4000;
                physical_address = fixed_bank_offset + (address - 0x4000);
            }
            
            // Bounds check (support up to 4MB)
            if (physical_address < this.cart.length) {
                return this.cart[physical_address] & 0xff;
            }
            return 0xff; // Out of bounds
        }

        return 0xff;
    }

    //void write8 (unsigned address, unsigned char data)
    this.write8 = function( address, data )
    {        
        address &= 0xffff;
        data &= 0xff;

        if( (address & 0xe000) == 0xe000 )
        {
            /* rom */
        }
        else if( (address & 0xe000) == 0xc000 )
        {
            /* it is possible for both ram and io to be written at the same! */

            if( address & 0x800 )
            {
                this.ram[address & 0x3ff] = data;
            }

            if( address & 0x1000 )
            {
                switch( address & 0xf )
                {
                    case 0x0:
                        this.via_orb = data;
                        this.snd_update();
                        this.alg_update();

                        if( (this.via_pcr & 0xe0) == 0x80 )
                        {
                            /* if cb2 is in pulse mode or handshake mode, then it
                            * goes low whenever orb is written.
                            */

                            this.via_cb2h = 0;
                        }

                        break;
                    case 0x1:
                    /* register 1 also performs handshakes if necessary */

                        if( (this.via_pcr & 0x0e) == 0x08 )
                        {
                            /* if ca2 is in pulse mode or handshake mode, then it
                            * goes low whenever ora is written.
                            */

                            this.via_ca2 = 0;
                        }

                        /* fall through */

                    case 0xf:
                        this.via_ora = data;

                        this.snd_update();

                    /* output of port a feeds directly into the dac which then
                     * feeds the x axis sample and hold.
                     */

                        this.alg_xsh = data ^ 0x80;
                        this.alg_update();

                        break;
                    case 0x2:
                        this.via_ddrb = data;
                        break;
                    case 0x3:
                        this.via_ddra = data;
                        break;
                    case 0x4:
                    /* T1 low order counter */

                        this.via_t1ll = data;

                        break;
                    case 0x5:
                    /* T1 high order counter */

                        this.via_t1lh = data;
                        this.via_t1c = (this.via_t1lh << 8) | this.via_t1ll;
                        this.via_ifr &= 0xbf; /* remove timer 1 interrupt flag */

                        this.via_t1on = 1; /* timer 1 starts running */
                        this.via_t1int = 1;
                        this.via_t1pb7 = 0;

                        //this.int_update();
                        // int_update inline begin
                        if( (this.via_ifr & 0x7f) & (this.via_ier & 0x7f) )
                        {
                            this.via_ifr |= 0x80;
                        }
                        else
                        {
                            this.via_ifr &= 0x7f;
                        }
                        // int_update inline end

                        break;
                    case 0x6:
                    /* T1 low order latch */

                        this.via_t1ll = data;
                        break;
                    case 0x7:
                    /* T1 high order latch */

                        this.via_t1lh = data;
                        break;
                    case 0x8:
                    /* T2 low order latch */

                        this.via_t2ll = data;
                        break;
                    case 0x9:
                    /* T2 high order latch/counter */

                        this.via_t2c = (data << 8) | this.via_t2ll;
                        this.via_ifr &= 0xdf;

                        this.via_t2on = 1; /* timer 2 starts running */
                        this.via_t2int = 1;

                        //this.int_update();
                        // int_update inline begin
                        if( (this.via_ifr & 0x7f) & (this.via_ier & 0x7f) )
                        {
                            this.via_ifr |= 0x80;
                        }
                        else
                        {
                            this.via_ifr &= 0x7f;
                        }
                        // int_update inline end

                        break;
                    case 0xa:
                        this.via_sr = data;
                        this.via_ifr &= 0xfb; /* remove shift register interrupt flag */
                        this.via_srb = 0;
                        this.via_srclk = 1;

                        //this.int_update();
                        // int_update inline begin
                        if( (this.via_ifr & 0x7f) & (this.via_ier & 0x7f) )
                        {
                            this.via_ifr |= 0x80;
                        }
                        else
                        {
                            this.via_ifr &= 0x7f;
                        }
                        // int_update inline end

                        break;
                    case 0xb:
                        this.via_acr = data;
                        break;
                    case 0xc:
                        this.via_pcr = data;


                        if( (this.via_pcr & 0x0e) == 0x0c )
                        {
                            /* ca2 is outputting low */

                            this.via_ca2 = 0;
                        }
                        else
                        {
                            /* ca2 is disabled or in pulse mode or is
                            * outputting high.
                            */

                            this.via_ca2 = 1;
                        }

                        if( (this.via_pcr & 0xe0) == 0xc0 )
                        {
                            /* cb2 is outputting low */

                            this.via_cb2h = 0;
                        }
                        else
                        {
                            /* cb2 is disabled or is in pulse mode or is
                            * outputting high.
                            */

                            this.via_cb2h = 1;
                        }

                        break;
                    case 0xd:
                    /* interrupt flag register */

                        this.via_ifr &= (~(data & 0x7f)); // & 0xffff ); // raz

                        //this.int_update();
                        // int_update inline begin
                        if( (this.via_ifr & 0x7f) & (this.via_ier & 0x7f) )
                        {
                            this.via_ifr |= 0x80;
                        }
                        else
                        {
                            this.via_ifr &= 0x7f;
                        }
                        // int_update inline end

                        break;
                    case 0xe:
                    /* interrupt enable register */

                        if( data & 0x80 )
                        {
                            this.via_ier |= data & 0x7f;
                        }
                        else
                        {
                            this.via_ier &= (~(data & 0x7f)); // & 0xffff ); // raz
                        }

                        //this.int_update();
                        // int_update inline begin
                        if( (this.via_ifr & 0x7f) & (this.via_ier & 0x7f) )
                        {
                            this.via_ifr |= 0x80;
                        }
                        else
                        {
                            this.via_ifr &= 0x7f;
                        }
                        // int_update inline end

                        break;
                }
            }
        }
        else if( address < 0x8000 )
        {
            /* cartridge ROM area - read only, ignore writes */
        }
        
        // Bank switching register at $DF00 (in unmapped I/O space)
        // Write to $DF00 switches the current bank (0x0000-0x3FFF window)
        if (address == 0xDF00) {
            this.current_bank = data & 0xff; // Bank number (0-255)
            // console.log('[JSVecx] Bank switch to:', this.current_bank);
        }
    }

    //void vecx_reset (void)
    this.vecx_reset = function()
    {
        /* ram */
        for( var r = 0; r < this.ram.length; r++ )
        {
            this.ram[r] = r & 0xff;
        }

        /* reset bank switching to Bank 0 */
        this.current_bank = 0;

        for( var r = 0; r < 16; r++ )
        {
            this.snd_regs[r] = 0;
            this.e8910.e8910_write(r, 0);
        }

        /* input buttons */

        this.snd_regs[14] = 0xff;
        this.e8910.e8910_write(14, 0xff);

        this.snd_select = 0;

        this.via_ora = 0;
        this.via_orb = 0;
        this.via_ddra = 0;
        this.via_ddrb = 0;
        this.via_t1on = 0;
        this.via_t1int = 0;
        this.via_t1c = 0;
        this.via_t1ll = 0;
        this.via_t1lh = 0;
        this.via_t1pb7 = 0x80;
        this.via_t2on = 0;
        this.via_t2int = 0;
        this.via_t2c = 0;
        this.via_t2ll = 0;
        this.via_sr = 0;
        this.via_srb = 8;
        this.via_src = 0;
        this.via_srclk = 0;
        this.via_acr = 0;
        this.via_pcr = 0;
        this.via_ifr = 0;
        this.via_ier = 0;
        this.via_ca2 = 1;
        this.via_cb2h = 1;
        this.via_cb2s = 0;

        this.alg_rsh = 128;
        this.alg_xsh = 128;
        this.alg_ysh = 128;
        this.alg_zsh = 0;
        this.alg_jch0 = 128;
        this.alg_jch1 = 128;
        this.alg_jch2 = 128;
        this.alg_jch3 = 128;
        this.alg_jsh = 128;

        this.alg_compare = 0;
        /* check this */

        this.alg_dx = 0;
        this.alg_dy = 0;
        this.alg_curr_x = Globals.ALG_MAX_X >> 1;
        this.alg_curr_y = Globals.ALG_MAX_Y >> 1;

        this.alg_vectoring = 0;

        this.vector_draw_cnt = 0;
        this.vector_erse_cnt = 0;

        for( var i = 0; i < this.vectors_draw.length; i++ )
        {
            if( !this.vectors_draw[i] )
            {
                this.vectors_draw[i] = new vector_t();
            }
            else
            {
                this.vectors_draw[i].reset();
            }
        }
        
        for( var i = 0; i < this.vectors_erse.length; i++ )
        {
            if( !this.vectors_erse[i] )
            {
                this.vectors_erse[i] = new vector_t();
            }
            else
            {
                this.vectors_erse[i].reset();
            }
        }

        /* load the rom into memory */
        var len = Globals.romdata.length;
        for( var i = 0; i < len; i++ )
        {
            this.rom[i] = Globals.romdata.charCodeAt(i);
        }

        /* the cart is empty by default */
        len = this.cart.length;
        for( var b = 0; b < len; b++ )
        {
            this.cart[b] = 0x01; // parabellum
        }

        if( Globals.cartdata != null && Globals.cartdata.length > 0 )
        {
            /* load the rom into memory */
            len = Globals.cartdata.length;
            console.log('[JSVecx] Loading cartridge: ' + len + ' bytes into cart[]');
            for( var i = 0; i < len; i++ )
            {
                this.cart[i] = Globals.cartdata.charCodeAt(i);
            }
            // Verify first few bytes loaded correctly
            console.log('[JSVecx] Cart verification - first 16 bytes: ' + 
                this.cart.slice(0, 16).map(function(b) { return b.toString(16).padStart(2, '0'); }).join(' '));
        }
        else
        {
            console.warn('[JSVecx] WARNING: No cartdata loaded! Cart will be filled with 0x01 (illegal opcode)');
        }

        this.fcycles = Globals.FCYCLES_INIT;

        this.e6809.e6809_reset();
    }

    this.t2shift = 0;

//    /* perform a single cycle worth of via emulation.
//     * via_sstep0 is the first postion of the emulation.
//     */
//    //static einline void via_sstep0 (void)
//    this.via_sstep0 = function()
//    {
//        //unsigned t2shift;
//        this.t2shift = 0;
//
//        if( this.via_t1on )
//        {
//            this.via_t1c = ( this.via_t1c > 0 ? this.via_t1c - 1 : 0xffff );
//            // On PC is 0xffffffff
//            if( (this.via_t1c & 0xffff) == 0xffff )
//            {
//                /* counter just rolled over */
//
//                if( this.via_acr & 0x40 )
//                {
//                    /* continuous interrupt mode */
//
//                    this.via_ifr |= 0x40;
//                    this.int_update();
//                    this.via_t1pb7 = 0x80 - this.via_t1pb7;
//
//                    /* reload counter */
//
//                    this.via_t1c = (this.via_t1lh << 8) | this.via_t1ll;
//                }
//                else
//                {
//                    /* one shot mode */
//
//                    if( this.via_t1int )
//                    {
//                        this.via_ifr |= 0x40;
//                        this.int_update();
//                        this.via_t1pb7 = 0x80;
//                        this.via_t1int = 0;
//                    }
//                }
//            }
//        }
//
//        if( this.via_t2on && (this.via_acr & 0x20) == 0x00 )
//        {
//            this.via_t2c = ( this.via_t2c > 0 ? this.via_t2c - 1 : 0xffff );
//
//            if( (this.via_t2c & 0xffff) == 0xffff )
//            {
//                /* one shot mode */
//
//                if( this.via_t2int )
//                {
//                    this.via_ifr |= 0x20;
//                    this.int_update();
//                    this.via_t2int = 0;
//                }
//            }
//        }
//
//        /* shift counter */
//
//        this.via_src = ( this.via_src > 0 ? this.via_src - 1 : 0xffff );
//
//        if( (this.via_src & 0xff) == 0xff )
//        {
//            this.via_src = this.via_t2ll;
//
//            if( this.via_srclk )
//            {
//                this.t2shift = 1;
//                this.via_srclk = 0;
//            }
//            else
//            {
//                this.t2shift = 0;
//                this.via_srclk = 1;
//            }
//        }
//        else
//        {
//            this.t2shift = 0;
//        }
//
//        if( this.via_srb < 8 )
//        {
//            switch( this.via_acr & 0x1c )
//            {
//                case 0x00:
//                /* disabled */
//                    break;
//                case 0x04:
//                /* shift in under control of t2 */
//
//                    if( this.t2shift )
//                    {
//                        /* shifting in 0s since cb2 is always an output */
//
//                        this.via_sr <<= 1;
//                        this.via_srb++;
//                    }
//
//                    break;
//                case 0x08:
//                /* shift in under system clk control */
//
//                    this.via_sr <<= 1;
//                    this.via_srb++;
//
//                    break;
//                case 0x0c:
//                /* shift in under cb1 control */
//                    break;
//                case 0x10:
//                /* shift out under t2 control (free run) */
//
//                    if( this.t2shift )
//                    {
//                        this.via_cb2s = (this.via_sr >> 7) & 1;
//
//                        this.via_sr <<= 1;
//                        this.via_sr |= this.via_cb2s;
//                    }
//
//                    break;
//                case 0x14:
//                /* shift out under t2 control */
//
//                    if( this.t2shift )
//                    {
//                        this.via_cb2s = (this.via_sr >> 7) & 1;
//
//                        this.via_sr <<= 1;
//                        this.via_sr |= this.via_cb2s;
//                        this.via_srb++;
//                    }
//
//                    break;
//                case 0x18:
//                /* shift out under system clock control */
//
//                    this.via_cb2s = (this.via_sr >> 7) & 1;
//
//                    this.via_sr <<= 1;
//                    this.via_sr |= this.via_cb2s;
//                    this.via_srb++;
//
//                    break;
//                case 0x1c:
//                /* shift out under cb1 control */
//                    break;
//            }
//
//            if( this.via_srb == 8 )
//            {
//                this.via_ifr |= 0x04;
//                this.int_update();
//            }
//        }
//    }

    /* perform the second part of the via emulation */

//    //static einline void via_sstep1 (void)
//    this.via_sstep1 = function()
//    {
//        if( (this.via_pcr & 0x0e) == 0x0a )
//        {
//            /* if ca2 is in pulse mode, then make sure
//             * it gets restored to '1' after the pulse.
//             */
//
//            this.via_ca2 = 1;
//        }
//
//        if( (this.via_pcr & 0xe0) == 0xa0 )
//        {
//            /* if cb2 is in pulse mode, then make sure
//             * it gets restored to '1' after the pulse.
//             */
//
//            this.via_cb2h = 1;
//        }
//    }

    //this.cacheHit = 0;

    //static einline void alg_addline (long x0, long y0, long x1, long y1, unsigned char color)
    this.alg_addline = function( x0, y0, x1, y1, color )
    {

        //if( utils.logCount-- > 0 ) console.log( "alg_addline: %d %d %d %d %d", x0, y0, x1, y1, color );

        //unsigned long key;
        //long index;
        var key = 0;
        var index = 0;
        var curVec = null;

        key = x0;
        key = key * 31 + y0;
        key = key * 31 + x1;
        key = key * 31 + y1;
        key %= Globals.VECTOR_HASH;

        /* first check if the line to be drawn is in the current draw list.
         * if it is, then it is not added again.
         */

        curVec = null;
        index = this.vector_hash[key];
        if( index >= 0 && index < this.vector_draw_cnt )
        {
            curVec = this.vectors_draw[index];            
        }

        if( curVec != null &&
            x0 == curVec.x0 && y0 == curVec.y0 &&
            x1 == curVec.x1 && y1 == curVec.y1 )
        {
            curVec.color = color;
            //this.cacheHit ++;
        }
        else
        {
            /* missed on the draw list, now check if the line to be drawn is in
             * the erase list ... if it is, "invalidate" it on the erase list.
             */

            curVec = null;
            if( index >= 0 && index < this.vector_erse_cnt )
            {
                curVec = this.vectors_erse[index];
            }

            if( curVec != null &&
                x0 == curVec.x0 && y0 == curVec.y0 &&
                x1 == curVec.x1 && y1 == curVec.y1 )
            {
                this.vectors_erse[index].color = Globals.VECTREX_COLORS;
                //this.cacheHit++;
            }

            curVec = this.vectors_draw[this.vector_draw_cnt];
            curVec.x0 = x0; curVec.y0 = y0;
            curVec.x1 = x1; curVec.y1 = y1;
            curVec.color = color;

            this.vector_hash[key] = this.vector_draw_cnt;
            this.vector_draw_cnt++;
        }
    }

//    /* perform a single cycle worth of analog emulation */
//    //static einline void alg_sstep (void)
//    this.alg_sstep = function()
//    {
//        //long sig_dx, sig_dy;
//        //unsigned sig_ramp;
//        //unsigned sig_blank;
//        var sig_dx = 0;
//        var sig_dy = 0;
//        var sig_ramp = 0;
//        var sig_blank = 0;
//
//        if( (this.via_acr & 0x10) == 0x10 )
//        {
//            sig_blank = this.via_cb2s;
//        }
//        else
//        {
//            sig_blank = this.via_cb2h;
//        }
//
//        if( this.via_ca2 == 0 )
//        {
//            /* need to force the current point to the 'orgin' so just
//             * calculate distance to origin and use that as dx,dy.
//             */
//            sig_dx = this.alg_max_x - this.alg_curr_x;
//            sig_dy = this.alg_max_y - this.alg_curr_y;
//        }
//        else
//        {
//            if( this.via_acr & 0x80 )
//            {
//                sig_ramp = this.via_t1pb7;
//            }
//            else
//            {
//                sig_ramp = this.via_orb & 0x80;
//            }
//
//            if( sig_ramp == 0 )
//            {
//                sig_dx = this.alg_dx;
//                sig_dy = this.alg_dy;
//            }
//            else
//            {
//                sig_dx = 0;
//                sig_dy = 0;
//            }
//        }
//
//        if( this.alg_vectoring == 0 )
//        {
//            if( sig_blank == 1 &&
//                this.alg_curr_x >= 0 && this.alg_curr_x < Globals.ALG_MAX_X &&
//                this.alg_curr_y >= 0 && this.alg_curr_y < Globals.ALG_MAX_Y )
//            {
//                /* start a new vector */
//                this.alg_vectoring = 1;
//                this.alg_vector_x0 = this.alg_curr_x;
//                this.alg_vector_y0 = this.alg_curr_y;
//                this.alg_vector_x1 = this.alg_curr_x;
//                this.alg_vector_y1 = this.alg_curr_y;
//                this.alg_vector_dx = sig_dx;
//                this.alg_vector_dy = sig_dy;
//                this.alg_vector_color = this.alg_zsh & 0xff;
//            }
//        }
//        else
//        {
//            /* already drawing a vector ... check if we need to turn it off */
//
//            if( sig_blank == 0 )
//            {
//                /* blank just went on, vectoring turns off, and we've got a
//                 * new line.
//                 */
//                this.alg_vectoring = 0;
//
//                this.alg_addline(this.alg_vector_x0, this.alg_vector_y0,
//                    this.alg_vector_x1, this.alg_vector_y1,
//                    this.alg_vector_color);
//            }
//            else if( sig_dx != this.alg_vector_dx ||
//                     sig_dy != this.alg_vector_dy ||
//                     ( this.alg_zsh & 0xff ) != this.alg_vector_color )
//            {
//
//                /* the parameters of the vectoring processing has changed.
//                 * so end the current line.
//                 */
//
//                this.alg_addline(this.alg_vector_x0, this.alg_vector_y0,
//                    this.alg_vector_x1, this.alg_vector_y1,
//                    this.alg_vector_color);
//
//                /* we continue vectoring with a new set of parameters if the
//                 * current point is not out of limits.
//                 */
//
//                if( this.alg_curr_x >= 0 && this.alg_curr_x < Globals.ALG_MAX_X &&
//                    this.alg_curr_y >= 0 && this.alg_curr_y < Globals.ALG_MAX_Y )
//                {
//                    this.alg_vector_x0 = this.alg_curr_x;
//                    this.alg_vector_y0 = this.alg_curr_y;
//                    this.alg_vector_x1 = this.alg_curr_x;
//                    this.alg_vector_y1 = this.alg_curr_y;
//                    this.alg_vector_dx = sig_dx;
//                    this.alg_vector_dy = sig_dy;
//                    this.alg_vector_color = this.alg_zsh & 0xff;
//                }
//                else
//                {
//                    this.alg_vectoring = 0;
//                }
//            }
//        }
//
//        this.alg_curr_x += sig_dx;
//        this.alg_curr_y += sig_dy;
//
//        if( this.alg_vectoring == 1 &&
//            this.alg_curr_x >= 0 && this.alg_curr_x < Globals.ALG_MAX_X &&
//            this.alg_curr_y >= 0 && this.alg_curr_y < Globals.ALG_MAX_Y )
//        {
//            /* we're vectoring ... current point is still within limits so
//             * extend the current vector.
//             */
//            this.alg_vector_x1 = this.alg_curr_x;
//            this.alg_vector_y1 = this.alg_curr_y;
//        }
//    }

    //void vecx_emu (long cycles, int ahead)
    this.vecx_emu = function( cycles, ahead )
    {
        var icycles = 0;
        var c = 0;
        var tmp = null;
        var e6809 = this.e6809;
        var osint = this.osint;
        var fcycles_add = Globals.FCYCLES_INIT;

        // alg_sstep inline
        var sig_dx = 0;
        var sig_dy = 0;
        var sig_ramp = 0;
        var sig_blank = 0;

        while( cycles > 0 )
        {
            icycles = e6809.e6809_sstep(this.via_ifr & 0x80, 0);

            for( c = 0; c < icycles; c++ )
            {
                //this.via_sstep0();                
//
// via_sstep0 inline begin
//
                this.t2shift = 0;
                if( this.via_t1on )
                {
                    this.via_t1c = ( this.via_t1c > 0 ? this.via_t1c - 1 : 0xffff );
                    if( (this.via_t1c & 0xffff) == 0xffff )
                    {
                        /* counter just rolled over */
                        if( this.via_acr & 0x40 )
                        {
                            /* continuous interrupt mode */
                            this.via_ifr |= 0x40;

                            //this.int_update();
                            // int_update inline begin
                            if( (this.via_ifr & 0x7f) & (this.via_ier & 0x7f) )
                            {
                                this.via_ifr |= 0x80;
                            }
                            else
                            {
                                this.via_ifr &= 0x7f;
                            }
                            // int_update inline end

                            this.via_t1pb7 = 0x80 - this.via_t1pb7;
                            /* reload counter */
                            this.via_t1c = (this.via_t1lh << 8) | this.via_t1ll;
                        }
                        else
                        {
                            /* one shot mode */

                            if( this.via_t1int )
                            {
                                this.via_ifr |= 0x40;

                                //this.int_update();
                                // int_update inline begin
                                if( (this.via_ifr & 0x7f) & (this.via_ier & 0x7f) )
                                {
                                    this.via_ifr |= 0x80;
                                }
                                else
                                {
                                    this.via_ifr &= 0x7f;
                                }
                                // int_update inline end

                                this.via_t1pb7 = 0x80;
                                this.via_t1int = 0;
                            }
                        }
                    }
                }

                if( this.via_t2on && (this.via_acr & 0x20) == 0x00 )
                {
                    this.via_t2c = ( this.via_t2c > 0 ? this.via_t2c - 1 : 0xffff );
                    if( (this.via_t2c & 0xffff) == 0xffff )
                    {
                        /* one shot mode */
                        if( this.via_t2int )
                        {
                            this.via_ifr |= 0x20;

                            //this.int_update();
                            // int_update inline begin
                            if( (this.via_ifr & 0x7f) & (this.via_ier & 0x7f) )
                            {
                                this.via_ifr |= 0x80;
                            }
                            else
                            {
                                this.via_ifr &= 0x7f;
                            }
                            // int_update inline end

                            this.via_t2int = 0;
                        }
                    }
                }

                /* shift counter */
                this.via_src = ( this.via_src > 0 ? this.via_src - 1 : 0xff ); // raz was 0xffffffff
                if( (this.via_src & 0xff) == 0xff )
                {
                    this.via_src = this.via_t2ll;

                    if( this.via_srclk )
                    {
                        this.t2shift = 1;
                        this.via_srclk = 0;
                    }
                    else
                    {
                        this.t2shift = 0;
                        this.via_srclk = 1;
                    }
                }
                else
                {
                    this.t2shift = 0;
                }

                if( this.via_srb < 8 )
                {
                    switch( this.via_acr & 0x1c )
                    {
                        case 0x00:
                        /* disabled */
                            break;
                        case 0x04:
                        /* shift in under control of t2 */

                            if( this.t2shift )
                            {
                                /* shifting in 0s since cb2 is always an output */
                                this.via_sr <<= 1;
                                this.via_srb++;
                            }
                            break;
                        case 0x08:
                            /* shift in under system clk control */
                            this.via_sr <<= 1;
                            this.via_srb++;
                            break;
                        case 0x0c:
                            /* shift in under cb1 control */
                            break;
                        case 0x10:
                            /* shift out under t2 control (free run) */
                            if( this.t2shift )
                            {
                                this.via_cb2s = (this.via_sr >> 7) & 1;
                                this.via_sr <<= 1;
                                this.via_sr |= this.via_cb2s;
                            }
                            break;
                        case 0x14:
                        /* shift out under t2 control */

                            if( this.t2shift )
                            {
                                this.via_cb2s = (this.via_sr >> 7) & 1;

                                this.via_sr <<= 1;
                                this.via_sr |= this.via_cb2s;
                                this.via_srb++;
                            }
                            break;
                        case 0x18:
                        /* shift out under system clock control */

                            this.via_cb2s = (this.via_sr >> 7) & 1;

                            this.via_sr <<= 1;
                            this.via_sr |= this.via_cb2s;
                            this.via_srb++;
                            break;
                        case 0x1c:
                        /* shift out under cb1 control */
                            break;
                    }

                    if( this.via_srb == 8 )
                    {
                        this.via_ifr |= 0x04;

                        //this.int_update();
                        // int_update inline begin
                        if( (this.via_ifr & 0x7f) & (this.via_ier & 0x7f) )
                        {
                            this.via_ifr |= 0x80;
                        }
                        else
                        {
                            this.via_ifr &= 0x7f;
                        }
                        // int_update inline end
                    }
                }
//
// via_sstep0 inline end
//

                //this.alg_sstep();
//
// alg_sstep inline begin
//
                //long sig_dx, sig_dy;
                //unsigned sig_ramp;
                //unsigned sig_blank;
                sig_dx = 0;
                sig_dy = 0;
                sig_ramp = 0;
                sig_blank = 0;

                if( (this.via_acr & 0x10) == 0x10 )
                {
                    sig_blank = this.via_cb2s;
                }
                else
                {
                    sig_blank = this.via_cb2h;
                }

                if( this.via_ca2 == 0 )
                {
                    /* need to force the current point to the 'orgin' so just
                     * calculate distance to origin and use that as dx,dy.
                     */
                    sig_dx = this.alg_max_x - this.alg_curr_x;
                    sig_dy = this.alg_max_y - this.alg_curr_y;
                }
                else
                {
                    if( this.via_acr & 0x80 )
                    {
                        sig_ramp = this.via_t1pb7;
                    }
                    else
                    {
                        sig_ramp = this.via_orb & 0x80;
                    }

                    if( sig_ramp == 0 )
                    {
                        sig_dx = this.alg_dx;
                        sig_dy = this.alg_dy;
                    }
                    else
                    {
                        sig_dx = 0;
                        sig_dy = 0;
                    }
                }

                if( this.alg_vectoring == 0 )
                {
                    if( sig_blank == 1 &&
                        this.alg_curr_x >= 0 && this.alg_curr_x < Globals.ALG_MAX_X &&
                        this.alg_curr_y >= 0 && this.alg_curr_y < Globals.ALG_MAX_Y )
                    {
                        /* start a new vector */
                        this.alg_vectoring = 1;
                        this.alg_vector_x0 = this.alg_curr_x;
                        this.alg_vector_y0 = this.alg_curr_y;
                        this.alg_vector_x1 = this.alg_curr_x;
                        this.alg_vector_y1 = this.alg_curr_y;
                        this.alg_vector_dx = sig_dx;
                        this.alg_vector_dy = sig_dy;
                        this.alg_vector_color = this.alg_zsh & 0xff;
                    }
                }
                else
                {
                    /* already drawing a vector ... check if we need to turn it off */

                    if( sig_blank == 0 )
                    {
                        /* blank just went on, vectoring turns off, and we've got a
                         * new line.
                         */
                        this.alg_vectoring = 0;

                        this.alg_addline(this.alg_vector_x0, this.alg_vector_y0,
                            this.alg_vector_x1, this.alg_vector_y1,
                            this.alg_vector_color);
                    }
                    else if( sig_dx != this.alg_vector_dx ||
                             sig_dy != this.alg_vector_dy ||
                             ( this.alg_zsh & 0xff ) != this.alg_vector_color )
                    {

                        /* the parameters of the vectoring processing has changed.
                         * so end the current line.
                         */

                        this.alg_addline(this.alg_vector_x0, this.alg_vector_y0,
                            this.alg_vector_x1, this.alg_vector_y1,
                            this.alg_vector_color);

                        /* we continue vectoring with a new set of parameters if the
                         * current point is not out of limits.
                         */

                        if( this.alg_curr_x >= 0 && this.alg_curr_x < Globals.ALG_MAX_X &&
                            this.alg_curr_y >= 0 && this.alg_curr_y < Globals.ALG_MAX_Y )
                        {
                            this.alg_vector_x0 = this.alg_curr_x;
                            this.alg_vector_y0 = this.alg_curr_y;
                            this.alg_vector_x1 = this.alg_curr_x;
                            this.alg_vector_y1 = this.alg_curr_y;
                            this.alg_vector_dx = sig_dx;
                            this.alg_vector_dy = sig_dy;
                            this.alg_vector_color = this.alg_zsh & 0xff;
                        }
                        else
                        {
                            this.alg_vectoring = 0;
                        }
                    }
                }

                this.alg_curr_x += sig_dx;
                this.alg_curr_y += sig_dy;

                if( this.alg_vectoring == 1 &&
                    this.alg_curr_x >= 0 && this.alg_curr_x < Globals.ALG_MAX_X &&
                    this.alg_curr_y >= 0 && this.alg_curr_y < Globals.ALG_MAX_Y )
                {
                    /* we're vectoring ... current point is still within limits so
                     * extend the current vector.
                     */
                    this.alg_vector_x1 = this.alg_curr_x;
                    this.alg_vector_y1 = this.alg_curr_y;
                }
//
// alg_sstep inline end
//

                //this.via_sstep1();
//
// alg_sstep1 inline begin
//
                if( (this.via_pcr & 0x0e) == 0x0a )
                {
                    /* if ca2 is in pulse mode, then make sure
                     * it gets restored to '1' after the pulse.
                     */

                    this.via_ca2 = 1;
                }

                if( (this.via_pcr & 0xe0) == 0xa0 )
                {
                    /* if cb2 is in pulse mode, then make sure
                     * it gets restored to '1' after the pulse.
                     */

                    this.via_cb2h = 1;
                }
            }
//
// alg_sstep1 inline end
//

//this.validateState();

            cycles -= icycles;
            this.fcycles -= icycles;

            if( this.fcycles < 0 )
            {
                this.fcycles += fcycles_add;

                osint.osint_render();

                // everything that was drawn during this pass now now enters
                // the erase list for the next pass.
                //
                this.vector_erse_cnt = this.vector_draw_cnt;
                this.vector_draw_cnt = 0;

                tmp = this.vectors_erse;
                this.vectors_erse = this.vectors_draw;
                this.vectors_draw = tmp;
            }
        }
    }

    this.count = 0;
    this.startTime = null;
    this.nextFrameTime = null;
    this.extraTime = 0;
    this.fpsTimer = null;

    this.running = false;

    this.vecx_emuloop = function()
    {
        if( this.running ) return;

        this.running = true;

        var EMU_TIMER = this.osint.EMU_TIMER;
        var cycles = ( Globals.VECTREX_MHZ / 1000 >> 0 ) * EMU_TIMER;
        var vecx = this;

        this.startTime = this.nextFrameTime = new Date().getTime() + EMU_TIMER;
        this.count = 0;
        this.extraTime = 0;

        this.fpsTimer = setInterval(
            function()
            {
                $("#status").text(  "FPS: " +
                    ( vecx.count / ( new Date().getTime() - vecx.startTime )
                        * 1000.0 ).toFixed(2) + " (50)" +
                    ( vecx.extraTime > 0 ?
                       ( ", extra: " +
                            ( vecx.extraTime / ( vecx.count / 50 ) ).toFixed(2)
                                + " (ms)" ) : "" ) );
                    
                if( vecx.count > 500 )
                {
                    vecx.startTime = new Date().getTime();
                    vecx.count = 0;
                    vecx.extraTime = 0;
                }
            }, 2000
        );

        var f = function()
        {
            if( !vecx.running ) return;

            vecx.alg_jch0 =
                 ( vecx.leftHeld ? 0x00 :
                     ( vecx.rightHeld ? 0xff :
                        0x80 ) );

            vecx.alg_jch1 =
                 ( vecx.downHeld ? 0x00 :
                    ( vecx.upHeld ? 0xff :
                        0x80 ) );

            vecx.snd_regs[14] = vecx.shadow_snd_regs14;

            try {
                vecx.vecx_emu.call( vecx, cycles, 0 );
            } catch (e) {
                // Illegal opcode or other fatal error - stop emulator gracefully
                console.error("[JSVecx] Emulator halted:", e.message);
                vecx.running = false;
                vecx.halted = true;
                if (vecx.fpsTimer) {
                    clearInterval(vecx.fpsTimer);
                    vecx.fpsTimer = null;
                }
                vecx.e8910.stop();
                return; // Don't schedule next frame
            }
            vecx.count++;

            var now = new Date().getTime();
            var waitTime = vecx.nextFrameTime - now;
            vecx.extraTime += waitTime;
            if( waitTime < -EMU_TIMER ) waitTime = -EMU_TIMER;

            vecx.nextFrameTime = now + EMU_TIMER + waitTime;            

            setTimeout( function() { f(); }, waitTime );
        };

        setTimeout( f, 15 );
    }

    this.stop = function()
    {
        if( this.running )
        {
            if( this.fpsTimer != null )
            {
                clearInterval( this.fpsTimer );
                this.fpsTimer = null;
            }

            this.running = false;
            this.e8910.stop();
        }
    }

    this.start = function()
    {
        if( !this.running )
        {
            this.e8910.start();
            this.vecx_emuloop();
        }
    }

    this.main = function()
    {
        this.osint.init( this );
        this.e6809.init( this );

        $("#status").text("Loaded.");

        /* message loop handler and emulator code */
        /* reset the vectrex hardware */
        this.vecx_reset();
        this.start();
    }

    this.reset = function()
    {
        this.stop();
        this.vecx_reset();
        this.osint.osint_clearscreen();

        var vecx = this;
        setTimeout( function() { vecx.start(); }, 200 );
    }
    
    this.toggleSoundEnabled = function() 
    {
        return this.e8910.toggleEnabled();
    }

    this.leftHeld = false;
    this.rightHeld = false;
    this.upHeld = false;
    this.downHeld = false;
    this.shadow_snd_regs14 = 0xff;

    this.onkeydown = function( event )
    {
        var handled = true;
        switch( event.keyCode )
        {
            case 37: // left
            case 76:
                //this.shadow_alg_jch0 = 0x00;
                this.leftHeld = true;
                break;
            case 38: // up
            case 80:
                this.upHeld = true;
                //this.shadow_alg_jch1 = 0xff;
                break;
            case 39: // right
            case 222:
                this.rightHeld = true;
                //this.shadow_alg_jch0 = 0xff;
                break;
            case 40: // down
            case 59:
            case 186:
                this.downHeld = true;
                //this.shadow_alg_jch1 = 0x00;
                break;
            case 65: // a
                this.shadow_snd_regs14 &= (~0x01);
                break;
            case 83: // s
                this.shadow_snd_regs14 &= (~0x02);
                break;
            case 68: // d
                this.shadow_snd_regs14 &= (~0x04);
                break;
            case 70: // f
                this.shadow_snd_regs14 &= (~0x08);
                break;
            default:
                handled = false;
        }

        if( handled && event.preventDefault )
        {
            event.preventDefault();
        }
    }

    this.onkeyup = function( event )
    {
        var handled = true;
        switch( event.keyCode )
        {
            case 37: // left
            case 76:
                this.leftHeld = false;
                //this.shadow_alg_jch0 = 0x80;
                break;
            case 38: // up
            case 80:
                this.upHeld = false;
                //this.shadow_alg_jch1 = 0x80;
                break;
            case 39: // right
            case 222:
                this.rightHeld = false;
                //this.shadow_alg_jch0 = 0x80;
                break;
            case 40: // down
            case 59:
            case 186:
                this.downHeld = false;
                //this.shadow_alg_jch1 = 0x80;
                break;
            case 65: // a
                this.shadow_snd_regs14 |= 0x01;
                break;
            case 83: // s
                this.shadow_snd_regs14 |= 0x02;
                break;
            case 68: // d
                this.shadow_snd_regs14 |= 0x04;
                break;
            case 70: // f
                this.shadow_snd_regs14 |= 0x08;
                break;
            default:
                handled = false;
        }

        if( handled && event.preventDefault )
        {
            event.preventDefault();
        }
    }

    
}

//Globals.vecx = new VecX();

/* END vecx.js */

export { VecX, Globals };
