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
    this.osint = new osint();
    this.e6809 = new e6809();
    this.e8910 = new e8910();
    this.rom = new Array(0x2000);
    utils.initArray(this.rom, 0);
    this.cart = new Array(0x8000);
    utils.initArray(this.cart, 0);
    this.ram = new Array(0x400);
    utils.initArray(this.ram, 0);
    this.snd_regs = new Array(16);
    this.e8910.init(this.snd_regs);
    this.snd_select = 0;
    
    // Multi-bank ROM support (512KB ROM with 32 banks of 16KB)
    this.multibankRom = null;     // Full 512KB ROM data
    this.currentBank = 0;         // Current bank number (0-31)
    this.bankRegister = 0xDF00;   // Bank register (write-only, cartucho I/O at $DF00 - avoids VIA DP collision)
    this.isMultibank = false;     // Flag if multi-bank ROM loaded
    
    // Debug system - Estado del debugger
    this.debugState = 'stopped'; // 'stopped' | 'running' | 'paused'
    this.breakpoints = new Set(); // Set de direcciones con breakpoints
    this.stepMode = null; // null | 'over' | 'into' | 'out'
    this.stepTargetAddress = null; // Dirección objetivo para step over
    this.callStackDepth = 0; // Profundidad de la pila de llamadas (para step out)
    this.isNativeCallStepInto = false; // Flag para saltar JSR en step into de native calls
    this.skipNextBreakpoint = false; // Flag para saltarse breakpoint una vez (step desde breakpoint)
    this.via_ora = 0;
    this.via_orb = 0;
    this.via_ddra = 0;
    this.via_ddrb = 0;
    this.via_t1on = 0;
    this.via_t1int = 0;
    this.via_t1c = 0;
    this.via_t1ll = 0;
    this.via_t1lh = 0;
    this.via_t1pb7 = 0;
    this.via_t2on = 0;
    this.via_t2int = 0;
    this.via_t2c = 0;
    this.via_t2ll = 0;
    this.via_sr = 0;
    this.via_srb = 0;
    this.via_src = 0;
    this.via_srclk = 0;
    this.via_acr = 0;
    this.via_pcr = 0;
    this.via_ifr = 0;
    this.via_ier = 0;
    this.via_ca2 = 0;
    this.via_cb2h = 0;
    this.via_cb2s = 0;
    this.alg_rsh = 0;
    this.alg_xsh = 0;
    this.alg_ysh = 0;
    this.alg_zsh = 0;
    this.alg_jch0 = 0;
    this.alg_jch1 = 0;
    this.alg_jch2 = 0;
    this.alg_jch3 = 0;
    this.alg_jsh = 0;
    this.alg_compare = 0;
    this.alg_dx = 0;
    this.alg_dy = 0;
    this.alg_curr_x = 0;
    this.alg_curr_y = 0;
    this.alg_max_x = Globals.ALG_MAX_X >> 1;
    this.alg_max_y = Globals.ALG_MAX_Y >> 1;
    this.alg_vectoring = 0;
    this.alg_vector_x0 = 0;
    this.alg_vector_y0 = 0;
    this.alg_vector_x1 = 0;
    this.alg_vector_y1 = 0;
    this.alg_vector_dx = 0;
    this.alg_vector_dy = 0;
    this.alg_vector_color = 0;
    this.vector_draw_cnt = 0;
    this.vector_erse_cnt = 0;
    this.vectors_draw = new Array(Globals.VECTOR_CNT);
    this.vectors_erse = new Array(Globals.VECTOR_CNT);
    this.vector_hash = new Array(Globals.VECTOR_HASH);
    utils.initArray(this.vector_hash, 0);
    this.fcycles = 0;
    this.snd_update = function()
    {
        switch( this.via_orb & 0x18 )
        {
            case 0x00:
                break;
            case 0x08:
                break;
            case 0x10:
                if( this.snd_select != 14 )
                {
                    this.snd_regs[this.snd_select] = this.via_ora;
                    this.e8910.e8910_write(this.snd_select, this.via_ora);
                }
                break;
            case 0x18:
                if( (this.via_ora & 0xf0) == 0x00 )
                {
                    this.snd_select = this.via_ora & 0x0f;
                }
                break;
        }
    }
    this.alg_update = function()
    {
        switch( this.via_orb & 0x06 )
        {
            case 0x00:
                this.alg_jsh = this.alg_jch0;
                if( (this.via_orb & 0x01) == 0x00 )
                {
                    this.alg_ysh = this.alg_xsh;
                }
                break;
            case 0x02:
                this.alg_jsh = this.alg_jch1;
                if( (this.via_orb & 0x01) == 0x00 )
                {
                    this.alg_rsh = this.alg_xsh;
                }
                break;
            case 0x04:
                this.alg_jsh = this.alg_jch2;
                if( (this.via_orb & 0x01) == 0x00 )
                {
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
                this.alg_jsh = this.alg_jch3;
                break;
        }
        if( this.alg_jsh > this.alg_xsh )
        {
            this.alg_compare = 0x20;
        }
        else
        {
            this.alg_compare = 0;
        }
        this.alg_dx = this.alg_xsh - this.alg_rsh;
        this.alg_dy = this.alg_rsh - this.alg_ysh;
    }
    this.read8 = function( address )
    {
        address &= 0xffff;
        
        // Multi-bank ROM support (cartridge ROM at 0x0000-0x5FFF)
        if (this.isMultibank) {
            const bankSize = 0x4000; // 16KB per bank
            const numBanks = Math.floor(this.multibankRom.length / bankSize);
            const fixedBankId = numBanks - 1; // Last bank is fixed
            
            // Banked window: 0x0000-0x3FFF (16KB switchable)
            if (address < 0x4000) {
                const bankOffset = this.currentBank * bankSize;
                return this.multibankRom[bankOffset + address] & 0xff;
            }
            // Fixed bank (last bank): 0x4000-0x7FFF (16KB always visible)
            if (address >= 0x4000 && address < 0x8000) {
                const fixedBankOffset = fixedBankId * bankSize;
                const localOffset = address - 0x4000;
                return this.multibankRom[fixedBankOffset + localOffset] & 0xff;
            }
        }
        
        // Original ROM mapping (BIOS at 0xE000-0xFFFF)
        if( (address & 0xe000) == 0xe000 )
        {
            return this.rom[address & 0x1fff] & 0xff;
        }
        if( (address & 0xe000) == 0xc000 )
        {
            if( address & 0x800 )
            {
                return this.ram[address & 0x3ff] & 0xff;
            }
            var data = 0;
            switch( address & 0xf )
            {
                case 0x0:
                    if( this.via_acr & 0x80 )
                    {
                        data = ((this.via_orb & 0x5f) | this.via_t1pb7 | this.alg_compare);
                    }
                    else
                    {
                        data = ((this.via_orb & 0xdf) | this.alg_compare);
                    }
                    return data & 0xff;
                case 0x1:
                    if( (this.via_pcr & 0x0e) == 0x08 )
                    {
                        this.via_ca2 = 0;
                    }
                case 0xf:
                    if( (this.via_orb & 0x18) == 0x08 )
                    {
                        // Button injection for PSG register 14 reads
                        if (this.snd_select === 14) {
                            if (typeof window !== 'undefined' && window.injectedButtonStatePSG !== undefined) {
                                data = window.injectedButtonStatePSG;
                            } else {
                                data = this.snd_regs[this.snd_select];
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
                    data = this.via_t1c;
                    this.via_ifr &= 0xbf;
                    this.via_t1on = 0;
                    this.via_t1int = 0;
                    this.via_t1pb7 = 0x80;
                    if( (this.via_ifr & 0x7f) & (this.via_ier & 0x7f) )
                    {
                        this.via_ifr |= 0x80;
                    }
                    else
                    {
                        this.via_ifr &= 0x7f;
                    }
                    return data & 0xff;
                case 0x5:
                    return (this.via_t1c >> 8) & 0xff;
                case 0x6:
                    return this.via_t1ll & 0xff;
                case 0x7:
                    return this.via_t1lh & 0xff;
                case 0x8:
                    data = this.via_t2c;
                    this.via_ifr &= 0xdf;
                    this.via_t2on = 0;
                    this.via_t2int = 0;
                    if( (this.via_ifr & 0x7f) & (this.via_ier & 0x7f) )
                    {
                        this.via_ifr |= 0x80;
                    }
                    else
                    {
                        this.via_ifr &= 0x7f;
                    }
                    return data & 0xff;
                case 0x9:
                    return (this.via_t2c >> 8);
                case 0xa:
                    data = this.via_sr;
                    this.via_ifr &= 0xfb;
                    this.via_srb = 0;
                    this.via_srclk = 1;
                    if( (this.via_ifr & 0x7f) & (this.via_ier & 0x7f) )
                    {
                        this.via_ifr |= 0x80;
                    }
                    else
                    {
                        this.via_ifr &= 0x7f;
                    }
                    return data & 0xff;
                case 0xb:
                    return this.via_acr & 0xff;
                case 0xc:
                    return this.via_pcr & 0xff;
                case 0xd:
                    return this.via_ifr & 0xff;
                case 0xe:
                    return (this.via_ier | 0x80) & 0xff;
            }
        }
        if( address < 0x8000 )
        {
            // Multi-bank ROM support
            if (this.isMultibank) {
                // Banked window: 0x0000-0x3FFF (16KB) → select bank via currentBank
                if (address < 0x4000) {
                    const bankSize = 0x4000; // 16KB per bank
                    const romOffset = (this.currentBank * bankSize) + address;
                    // DEBUG: Log suspicious reads from bank 0 area when currentBank != 0
                    if (this.currentBank !== 0) {
                        console.warn('[JSVecx] Reading from $' + address.toString(16).padStart(4, '0') + 
                            ' with currentBank=' + this.currentBank + ' (romOffset=0x' + romOffset.toString(16) + ')');
                    }
                    return this.multibankRom[romOffset] & 0xff;
                }
                // Fixed window: 0x4000-0x7FFF (16KB) → always bank #31
                else {
                    const bankSize = 0x4000;
                    const romOffset = (31 * bankSize) + (address - 0x4000);
                    const value = this.multibankRom[romOffset] & 0xff;
                    // DEBUG: Log reads from first 64 bytes of Bank #31 (VECTOR_BANK_TABLE area)
                    if (address < 0x4040) {
                        const pcStr = '0x' + (this.e6809.reg_pc & 0xffff).toString(16).toUpperCase().padStart(4, '0');
                        console.log('[JSVecx DEBUG] Read $' + address.toString(16).toUpperCase().padStart(4, '0') + 
                            ' from Bank#31 (offset=0x' + romOffset.toString(16) + ') = 0x' + value.toString(16).toUpperCase() +
                            ' PC=' + pcStr);
                    }
                    return value;
                }
            }
            // Single-bank cartridge
            return this.cart[address] & 0xff;
        }
        return 0xff;
    }
    this.write8 = function( address, data )
    {
        address &= 0xffff;
        data &= 0xff;

        // Multi-bank ROM bank switch register (write-only, single address intercept)
        if (this.isMultibank && address === this.bankRegister) {
            const bankSize = 0x4000;
            const numBanks = Math.floor(this.multibankRom.length / bankSize);
            const maxBankId = numBanks - 1;
            const oldBank = this.currentBank;
            const rawData = data;
            this.currentBank = data & maxBankId; // Mask to valid bank range
            const pcStr = '0x' + (this.e6809.reg_pc & 0xffff).toString(16).toUpperCase().padStart(4, '0');
            
            // DEBUG: Show where the bank value came from
            const regA = this.e6809.reg_a & 0xff;
            const regB = this.e6809.reg_b & 0xff;
            const regX = this.e6809.reg_x & 0xffff;
            const regD = ((regA << 8) | regB) & 0xffff;
            
            // DEBUG: Read what's ACTUALLY at $4000 in Bank #31
            const tableOffset = (31 * bankSize) + 0; // VECTOR_BANK_TABLE should be at $4000
            const actualByte0 = this.multibankRom[tableOffset] & 0xff;
            const actualByte1 = this.multibankRom[tableOffset + 1] & 0xff;
            const actualByte2 = this.multibankRom[tableOffset + 2] & 0xff;
            
            console.log('[JSVecx Multi-bank] Bank switched at PC=' + pcStr + 
                ': ' + oldBank + ' -> ' + this.currentBank + '/' + maxBankId +
                ' (raw_data=0x' + rawData.toString(16).toUpperCase() + 
                ', A=0x' + regA.toString(16).toUpperCase() +
                ', B=0x' + regB.toString(16).toUpperCase() +
                ', X=0x' + regX.toString(16).toUpperCase() +
                ', D=0x' + regD.toString(16).toUpperCase() +
                ', ROM[$4000-2]=0x' + actualByte0.toString(16) + ' 0x' + actualByte1.toString(16) + ' 0x' + actualByte2.toString(16) + ')');
            // DON'T return - let the write complete normally so CPU cycle continues
            // The bank switch is just a side effect, doesn't interrupt execution flow
        }
        
        if( (address & 0xe000) == 0xe000 )
        {
        }
        else if( (address & 0xe000) == 0xc000 )
        {
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
                            this.via_cb2h = 0;
                        }
                        break;
                    case 0x1:
                        if( (this.via_pcr & 0x0e) == 0x08 )
                        {
                            this.via_ca2 = 0;
                        }
                    case 0xf:
                        this.via_ora = data;
                        this.snd_update();
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
                        this.via_t1ll = data;
                        break;
                    case 0x5:
                        this.via_t1lh = data;
                        this.via_t1c = (this.via_t1lh << 8) | this.via_t1ll;
                        this.via_ifr &= 0xbf;
                        this.via_t1on = 1;
                        this.via_t1int = 1;
                        this.via_t1pb7 = 0;
                        if( (this.via_ifr & 0x7f) & (this.via_ier & 0x7f) )
                        {
                            this.via_ifr |= 0x80;
                        }
                        else
                        {
                            this.via_ifr &= 0x7f;
                        }
                        break;
                    case 0x6:
                        this.via_t1ll = data;
                        break;
                    case 0x7:
                        this.via_t1lh = data;
                        break;
                    case 0x8:
                        this.via_t2ll = data;
                        break;
                    case 0x9:
                        this.via_t2c = (data << 8) | this.via_t2ll;
                        this.via_ifr &= 0xdf;
                        this.via_t2on = 1;
                        this.via_t2int = 1;
                        if( (this.via_ifr & 0x7f) & (this.via_ier & 0x7f) )
                        {
                            this.via_ifr |= 0x80;
                        }
                        else
                        {
                            this.via_ifr &= 0x7f;
                        }
                        break;
                    case 0xa:
                        this.via_sr = data;
                        this.via_ifr &= 0xfb;
                        this.via_srb = 0;
                        this.via_srclk = 1;
                        if( (this.via_ifr & 0x7f) & (this.via_ier & 0x7f) )
                        {
                            this.via_ifr |= 0x80;
                        }
                        else
                        {
                            this.via_ifr &= 0x7f;
                        }
                        break;
                    case 0xb:
                        this.via_acr = data;
                        break;
                    case 0xc:
                        this.via_pcr = data;
                        if( (this.via_pcr & 0x0e) == 0x0c )
                        {
                            this.via_ca2 = 0;
                        }
                        else
                        {
                            this.via_ca2 = 1;
                        }
                        if( (this.via_pcr & 0xe0) == 0xc0 )
                        {
                            this.via_cb2h = 0;
                        }
                        else
                        {
                            this.via_cb2h = 1;
                        }
                        break;
                    case 0xd:
                        this.via_ifr &= (~(data & 0x7f));
                        if( (this.via_ifr & 0x7f) & (this.via_ier & 0x7f) )
                        {
                            this.via_ifr |= 0x80;
                        }
                        else
                        {
                            this.via_ifr &= 0x7f;
                        }
                        break;
                    case 0xe:
                        if( data & 0x80 )
                        {
                            this.via_ier |= data & 0x7f;
                        }
                        else
                        {
                            this.via_ier &= (~(data & 0x7f));
                        }
                        if( (this.via_ifr & 0x7f) & (this.via_ier & 0x7f) )
                        {
                            this.via_ifr |= 0x80;
                        }
                        else
                        {
                            this.via_ifr &= 0x7f;
                        }
                        break;
                }
            }
        }
        else if( address < 0x8000 )
        {
        }
    }
    this.vecx_reset = function()
    {
        for( var r = 0; r < this.ram.length; r++ )
        {
            this.ram[r] = r & 0xff;
        }
        for( var r = 0; r < 16; r++ )
        {
            this.snd_regs[r] = 0;
            this.e8910.e8910_write(r, 0);
        }
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
        var len = Globals.romdata.length;
        for( var i = 0; i < len; i++ )
        {
            this.rom[i] = Globals.romdata.charCodeAt(i);
        }
        len = this.cart.length;
        for( var b = 0; b < len; b++ )
        {
            this.cart[b] = 0x01;
        }
        if( Globals.cartdata != null )
        {
            len = Globals.cartdata.length;
            
            // Multi-bank ROM detection: any ROM > 32KB is multi-bank (up to 4MB)
            if (len > 32768) {
                const bankSize = 16384; // 16KB per bank
                const numBanks = Math.floor(len / bankSize);
                console.log('[JSVecx Multi-bank] Detected ' + len + ' bytes ROM (' + (len/1024) + 'KB)');
                console.log('[JSVecx Multi-bank] Banks: ' + numBanks + ' x ' + (bankSize/1024) + 'KB');
                this.isMultibank = true;
                this.currentBank = 0;
                this.multibankRom = new Uint8Array(len);
                for (var i = 0; i < len; i++) {
                    this.multibankRom[i] = Globals.cartdata.charCodeAt(i) & 0xFF;
                }
                // Verification: dump first 80 bytes to check load
                var hexDump = '[JSVecx Multi-bank] First 80 bytes: ';
                for (var j = 0; j < 80 && j < len; j++) {
                    hexDump += this.multibankRom[j].toString(16).padStart(2, '0') + ' ';
                }
                console.log(hexDump);
                // Check byte at 0x0048 specifically
                console.log('[JSVecx Multi-bank] Byte at 0x0048: 0x' + this.multibankRom[0x0048].toString(16).padStart(2, '0') + ' (expected: 0x86 for LDA #)');
            } else {
                // Standard cartridge (up to 32KB)
                console.log('[JSVecx Multi-bank] Regular Cart detected: ' + len + ' bytes (' + (len/1024) + 'KB)');
                this.isMultibank = false;
                for( var i = 0; i < len; i++ )
                {
                    this.cart[i] = Globals.cartdata.charCodeAt(i);
                }
            }
        }
        this.fcycles = Globals.FCYCLES_INIT;
        this.totalCycles = 0; // Reset contadores
        this.instructionCount = 0;
        this.e6809.e6809_reset();
    }
    this.t2shift = 0;
    this.alg_addline = function( x0, y0, x1, y1, color )
    {
        var key = 0;
        var index = 0;
        var curVec = null;
        key = x0;
        key = key * 31 + y0;
        key = key * 31 + x1;
        key = key * 31 + y1;
        key %= Globals.VECTOR_HASH;
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
        }
        else
        {
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
            }
            curVec = this.vectors_draw[this.vector_draw_cnt];
            curVec.x0 = x0; curVec.y0 = y0;
            curVec.x1 = x1; curVec.y1 = y1;
            curVec.color = color;
            this.vector_hash[key] = this.vector_draw_cnt;
            this.vector_draw_cnt++;
        }
    }
    this.vecx_emu = function( cycles, ahead )
    {
        var icycles = 0;
        var c = 0;
        var tmp = null;
        var e6809 = this.e6809;
        var osint = this.osint;
        var fcycles_add = Globals.FCYCLES_INIT;
        var sig_dx = 0;
        var sig_dy = 0;
        var sig_ramp = 0;
        var sig_blank = 0;
        while( cycles > 0 )
        {
            // Debug: Check breakpoint ANTES de ejecutar la instrucción
            // BUT: skip breakpoint check if in step mode (step handles pause itself)
            var currentPC = e6809.reg_pc;
            
            // Expose current PC globally for PSG logging
            if (typeof window !== 'undefined') {
                window.g_currentPC = currentPC;
            }
            
            if (this.debugState === 'running' && this.breakpoints.has(currentPC)) {
                // Skip breakpoint if flag is set (stepping from breakpoint)
                if (this.skipNextBreakpoint) {
                    console.log('[JSVecx Debug] ⏭️ Skipping breakpoint at PC: 0x' + currentPC.toString(16).toUpperCase() + ' (step from breakpoint)');
                    this.skipNextBreakpoint = false; // Clear flag after skipping once
                } else {
                    console.log('[JSVecx Debug] 🔴 BEFORE EXECUTION - Breakpoint hit at PC: 0x' + currentPC.toString(16).toUpperCase());
                    this.pauseDebugger('breakpoint', currentPC);
                    return; // Detener ejecución inmediatamente
                }
            }
            
            // Debug: Check step over/into/out
            if (this.stepMode === 'over' && currentPC === this.stepTargetAddress) {
                this.pauseDebugger('step', currentPC);
                this.stepMode = null;
                this.stepTargetAddress = null;
                return;
            }
            
            if (this.stepMode === 'into') {
                // Step into: When stepping into native calls, skip instructions until we reach the JSR
                if (this.isNativeCallStepInto) {
                    var opcode = this.read8(currentPC);
                    // console.log('[JSVecx Debug] Native call mode: opcode 0x' + opcode.toString(16) + ' at PC=0x' + currentPC.toString(16));
                    if (opcode === 0xBD || opcode === 0x9D || opcode === 0xAD || opcode === 0x8D) { // JSR variants
                        console.log('[JSVecx Debug] ✅ Found JSR! Will execute and pause at target');
                        this.isNativeCallStepInto = false; // Only skip once
                        // Don't pause - continue to execute JSR and pause at target
                    } else {
                        // Not JSR yet - keep stepping through setup code (LDD, STD, etc.)
                        // console.log('[JSVecx Debug] Not JSR yet, continuing to next instruction');
                        // Don't pause - keep stepping until we find the JSR
                    }
                }
                // CRITICAL: Don't pause before executing - let instruction execute first
                // The check AFTER instruction execution (line ~710) will pause at the new PC
            }
            
            if (this.stepMode === 'out' && this.callStackDepth === 0) {
                // Step out pausa cuando retornamos al nivel original
                this.pauseDebugger('step', currentPC);
                this.stepMode = null;
                return;
            }
            
            icycles = e6809.e6809_sstep(this.via_ifr & 0x80, 0);
            this.instructionCount++; // Contar instrucciones ejecutadas
            this.totalCycles += icycles; // Contar cycles totales
            
            // CRITICAL: Check breakpoint AFTER instruction execution (PC may have changed)
            var newPC = e6809.reg_pc;
            
            // TEMP DEBUG: Log when passing through target addresses (DISABLED - too verbose)
            /*
            if (newPC === 0x04DB || newPC === 0x4DB) {
                console.log('[JSVecx Debug] 🔍 Passing through PC: 0x' + newPC.toString(16).toUpperCase() + 
                           ', debugState=' + this.debugState + 
                           ', hasBreakpoint=' + this.breakpoints.has(newPC) +
                           ', stepMode=' + this.stepMode +
                           ', breakpoints=' + Array.from(this.breakpoints).map(b => '0x' + b.toString(16)).join(','));
            }
            */
            
            // CRITICAL: Check breakpoints ALWAYS (never disable them)
            if (this.debugState === 'running' && this.breakpoints.has(newPC)) {
                console.log('[JSVecx Debug] 🔴 Breakpoint hit at PC: 0x' + newPC.toString(16).toUpperCase());
                this.pauseDebugger('breakpoint', newPC);
                return; // Stop execution immediately
            }
            
            // CRITICAL: Check step target AFTER instruction execution (PC may have changed)
            if (this.stepMode === 'over' && newPC === this.stepTargetAddress) {
                console.log('[JSVecx Debug] ✅ Step Over reached target: 0x' + newPC.toString(16).toUpperCase());
                this.pauseDebugger('step', newPC);
                this.stepMode = null;
                this.stepTargetAddress = null;
                return;
            }
            
            // Step Into AFTER instruction: Pause now that we've executed the JSR
            if (this.stepMode === 'into') {
                console.log('[JSVecx Debug] ✅ Step Into reached target: 0x' + newPC.toString(16).toUpperCase());
                this.pauseDebugger('step', newPC);
                this.stepMode = null;
                this.isNativeCallStepInto = false;
                return;
            }
            
            // Debug: Track call stack depth para step out
            if (this.stepMode === 'out') {
                var opcode = this.read8(currentPC);
                if (opcode === 0xBD || opcode === 0x17 || opcode === 0x9D || opcode === 0xAD) { // JSR variants
                    this.callStackDepth++;
                } else if (opcode === 0x39) { // RTS
                    this.callStackDepth--;
                }
            }
            for( c = 0; c < icycles; c++ )
            {
                this.t2shift = 0;
                if( this.via_t1on )
                {
                    this.via_t1c = ( this.via_t1c > 0 ? this.via_t1c - 1 : 0xffff );
                    if( (this.via_t1c & 0xffff) == 0xffff )
                    {
                        if( this.via_acr & 0x40 )
                        {
                            this.via_ifr |= 0x40;
                            if( (this.via_ifr & 0x7f) & (this.via_ier & 0x7f) )
                            {
                                this.via_ifr |= 0x80;
                            }
                            else
                            {
                                this.via_ifr &= 0x7f;
                            }
                            this.via_t1pb7 = 0x80 - this.via_t1pb7;
                            this.via_t1c = (this.via_t1lh << 8) | this.via_t1ll;
                        }
                        else
                        {
                            if( this.via_t1int )
                            {
                                this.via_ifr |= 0x40;
                                if( (this.via_ifr & 0x7f) & (this.via_ier & 0x7f) )
                                {
                                    this.via_ifr |= 0x80;
                                }
                                else
                                {
                                    this.via_ifr &= 0x7f;
                                }
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
                        if( this.via_t2int )
                        {
                            this.via_ifr |= 0x20;
                            if( (this.via_ifr & 0x7f) & (this.via_ier & 0x7f) )
                            {
                                this.via_ifr |= 0x80;
                            }
                            else
                            {
                                this.via_ifr &= 0x7f;
                            }
                            this.via_t2int = 0;
                        }
                    }
                }
                this.via_src = ( this.via_src > 0 ? this.via_src - 1 : 0xff );
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
                            break;
                        case 0x04:
                            if( this.t2shift )
                            {
                                this.via_sr <<= 1;
                                this.via_srb++;
                            }
                            break;
                        case 0x08:
                            this.via_sr <<= 1;
                            this.via_srb++;
                            break;
                        case 0x0c:
                            break;
                        case 0x10:
                            if( this.t2shift )
                            {
                                this.via_cb2s = (this.via_sr >> 7) & 1;
                                this.via_sr <<= 1;
                                this.via_sr |= this.via_cb2s;
                            }
                            break;
                        case 0x14:
                            if( this.t2shift )
                            {
                                this.via_cb2s = (this.via_sr >> 7) & 1;
                                this.via_sr <<= 1;
                                this.via_sr |= this.via_cb2s;
                                this.via_srb++;
                            }
                            break;
                        case 0x18:
                            this.via_cb2s = (this.via_sr >> 7) & 1;
                            this.via_sr <<= 1;
                            this.via_sr |= this.via_cb2s;
                            this.via_srb++;
                            break;
                        case 0x1c:
                            break;
                    }
                    if( this.via_srb == 8 )
                    {
                        this.via_ifr |= 0x04;
                        if( (this.via_ifr & 0x7f) & (this.via_ier & 0x7f) )
                        {
                            this.via_ifr |= 0x80;
                        }
                        else
                        {
                            this.via_ifr &= 0x7f;
                        }
                    }
                }
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
                    if( sig_blank == 0 )
                    {
                        this.alg_vectoring = 0;
                        this.alg_addline(this.alg_vector_x0, this.alg_vector_y0,
                            this.alg_vector_x1, this.alg_vector_y1,
                            this.alg_vector_color);
                    }
                    else if( sig_dx != this.alg_vector_dx ||
                             sig_dy != this.alg_vector_dy ||
                             ( this.alg_zsh & 0xff ) != this.alg_vector_color )
                    {
                        this.alg_addline(this.alg_vector_x0, this.alg_vector_y0,
                            this.alg_vector_x1, this.alg_vector_y1,
                            this.alg_vector_color);
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
                    this.alg_vector_x1 = this.alg_curr_x;
                    this.alg_vector_y1 = this.alg_curr_y;
                }
                if( (this.via_pcr & 0x0e) == 0x0a )
                {
                    this.via_ca2 = 1;
                }
                if( (this.via_pcr & 0xe0) == 0xa0 )
                {
                    this.via_cb2h = 1;
                }
            }
            cycles -= icycles;
            this.fcycles -= icycles;
            if( this.fcycles < 0 )
            {
                this.fcycles += fcycles_add;
                osint.osint_render();
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
                $("#status").text( "FPS: " +
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
            vecx.vecx_emu.call( vecx, cycles, 0 );
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
            // CRITICAL: Activate debug mode if breakpoints exist
            if (this.breakpoints.size > 0) {
                this.debugState = 'running';
                console.log('[JSVecx] ✓ Debug mode activated (breakpoints detected)');
                
                // Notify debug store to sync state
                if (typeof window !== 'undefined') {
                    window.postMessage({ 
                        type: 'debug-state-changed',
                        state: 'running'
                    }, '*');
                }
            }
            this.e8910.start();
            this.vecx_emuloop();
        }
    }
    this.main = function()
    {
        this.osint.init( this );
        this.e6809.init( this );
        $("#status").text("Loaded.");
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
            case 37:
            case 76:
                this.leftHeld = true;
                break;
            case 38:
            case 80:
                this.upHeld = true;
                break;
            case 39:
            case 222:
                this.rightHeld = true;
                break;
            case 40:
            case 59:
            case 186:
                this.downHeld = true;
                break;
            case 65:
                this.shadow_snd_regs14 &= (~0x01);
                break;
            case 83:
                this.shadow_snd_regs14 &= (~0x02);
                break;
            case 68:
                this.shadow_snd_regs14 &= (~0x04);
                break;
            case 70:
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
            case 37:
            case 76:
                this.leftHeld = false;
                break;
            case 38:
            case 80:
                this.upHeld = false;
                break;
            case 39:
            case 222:
                this.rightHeld = false;
                break;
            case 40:
            case 59:
            case 186:
                this.downHeld = false;
                break;
            case 65:
                this.shadow_snd_regs14 |= 0x01;
                break;
            case 83:
                this.shadow_snd_regs14 |= 0x02;
                break;
            case 68:
                this.shadow_snd_regs14 |= 0x04;
                break;
            case 70:
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
    
    // === EXTENSIONES PARA OUTPUT PANEL ===
    // Añadido para compatibilidad con OutputPanel.tsx
    this.totalCycles = 0;
    this.instructionCount = 0;

    // Capture reference for closures (avoids this-binding issues)
    var self = this;

    // Wrapper para métricas del emulador
    this.getMetrics = function() {
        return {
            totalCycles: self.totalCycles,
            instructionCount: self.instructionCount,
            frameCount: self.count || 0,
            running: self.running,
            vectorCount: self.vector_erse_cnt || 0
        };
    }
    
    // Wrapper para acceso a registros CPU
    this.getRegisters = function() {
        if (!self.e6809) {
            return {
                PC: 0, A: 0, B: 0, X: 0, Y: 0, U: 0, S: 0, DP: 0, CC: 0
            };
        }

        return {
            PC: self.e6809.reg_pc || 0,
            A: self.e6809.reg_a || 0,
            B: self.e6809.reg_b || 0,
            X: (self.e6809.reg_x && self.e6809.reg_x.value) || 0,
            Y: (self.e6809.reg_y && self.e6809.reg_y.value) || 0,
            U: (self.e6809.reg_u && self.e6809.reg_u.value) || 0,
            S: (self.e6809.reg_s && self.e6809.reg_s.value) || 0,
            DP: self.e6809.reg_dp || 0,
            CC: self.e6809.reg_cc || 0,
            BANK: self.currentBank || 0
        };
    }
    
    // === DEBUG SYSTEM - Control Methods ===
    
    // Pausar el debugger y notificar al IDE
    this.pauseDebugger = function(mode, pc) {
        this.debugState = 'paused';
        this.running = false; // CRITICAL: Stop the emulation loop
        
        var registers = this.getRegisters();
        var callStack = this.buildCallStack(); // TODO: Implementar call stack real
        
        // Enviar evento al IDE vía postMessage
        window.postMessage({
            type: 'debugger-paused',
            pc: '0x' + pc.toString(16).toUpperCase().padStart(4, '0'),
            mode: mode, // 'breakpoint' | 'step'
            registers: registers,
            callStack: callStack,
            cycles: this.totalCycles
        }, '*');
        
        console.log('[JSVecx Debug] Paused at PC=' + pc.toString(16) + ', mode=' + mode);
    }
    
    // Construir call stack (placeholder por ahora)
    this.buildCallStack = function() {
        // TODO: Implementar tracking real de JSR/RTS
        return [{
            function: 'MAIN',
            line: 0,
            address: '0x' + this.e6809.reg_pc.toString(16).toUpperCase().padStart(4, '0'),
            type: 'vpy'
        }];
    }
    
    // Añadir breakpoint
    this.addBreakpoint = function(address) {
        if (typeof address === 'string') {
            address = parseInt(address, 16);
        }
        this.breakpoints.add(address);
        // CRITICAL: Activate debug mode when adding breakpoint
        // This ensures breakpoint checks happen in vecx_emu loop
        if (this.running && this.debugState !== 'paused') {
            this.debugState = 'running';
            console.log('[JSVecx Debug] Debug mode activated (breakpoint added while running)');
        }
        console.log('[JSVecx Debug] Breakpoint added at 0x' + address.toString(16));
    }
    
    // Eliminar breakpoint
    this.removeBreakpoint = function(address) {
        if (typeof address === 'string') {
            address = parseInt(address, 16);
        }
        this.breakpoints.delete(address);
        console.log('[JSVecx Debug] Breakpoint removed from 0x' + address.toString(16));
    }
    
    // Limpiar todos los breakpoints
    this.clearBreakpoints = function() {
        this.breakpoints.clear();
        console.log('[JSVecx Debug] All breakpoints cleared');
    }
    
    // Continuar ejecución (F5)
    this.debugContinue = function() {
        if (this.debugState === 'paused') {
            this.debugState = 'running';
            this.stepMode = null; // CRITICAL: Clear step mode to re-enable breakpoints
            this.stepTargetAddress = null; // Clear step target
            // DON'T set running=true here - vecx_emuloop() checks this and returns early if already true
            // Let vecx_emuloop() set running=true itself (line 983)
            this.skipNextBreakpoint = true; // Skip breakpoint at current position
            console.log('[JSVecx Debug] Continuing execution (stepMode cleared, skipNextBreakpoint=true, running will be set by vecx_emuloop)');
            // Continue the emulation loop
            this.vecx_emuloop();
        }
    }
    
    // Alias for compatibility with EmulatorPanel
    this.resumeFromBreakpoint = function() {
        console.log('[JSVecx Debug] resumeFromBreakpoint() called - delegating to debugContinue()');
        this.debugContinue();
    }
    
    // Check if currently paused by a breakpoint
    this.isPausedByBreakpoint = function() {
        return this.debugState === 'paused' && !this.running;
    }
    
    // Pausar ejecución manualmente
    this.debugPause = function() {
        if (this.debugState === 'running') {
            this.pauseDebugger('manual', this.e6809.reg_pc);
        }
    }
    
    // Detener ejecución (Stop button)
    this.debugStop = function() {
        this.debugState = 'stopped';
        this.running = false;
        this.stepMode = null;
        this.stepTargetAddress = null;
        this.callStackDepth = 0;
        console.log('[JSVecx Debug] Execution stopped');
    }
    
    // Step Over (F10) - ejecutar instrucción por instrucción hasta la siguiente línea
    this.debugStepOver = function(targetAddress) {
        if (typeof targetAddress === 'string') {
            targetAddress = parseInt(targetAddress, 16);
        }
        
        this.stepMode = 'over';
        this.stepTargetAddress = targetAddress;
        var initialCallDepth = 0; // Track JSR/RTS to detect when we exit current function
        var initialPC = this.e6809.reg_pc;
        // CRITICAL: Stay in 'paused' state, execute instruction-by-instruction
        // Do NOT set debugState='running' - this would disable breakpoint checking
        
        console.log('[JSVecx Debug] Step Over to 0x' + targetAddress.toString(16) + ' (instruction-by-instruction)');
        
        // Execute instructions one at a time until we reach target
        var vecx = this;
        var firstStep = true; // Skip breakpoint check on first instruction (we're already stopped there)
        var stepCount = 0; // Debug counter
        var maxSteps = 1000; // Safety limit to prevent infinite loops
        
        var stepLoop = function() {
            if (vecx.stepMode !== 'over') return; // Stopped or target reached
            
            stepCount++;
            if (stepCount > maxSteps) {
                console.error('[JSVecx Debug] ❌ Step Over exceeded max steps (' + maxSteps + '), aborting at PC=0x' + vecx.e6809.reg_pc.toString(16));
                vecx.pauseDebugger('step', vecx.e6809.reg_pc);
                vecx.stepMode = null;
                vecx.stepTargetAddress = null;
                return;
            }
            
            // HEURISTIC: If we've stepped many times without reaching target, convert to Continue
            // This handles cases where target is unreachable (e.g., inside main() which already finished)
            // Note: Removed PC >= 0xE000 check because BIOS code can be in low addresses (0x312, 0x315, etc.)
            if (stepCount > 200) {
                console.log('[JSVecx Debug] ⚠️ Step Over taking too long (' + stepCount + ' steps), converting to Continue');
                console.log('[JSVecx Debug]    Target 0x' + vecx.stepTargetAddress.toString(16) + ' unreachable or inside finished function');
                console.log('[JSVecx Debug]    Will run freely until next breakpoint');
                vecx.stepMode = null;
                vecx.stepTargetAddress = null;
                vecx.debugState = 'running';
                if (!vecx.running) {
                    vecx.vecx_emuloop();
                }
                return;
            }
            
            var currentPC = vecx.e6809.reg_pc;
            
            // Check if we've reached the target BEFORE executing
            if (currentPC === vecx.stepTargetAddress) {
                console.log('[JSVecx Debug] ✅ Step Over reached target: 0x' + currentPC.toString(16).toUpperCase() + ' after ' + stepCount + ' steps');
                vecx.pauseDebugger('step', currentPC);
                vecx.stepMode = null;
                vecx.stepTargetAddress = null;
                return;
            }
            
            // CRITICAL: Don't check breakpoint at starting position (we're already paused there)
            // Only check breakpoints AFTER we've moved from the initial position
            if (!firstStep && vecx.breakpoints.has(currentPC)) {
                console.log('[JSVecx Debug] 🔴 Breakpoint hit during Step Over at PC: 0x' + currentPC.toString(16).toUpperCase());
                vecx.pauseDebugger('breakpoint', currentPC);
                vecx.stepMode = null;
                vecx.stepTargetAddress = null;
                return;
            }
            
            // Track JSR/RTS to detect when we've exited the function
            var opcode = vecx.read8(currentPC);
            if (opcode === 0xBD || opcode === 0x17 || opcode === 0x9D || opcode === 0xAD) { // JSR variants
                initialCallDepth++;
            } else if (opcode === 0x39) { // RTS
                initialCallDepth--;
            }
            
            // Debug logging every 10 steps
            if (stepCount % 10 === 0 || stepCount <= 5) {
                console.log('[JSVecx Debug] Step ' + stepCount + ': PC=0x' + currentPC.toString(16) + ', target=0x' + vecx.stepTargetAddress.toString(16) + ', depth=' + initialCallDepth);
            }
            
            // Execute ONE instruction
            var icycles = vecx.e6809.e6809_sstep(vecx.via_ifr & 0x80, 0);
            vecx.instructionCount++;
            vecx.totalCycles += icycles;
            
            // CRITICAL: Process VIA/hardware cycles manually (without executing more CPU)
            // This simulates VIA timers so WAIT_RECAL doesn't hang forever
            for (var c = 0; c < icycles; c++) {
                // VIA Timer 1 countdown
                if (vecx.via_t1on) {
                    vecx.via_t1c = (vecx.via_t1c > 0 ? vecx.via_t1c - 1 : 0xffff);
                    if ((vecx.via_t1c & 0xffff) == 0xffff) {
                        if (vecx.via_acr & 0x40) {
                            vecx.via_ifr |= 0x40;
                            vecx.via_t1pb7 = 0x80 - vecx.via_t1pb7;
                            vecx.via_t1c = (vecx.via_t1lh << 8) | vecx.via_t1ll;
                        }
                    }
                }
            }
            
            firstStep = false; // After first instruction, enable breakpoint checking
            
            var newPC = vecx.e6809.reg_pc;
            
            // CRITICAL: Check if we exited the function AFTER executing RTS
            // newPC is now back in user code (< 0xE000) and we've returned from initial function
            if (initialCallDepth < 0 && newPC < 0xE000) {
                console.log('[JSVecx Debug] ✅ Step Over exited function, returned to PC: 0x' + newPC.toString(16).toUpperCase() + ' after ' + stepCount + ' steps');
                vecx.pauseDebugger('step', newPC);
                vecx.stepMode = null;
                vecx.stepTargetAddress = null;
                return;
            }
            
            // Check if we've reached the target AFTER executing
            if (newPC === vecx.stepTargetAddress) {
                console.log('[JSVecx Debug] ✅ Step Over reached target: 0x' + newPC.toString(16).toUpperCase() + ' after ' + stepCount + ' steps');
                vecx.pauseDebugger('step', newPC);
                vecx.stepMode = null;
                vecx.stepTargetAddress = null;
                return;
            }
            
            // Check for breakpoints at new PC (always check after execution)
            if (vecx.breakpoints.has(newPC)) {
                console.log('[JSVecx Debug] 🔴 Breakpoint hit during Step Over at PC: 0x' + newPC.toString(16).toUpperCase());
                vecx.pauseDebugger('breakpoint', newPC);
                vecx.stepMode = null;
                vecx.stepTargetAddress = null;
                return;
            }
            
            // Continue stepping (schedule next instruction)
            setTimeout(stepLoop, 0);
        };
        
        // Start stepping
        stepLoop();
    }
    
    // Step Into (F11) - entrar en funciones
    this.debugStepInto = function(isNativeCall) {
        this.stepMode = 'into';
        this.debugState = 'running';
        this.running = true; // CRITICAL: Resume emulation for stepping
        this.skipNextBreakpoint = true; // Skip breakpoint at current position
        this.isNativeCallStepInto = isNativeCall;
        
        console.log('[JSVecx Debug] Step Into (native=' + isNativeCall + ', running=true, skipNextBreakpoint=true)');
        
        // If native call, we need to step TWICE:
        // 1st step: Execute JSR instruction (jumps to native)
        // 2nd step: Pause at first instruction of native function
        if (isNativeCall) {
            console.log('[JSVecx Debug] Native call detected - will step through JSR');
        }
        
        // CRITICAL FIX: Call vecx_emu directly to execute one instruction
        // Don't use vecx_emuloop() because it returns if this.running is true
        var cycles_per_instruction = 10; // Average M6809 instruction cycles
        this.vecx_emu(cycles_per_instruction, 0);
    }
    
    // Step Out (Shift+F11) - salir de función actual
    this.debugStepOut = function() {
        this.stepMode = 'out';
        this.callStackDepth = 0; // Reset depth counter
        this.debugState = 'running';
        
        console.log('[JSVecx Debug] Step Out');
        
        // CRITICAL FIX: Call vecx_emu directly to execute instructions
        // Execute enough cycles to potentially reach RTS (100 instructions max)
        var max_cycles = 1000; // ~100 instructions worth of cycles
        this.vecx_emu(max_cycles, 0);
    }
    
    // Setup de listeners para postMessage desde el IDE
    this.setupDebugListeners = function() {
        var vecx = this;
        
        window.addEventListener('message', function(event) {
            // Validar origen si es necesario
            // if (event.origin !== 'expected-origin') return;
            
            var msg = event.data;
            if (!msg || !msg.type) return;
            
            // console.log('[JSVecx Debug] Received message:', msg.type);
            
            switch (msg.type) {
                case 'debug-continue':
                    vecx.debugContinue();
                    break;
                    
                case 'debug-pause':
                    vecx.debugPause();
                    break;
                    
                case 'debug-stop':
                    vecx.debugStop();
                    break;
                    
                case 'debug-step-over':
                    if (msg.targetAddress) {
                        vecx.debugStepOver(msg.targetAddress);
                    }
                    break;
                    
                case 'debug-step-into':
                    vecx.debugStepInto(msg.isNativeCall || false);
                    break;
                    
                case 'debug-step-out':
                    vecx.debugStepOut();
                    break;
                    
                case 'debug-add-breakpoint':
                    if (msg.address) {
                        vecx.addBreakpoint(msg.address);
                    }
                    break;
                    
                case 'debug-remove-breakpoint':
                    if (msg.address) {
                        vecx.removeBreakpoint(msg.address);
                    }
                    break;
                    
                case 'debug-clear-breakpoints':
                    vecx.clearBreakpoints();
                    break;
                    
                case 'debugger-paused':
                    // Internal message sent by JSVecx itself when paused - handled elsewhere
                    break;
                    
                case 'debug-state-changed':
                    // Internal message for EmulatorPanel → debugStore sync - no action needed here
                    break;
                    
                default:
                    console.warn('[JSVecx Debug] Unknown message type:', msg.type);
            }
        });
        
        console.log('[JSVecx Debug] Listeners setup complete');
    }
    
    // Auto-setup de listeners al crear el emulador
    this.setupDebugListeners();
}
