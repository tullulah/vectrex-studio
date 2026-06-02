# KLONDIKE SOLITAIRE for Vectrex
# Card encoding: value = rank*4 + suit
#   rank: 0=Ace, 1=2 .. 12=King
#   suit: 0=Clubs, 1=Diamonds, 2=Hearts, 3=Spades
# card_rank(c) = c / 4
# card_suit(c) = c - (c/4)*4

META TITLE = "SOLITAIRE"

# ── Card dimensions ────────────────────────────────────────────────────────────
const CARD_W  = 26
const CARD_H  = 32
const COL_DY  = 14
const HALF_W  = 13

# ── Screen positions ───────────────────────────────────────────────────────────
const TOP_Y   = 85
const TAB_Y   = 30
const STK_X   = -102
const WST_X   = -68
const F0_X    = 0
const F1_X    = 34
const F2_X    = 68
const F3_X    = 102
const TAB_X0  = -102
const TAB_X1  = -68
const TAB_X2  = -34
const TAB_X3  = 0
const TAB_X4  = 34
const TAB_X5  = 68
const TAB_X6  = 102

# ── Intensities ────────────────────────────────────────────────────────────────
const INT_CARD    = 70
const INT_CURSOR  = 127
const INT_FACEDN  = 40
const INT_EMPTY   = 25
const INT_HELD    = 100

# ── Game states ────────────────────────────────────────────────────────────────
const STATE_PLAY = 0
const STATE_WIN  = 1

# ── Deck ──────────────────────────────────────────────────────────────────────
deck = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51]

# ── Tableau: flat array, col*20 + row ─────────────────────────────────────────
tab = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
tab_sz  = [0, 0, 0, 0, 0, 0, 0]
tab_hid = [0, 0, 0, 0, 0, 0, 0]

# ── Foundation ─────────────────────────────────────────────────────────────────
found_cnt = [0, 0, 0, 0]

# ── Stock and waste ────────────────────────────────────────────────────────────
stock = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
stk_sz = 0
waste  = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
wst_sz = 0

# ── Cursor & selection ─────────────────────────────────────────────────────────
cursor   = 0
sel_card = -1
sel_src  = -1

# ── Game state ─────────────────────────────────────────────────────────────────
game_state = STATE_PLAY
win_blink  = 0

# ── Button edge detection ──────────────────────────────────────────────────────
prev_btn1 = 0
prev_btn2 = 0
btn1_fire = 0
btn2_fire = 0
prev_jx   = 0   # previous joystick X direction: -1, 0, 1

# ── Scratch globals (used by helper functions as "out" params) ─────────────────
g_result  = 0    # return value from can_move_to_tab / can_move_to_found
g_col_x   = 0    # return value from get_col_x
g_card    = 0    # scratch card value
g_rank    = 0    # scratch rank
g_suit    = 0    # scratch suit
g_sz      = 0    # scratch size
g_hd      = 0    # scratch hidden count
g_idx     = 0    # scratch index
g_cy      = 0    # scratch Y coordinate
g_tidx    = 0    # scratch tableau index
g_top     = 0    # scratch top card
g_tr      = 0    # scratch top rank
g_tc      = 0    # scratch top suit
g_top_red = 0    # scratch top color
g_card_red= 0    # scratch card color
g_placed  = 0    # scratch placed flag
deal_idx  = 0    # used in deal()
g_row     = 0    # loop counter
g_c       = 0    # loop counter
g_cx      = 0    # loop X coord
g_fc      = 0    # scratch found count
g_wcard   = 0    # scratch waste card
g_fx      = 0    # scratch foundation X

# ═══════════════════════════════════════════════════════════════════════════════
def main():
    game_state = STATE_PLAY
    shuffle()
    deal()

# ═══════════════════════════════════════════════════════════════════════════════
def loop():
    g_card = J1_BUTTON_1()
    g_rank = J1_BUTTON_2()
    btn1_fire = 0
    btn2_fire = 0
    if g_card == 1 and prev_btn1 == 0:
        btn1_fire = 1
    if g_rank == 1 and prev_btn2 == 0:
        btn2_fire = 1
    prev_btn1 = g_card
    prev_btn2 = g_rank

    if game_state == STATE_PLAY:
        update_input()
        draw_table()
        check_win()
    else:
        draw_win_screen()

# ═══════════════════════════════════════════════════════════════════════════════
# SHUFFLE (Fisher-Yates)
# ═══════════════════════════════════════════════════════════════════════════════
def shuffle():
    g_c = 51
    while g_c > 0:
        g_idx = rand_range(0, g_c)
        g_card = deck[g_c]
        deck[g_c] = deck[g_idx]
        deck[g_idx] = g_card
        g_c = g_c - 1

# ═══════════════════════════════════════════════════════════════════════════════
# DEAL
# ═══════════════════════════════════════════════════════════════════════════════
def deal():
    tab_sz[0]  = 0
    tab_sz[1]  = 0
    tab_sz[2]  = 0
    tab_sz[3]  = 0
    tab_sz[4]  = 0
    tab_sz[5]  = 0
    tab_sz[6]  = 0
    tab_hid[0] = 0
    tab_hid[1] = 0
    tab_hid[2] = 0
    tab_hid[3] = 0
    tab_hid[4] = 0
    tab_hid[5] = 0
    tab_hid[6] = 0
    found_cnt[0] = 0
    found_cnt[1] = 0
    found_cnt[2] = 0
    found_cnt[3] = 0
    stk_sz = 0
    wst_sz = 0
    sel_card = -1
    sel_src  = -1
    cursor   = 0

    deal_idx = 0
    g_c = 0
    while g_c < 7:
        g_row = 0
        while g_row <= g_c:
            g_tidx = g_c * 20 + g_row
            tab[g_tidx] = deck[deal_idx]
            deal_idx = deal_idx + 1
            g_row = g_row + 1
        tab_sz[g_c]  = g_c + 1
        tab_hid[g_c] = g_c
        g_c = g_c + 1

    g_row = 0
    while deal_idx < 52:
        stock[g_row] = deck[deal_idx]
        deal_idx = deal_idx + 1
        g_row = g_row + 1
    stk_sz = g_row

# ═══════════════════════════════════════════════════════════════════════════════
# INPUT
# ═══════════════════════════════════════════════════════════════════════════════
def update_input():
    g_idx = J1_X()
    g_row = 0
    if g_idx > 40:
        g_row = 1
    elif g_idx < -40:
        g_row = -1
    if g_row == 1 and prev_jx == 0:
        cursor = cursor + 1
        if cursor > 12:
            cursor = 0
    elif g_row == -1 and prev_jx == 0:
        cursor = cursor - 1
        if cursor < 0:
            cursor = 12
    prev_jx = g_row

    if btn2_fire == 1:
        do_deal_stock()

    if btn1_fire == 1:
        if sel_card == -1:
            do_pick_up()
        else:
            do_place()

def do_deal_stock():
    if stk_sz > 0:
        stk_sz = stk_sz - 1
        waste[wst_sz] = stock[stk_sz]
        wst_sz = wst_sz + 1
    else:
        g_row = 0
        while g_row < wst_sz:
            stock[g_row] = waste[g_row]
            g_row = g_row + 1
        stk_sz = wst_sz
        wst_sz = 0

def do_pick_up():
    if cursor <= 6:
        g_c  = cursor
        g_sz = tab_sz[g_c]
        g_hd = tab_hid[g_c]
        if g_sz > 0 and g_sz > g_hd:
            g_tidx   = g_c * 20 + g_sz - 1
            sel_card = tab[g_tidx]
            sel_src  = cursor
            tab_sz[g_c] = g_sz - 1
            if tab_sz[g_c] > 0 and tab_sz[g_c] <= tab_hid[g_c]:
                tab_hid[g_c] = tab_hid[g_c] - 1
    elif cursor == 8:
        if wst_sz > 0:
            sel_card = waste[wst_sz - 1]
            sel_src  = 8
            wst_sz = wst_sz - 1

def do_place():
    g_placed = 0
    if cursor <= 6:
        can_move_to_tab(sel_card, cursor)
        if g_result == 1:
            g_tidx = cursor * 20 + tab_sz[cursor]
            tab[g_tidx] = sel_card
            tab_sz[cursor] = tab_sz[cursor] + 1
            g_placed = 1
    elif cursor >= 9 and cursor <= 12:
        g_suit = cursor - 9
        can_move_to_found(sel_card, g_suit)
        if g_result == 1:
            found_cnt[g_suit] = found_cnt[g_suit] + 1
            g_placed = 1

    if g_placed == 1:
        sel_card = -1
        sel_src  = -1
    else:
        return_card_to_src()

def return_card_to_src():
    if sel_src >= 0 and sel_src <= 6:
        g_c = sel_src
        if tab_sz[g_c] > 0 and tab_sz[g_c] == tab_hid[g_c]:
            tab_hid[g_c] = tab_hid[g_c] + 1
        g_tidx = g_c * 20 + tab_sz[g_c]
        tab[g_tidx] = sel_card
        tab_sz[g_c] = tab_sz[g_c] + 1
    elif sel_src == 8:
        waste[wst_sz] = sel_card
        wst_sz = wst_sz + 1
    sel_card = -1
    sel_src  = -1

# ═══════════════════════════════════════════════════════════════════════════════
# MOVE VALIDATION  (result written to g_result: 1=valid, 0=invalid)
# ═══════════════════════════════════════════════════════════════════════════════
def can_move_to_tab(card, col):
    g_sz = tab_sz[col]
    g_rank = card / 4
    if g_sz == 0:
        if g_rank == 12:
            g_result = 1
        else:
            g_result = 0
        return
    g_tidx   = col * 20 + g_sz - 1
    g_top    = tab[g_tidx]
    g_tr     = g_top / 4
    g_tc     = g_top - g_tr * 4
    g_suit   = card - g_rank * 4
    g_top_red  = 0
    if g_tc == 1 or g_tc == 2:
        g_top_red = 1
    g_card_red = 0
    if g_suit == 1 or g_suit == 2:
        g_card_red = 1
    if g_top_red == g_card_red:
        g_result = 0
        return
    if g_rank == g_tr - 1:
        g_result = 1
    else:
        g_result = 0

def can_move_to_found(card, suit):
    g_rank = card / 4
    g_suit = card - g_rank * 4
    if g_suit != suit:
        g_result = 0
        return
    g_fc = found_cnt[suit]
    if g_fc == 0 and g_rank == 0:
        g_result = 1
        return
    if g_fc > 0 and g_rank == g_fc:
        g_result = 1
        return
    g_result = 0

# ═══════════════════════════════════════════════════════════════════════════════
# WIN CHECK
# ═══════════════════════════════════════════════════════════════════════════════
def check_win():
    if found_cnt[0] == 13 and found_cnt[1] == 13 and found_cnt[2] == 13 and found_cnt[3] == 13:
        game_state = STATE_WIN

# ═══════════════════════════════════════════════════════════════════════════════
# DRAWING
# ═══════════════════════════════════════════════════════════════════════════════
def draw_table():
    draw_stock()
    draw_waste()
    draw_foundations()
    draw_tableau()
    draw_held_label()
    draw_cursor()

def get_col_x(col):
    if col == 0:
        g_col_x = TAB_X0
    elif col == 1:
        g_col_x = TAB_X1
    elif col == 2:
        g_col_x = TAB_X2
    elif col == 3:
        g_col_x = TAB_X3
    elif col == 4:
        g_col_x = TAB_X4
    elif col == 5:
        g_col_x = TAB_X5
    else:
        g_col_x = TAB_X6

def draw_stock():
    if stk_sz > 0:
        DRAW_RECT(STK_X, TOP_Y, CARD_W, CARD_H, INT_FACEDN)
        SET_INTENSITY(INT_FACEDN)
        PRINT_TEXT(STK_X + 4, TOP_Y + 10, "##")
    else:
        DRAW_RECT(STK_X, TOP_Y, CARD_W, CARD_H, INT_EMPTY)
        SET_INTENSITY(INT_EMPTY)
        PRINT_TEXT(STK_X + 4, TOP_Y + 10, "ST")

def draw_waste():
    if wst_sz > 0:
        g_wcard = waste[wst_sz - 1]
        draw_card(WST_X, TOP_Y, g_wcard, INT_CARD)
    else:
        DRAW_RECT(WST_X, TOP_Y, CARD_W, CARD_H, INT_EMPTY)
        SET_INTENSITY(INT_EMPTY)
        PRINT_TEXT(WST_X + 4, TOP_Y + 10, "WS")

def draw_foundations():
    g_fx = F0_X
    draw_one_foundation(g_fx, 0)
    g_fx = F1_X
    draw_one_foundation(g_fx, 1)
    g_fx = F2_X
    draw_one_foundation(g_fx, 2)
    g_fx = F3_X
    draw_one_foundation(g_fx, 3)

def draw_one_foundation(fx, suit):
    g_fc = found_cnt[suit]
    if g_fc == 0:
        DRAW_RECT(fx, TOP_Y, CARD_W, CARD_H, INT_EMPTY)
        draw_suit_at(fx + HALF_W, TOP_Y + HALF_W, suit)
    else:
        g_rank = g_fc - 1
        g_card = g_rank * 4 + suit
        draw_card(fx, TOP_Y, g_card, INT_CARD)

def draw_tableau():
    g_c = 0
    while g_c < 7:
        get_col_x(g_c)
        g_cx = g_col_x
        g_sz = tab_sz[g_c]
        g_hd = tab_hid[g_c]
        if g_sz == 0:
            DRAW_RECT(g_cx, TAB_Y, CARD_W, CARD_H, INT_EMPTY)
        else:
            # Face-down placeholder: double-border "card back" pattern, no text
            if g_hd > 0:
                DRAW_RECT(g_cx, TAB_Y, CARD_W, CARD_H, INT_FACEDN)
                DRAW_RECT(g_cx + 3, TAB_Y + 4, CARD_W - 6, CARD_H - 8, INT_FACEDN)
            # Show up to 4 face-up cards stacked below
            g_row = g_hd
            g_idx = 0
            while g_row < g_sz and g_idx < 4:
                if g_hd > 0:
                    g_cy = TAB_Y - CARD_H - (g_row - g_hd) * COL_DY
                else:
                    g_cy = TAB_Y - (g_row - g_hd) * COL_DY
                g_tidx = g_c * 20 + g_row
                g_card = tab[g_tidx]
                draw_card(g_cx, g_cy, g_card, INT_CARD)
                g_row = g_row + 1
                g_idx = g_idx + 1
        g_c = g_c + 1

def draw_held_label():
    if sel_card != -1:
        SET_INTENSITY(INT_HELD)
        PRINT_TEXT(-60, -100, "HELD:")
        g_rank = sel_card / 4
        g_suit = sel_card - g_rank * 4
        draw_rank_at(-15, -100, g_rank)
        draw_suit_at(0, -100, g_suit)

def draw_cursor():
    g_cx = 0
    g_cy = TOP_Y
    if cursor == 7:
        g_cx = STK_X
    elif cursor == 8:
        g_cx = WST_X
    elif cursor == 9:
        g_cx = F0_X
    elif cursor == 10:
        g_cx = F1_X
    elif cursor == 11:
        g_cx = F2_X
    elif cursor == 12:
        g_cx = F3_X
    else:
        get_col_x(cursor)
        g_cx = g_col_x
        g_sz = tab_sz[cursor]
        g_hd = tab_hid[cursor]
        if g_sz == 0:
            g_cy = TAB_Y
        elif g_hd == 0:
            g_cy = TAB_Y - (g_sz - 1) * COL_DY
        else:
            g_cy = TAB_Y - CARD_H - (g_sz - g_hd - 1) * COL_DY
    SET_INTENSITY(INT_CURSOR)
    DRAW_RECT(g_cx - 1, g_cy + 1, CARD_W + 2, CARD_H + 2, INT_CURSOR)

# ── Card renderer ──────────────────────────────────────────────────────────────
def draw_card(x, y, card, intensity):
    DRAW_RECT(x, y, CARD_W, CARD_H, intensity)
    SET_INTENSITY(intensity)
    g_rank = card / 4
    g_suit = card - g_rank * 4
    draw_rank_at(x + 3, y + 26, g_rank)
    draw_suit_at(x + HALF_W, y + 12, g_suit)

def draw_small_count(x, y, n):
    if n == 1:
        PRINT_TEXT(x, y, "1")
    elif n == 2:
        PRINT_TEXT(x, y, "2")
    elif n == 3:
        PRINT_TEXT(x, y, "3")
    elif n == 4:
        PRINT_TEXT(x, y, "4")
    elif n == 5:
        PRINT_TEXT(x, y, "5")
    elif n == 6:
        PRINT_TEXT(x, y, "6")
    elif n == 7:
        PRINT_TEXT(x, y, "7")
    elif n == 8:
        PRINT_TEXT(x, y, "8")
    elif n == 9:
        PRINT_TEXT(x, y, "9")
    else:
        PRINT_TEXT(x, y, "+")

def draw_rank_at(x, y, r):
    if r == 0:
        PRINT_TEXT(x, y, "A")
    elif r == 1:
        PRINT_TEXT(x, y, "2")
    elif r == 2:
        PRINT_TEXT(x, y, "3")
    elif r == 3:
        PRINT_TEXT(x, y, "4")
    elif r == 4:
        PRINT_TEXT(x, y, "5")
    elif r == 5:
        PRINT_TEXT(x, y, "6")
    elif r == 6:
        PRINT_TEXT(x, y, "7")
    elif r == 7:
        PRINT_TEXT(x, y, "8")
    elif r == 8:
        PRINT_TEXT(x, y, "9")
    elif r == 9:
        PRINT_TEXT(x, y, "10")
    elif r == 10:
        PRINT_TEXT(x, y, "J")
    elif r == 11:
        PRINT_TEXT(x, y, "Q")
    else:
        PRINT_TEXT(x, y, "K")

def draw_suit_at(x, y, s):
    if s == 0:
        DRAW_VECTOR("suit_clubs", x, y)
    elif s == 1:
        DRAW_VECTOR("suit_diamonds", x, y)
    elif s == 2:
        DRAW_VECTOR("suit_hearts", x, y)
    else:
        DRAW_VECTOR("suit_spades", x, y)

# ── Win screen ─────────────────────────────────────────────────────────────────
def draw_win_screen():
    win_blink = win_blink + 1
    SET_INTENSITY(127)
    PRINT_TEXT(-42, 30, "YOU WIN!")
    SET_INTENSITY(80)
    PRINT_TEXT(-63, 0, "ALL SUITS COMPLETE")
    if win_blink < 30:
        SET_INTENSITY(60)
        PRINT_TEXT(-63, -30, "PRESS B1 TO PLAY")
    if win_blink >= 60:
        win_blink = 0
    if btn1_fire == 1:
        game_state = STATE_PLAY
        shuffle()
        deal()
