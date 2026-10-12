/* vpy3d_bridge.c — VPy's 3D builtins on the uvm2 target, over the SDK's vpy3d.
 *
 * Written into the build directory by vpy_cli and compiled, with the SDK's
 * vpy-c/vpy3d.c, into every .um2 whose program calls a 3D builtin
 * (vpy_codegen arm/three_d.rs lists them and emits the calls). The effects
 * (VPYX_FX: vpyfx.c), skeletons (VPYX_BONES: vpybone.c, vpyik.c) and soft
 * bodies (VPYX_SOFT: vpysoft.c) parts are compiled only when the program uses
 * them, with their SDK files.
 *
 * THE ABI WITH THE GENERATED CODE. Every vpyx_* function takes only integers and
 * pointers: the first four arguments in r0-r3, the rest in vpyx_args[] (the
 * generated code stores them there instead of on the stack). A transform is a
 * VPy `i32` array of 12, which has vpy_xf's layout (m[9], t[3]). Meshes and
 * scenes are slots, numbered by the compiler; VPYX_MESHES and VPYX_SCENES (set by
 * vpy_cli) size them.
 *
 * WHAT vpy3d NEEDS FROM libvpy, given here instead: vpy_draw_line_dev (a stroke in
 * deflection units = VPy units x127, straight to the UVM2 draw list, the way the
 * SDK's v_directDraw32 sends it on this cartridge), vpy_beam_rezero, the shed
 * priority (kept, unused: nothing sheds here), the Q14 sine and the font. libvpy
 * itself (vpy.c) cannot be linked into a VPy image: its builtins share names with
 * the VPy runtime, so vpy_cli copies its font out of it (vpy3d_font.inc).
 */
#include <stdint.h>
#include "vpy3d.h"
#include "vpy_trig_q14.h"
#ifdef VPYX_FX
#include "vpyfx.h"
#endif
#ifdef VPYX_BONES
#include "vpybone.h"
#endif
#ifdef VPYX_SOFT
#include "vpysoft.h"
#endif

#ifndef VPYX_MESHES
#define VPYX_MESHES 1
#endif
#ifndef VPYX_SCENES
#define VPYX_SCENES 1
#endif

/* Arguments 5 and up of a vpyx_* call. */
int32_t vpyx_args[12];

/* ---- what vpy3d calls in libvpy ---------------------------------------- */

void uvm2_draw_reset(void);
void uvm2_draw_intensity(int brightness);
void uvm2_draw_move_abs_q4(int x_q4, int y_q4);
void uvm2_draw_delta_q4(int dx_q4, int dy_q4);

/* Deflection units (VPy x127) to the draw list's 1/16 of a VPy unit, rounded
 * half away from zero: the SDK's VS_Q4. */
static int q4(int32_t v)
{
    return (int)(v < 0 ? ((int64_t)v * 16 - 63) / 127 : ((int64_t)v * 16 + 63) / 127);
}

static uint8_t s_zero_next, s_pri;

void vpy_draw_line_dev(int32_t x0, int32_t y0, int32_t x1, int32_t y1, int br)
{
    if (br <= 0) return;
    if (br > 127) br = 127;
    if (s_zero_next) { uvm2_draw_reset(); s_zero_next = 0; }
    const int ax = q4(x0), ay = q4(y0);
    uvm2_draw_intensity(br);
    uvm2_draw_move_abs_q4(ax, ay);
    uvm2_draw_delta_q4(q4(x1) - ax, q4(y1) - ay);
}

void vpy_beam_rezero(void) { s_zero_next = 1; }
void vpy_set_priority(int p) { s_pri = (uint8_t)(p < 0 ? 0 : (p > 255 ? 255 : p)); }
int vpy_get_priority(void) { return s_pri; }

int vpy_sin_q14(int a)
{
    a &= (VPY_Q14_TURN - 1);
    if (a < 1024) return VPY_SIN_Q14[a];
    if (a < 2048) return VPY_SIN_Q14[2048 - a];
    if (a < 3072) return -VPY_SIN_Q14[a - 2048];
    return -VPY_SIN_Q14[4096 - a];
}
int vpy_cos_q14(int a) { return vpy_sin_q14(a + 1024); }

/* the font: vpy_cli cuts libvpy's out of the SDK's vpy.c into vpy3d_font.inc
   (the glyph tables, font_glyph and vpy_font_next) */
#include "vpy3d_font.inc"
const signed char *vpy_font_glyph(int c) { return font_glyph((unsigned char)c); }

/* ---- transforms ----------------------------------------------------------- */

void vpyx_xf_identity(vpy_xf *d) { *d = vpy3d_identity(); }
void vpyx_xf_translate(vpy_xf *d, int32_t x, int32_t y, int32_t z) { *d = vpy3d_translate(x, y, z); }
void vpyx_xf_rot_x(vpy_xf *d, int a) { *d = vpy3d_rot_x(a); }
void vpyx_xf_rot_y(vpy_xf *d, int a) { *d = vpy3d_rot_y(a); }
void vpyx_xf_rot_z(vpy_xf *d, int a) { *d = vpy3d_rot_z(a); }
/* d = a * b (apply b, then a); d may be a or b. */
void vpyx_xf_mul(vpy_xf *d, const vpy_xf *a, const vpy_xf *b)
{
    const vpy_xf r = vpy3d_mul(a, b);
    *d = r;
}
/* out[0..2] = the point (x, y, z) moved by the transform. */
void vpyx_xf_point(int32_t *out, const vpy_xf *xf, int32_t x, int32_t y)
{
    const int32_t z = vpyx_args[0];
    for (int r = 0; r < 3; r++)
        out[r] = xf->t[r] + (int32_t)(((int64_t)xf->m[r * 3] * x + (int64_t)xf->m[r * 3 + 1] * y
                                       + (int64_t)xf->m[r * 3 + 2] * z) >> 14);
}

/* out[0..2] = the world point (x, y, z) in the transform's own frame (its inverse). */
void vpyx_world_to_model(int32_t *out, const vpy_xf *xf, int32_t x, int32_t y)
{
    vpy3d_world_to_model(xf, x, y, vpyx_args[0], &out[0], &out[1], &out[2]);
}

/* ---- the camera ----------------------------------------------------------- */

/* eye, target, and the world direction that ends up pointing up on screen
   (left out: 0, 0, 0 = +y) */
int vpyx_look_at(int32_t ex, int32_t ey, int32_t ez, int32_t tx)
{
    int32_t ux = vpyx_args[2], uy = vpyx_args[3], uz = vpyx_args[4];
    if (!ux && !uy && !uz) uy = 1;
    return vpy3d_look_at(ex, ey, ez, tx, vpyx_args[0], vpyx_args[1], ux, uy, uz);
}
void vpyx_set_camera(const vpy_xf *xf) { vpy3d_set_camera(xf); }
void vpyx_get_camera(vpy_xf *d) { *d = *vpy3d_camera(); }
void vpyx_set_focal(int32_t f) { vpy3d_set_focal(f); }
void vpyx_set_near(int32_t z) { vpy3d_set_near(z); }
/* One half for both axes, or x and y (y = 0: the same as x). */
void vpyx_set_clip(int32_t hx, int32_t hy) { vpy3d_set_clip_xy(hx, hy > 0 ? hy : hx); }
/* out[0..1] = where the world point (x, y, z) lands on screen, in deflection
 * units (VPy x127). 0 if it is behind the near plane (out untouched). */
int vpyx_project(int32_t *out, int32_t x, int32_t y, int32_t z)
{
    int32_t cam[3];
    vpy3d_to_camera(x, y, z, cam);
    return vpy3d_project(cam, &out[0], &out[1]);
}

/* the same for a point already in camera space */
int vpyx_project_cam(int32_t *out, int32_t x, int32_t y, int32_t z)
{
    const int32_t cam[3] = { x, y, z };
    return vpy3d_project(cam, &out[0], &out[1]);
}

/* the angle of (x, y) from +x towards +y, 4096 per turn (0..4095): an octant fold,
   then a binary search of the sine table for the angle whose tangent is the ratio */
int vpyx_atan2_q14(int32_t y, int32_t x)
{
    if (!x && !y) return 0;
    int64_t ax = x < 0 ? -(int64_t)x : x, ay = y < 0 ? -(int64_t)y : y;
    const int steep = ay > ax;
    const int64_t lo = steep ? ax : ay, hi = steep ? ay : ax;     /* lo / hi in 0..1 */
    int a0 = 0, a1 = 513;                                          /* 0..45 degrees, both ends */
    while (a1 - a0 > 1) {
        const int m = (a0 + a1) / 2;
        if ((int64_t)VPY_SIN_Q14[m] * hi <= (int64_t)VPY_SIN_Q14[1024 - m] * lo) a0 = m; else a1 = m;
    }
    int a = a0;                                                    /* within one step (0.09 degrees) */
    if (steep) a = 1024 - a;
    if (x < 0) a = 2048 - a;
    if (y < 0) a = -a;
    return a & 4095;
}

int vpyx_sin_q14(int a) { return vpy_sin_q14(a); }
int vpyx_cos_q14(int a) { return vpy_cos_q14(a); }

/* ---- meshes and scenes ---------------------------------------------------- */

static vpy_mesh s_mesh[VPYX_MESHES];
static vpy_scene s_scene[VPYX_SCENES];
static vpy3d_pool_mark_t s_mark;

int vpyx_load_mesh(int i, const unsigned char *data) { return vpy3d_load_mesh(&s_mesh[i], data); }
void vpyx_draw_mesh(int i, const vpy_xf *xf, int br) { vpy3d_draw_mesh(&s_mesh[i], xf, br); }
void vpyx_pool_mark(void) { s_mark = vpy3d_pool_mark(); }
int vpyx_pool_release(void) { return vpy3d_pool_release(s_mark); }

int vpyx_load_scene(int i, const unsigned char *data, const unsigned char *const *meshes)
{
    return vpy3d_load_scene(&s_scene[i], data, meshes);
}
/* The scene at position (x, y, z) — what its `follow` items move with — with
 * groups = the bit mask its `group` items test. */
void vpyx_draw_scene(int i, int32_t x, int32_t y, int32_t z)
{
    const int32_t pos[3] = { x, y, z };
    vpy3d_draw_scene(&s_scene[i], 0, pos, (uint32_t)vpyx_args[1], vpyx_args[0]);
}

/* ---- lines, occluders, fog -------------------------------------------------- */

void vpyx_line_world(int32_t ax, int32_t ay, int32_t az, int32_t bx)
{
    vpy3d_line_world(ax, ay, az, bx, vpyx_args[0], vpyx_args[1], vpyx_args[2]);
}
/* a line in camera space (x right, y up, z ahead): overlays such as a gunsight */
void vpyx_line_cam(int32_t ax, int32_t ay, int32_t az, int32_t bx)
{
    const int32_t a[3] = { ax, ay, az }, b[3] = { bx, vpyx_args[0], vpyx_args[1] };
    vpy3d_line_cam(a, b, vpyx_args[2]);
}
void vpyx_occl_reset(void) { vpy3d_occl_reset(); }
void vpyx_occl_line(int32_t ax, int32_t ay, int32_t az, int32_t bx)
{
    vpy3d_occl_line(ax, ay, az, bx, vpyx_args[0], vpyx_args[1], vpyx_args[2]);
}
int vpyx_occl_add_mesh(int i, const vpy_xf *xf) { return vpy3d_occl_add_mesh(&s_mesh[i], xf); }
/* corners: an i32 array of n points (x, y, z). */
int vpyx_occl_add(const int32_t *corners, int n) { return vpy3d_occl_add((const int32_t (*)[3])corners, n); }
int vpyx_fog(int br, int32_t x, int32_t y, int32_t z)
{
    return vpy3d_fog(br, x, y, z, vpyx_args[0], vpyx_args[1]);
}
void vpyx_set_scenery_fog(int32_t full_until, int32_t gone_at) { vpy3d_set_scenery_fog(full_until, gone_at); }

/* text in the world: s at (x, y, z) facing the camera, `height` world units tall;
   flags: 1 hidden by the occluders, 2 centred, 4 only seen from the front */
int vpyx_text_billboard(const char *s, int32_t x, int32_t y, int32_t z)
{
    return vpy3d_text_billboard(s, x, y, z, vpyx_args[0], vpyx_args[1], vpyx_args[2]);
}
/* label followed by n in decimal, in one of four buffers taken in turn (so a few can
   be alive at once, as arguments of one call) */
const char *vpyx_label_num(const char *label, int32_t n)
{
    static char buf[4][40];
    static int k;
    char *o = buf[k = (k + 1) & 3], t[12];
    int i = 0, j = 0;
    while (label && label[j] && j < 26) { o[j] = label[j]; j++; }
    if (n < 0) { o[j++] = '-'; n = -n; }
    if (n == 0) t[i++] = '0';
    while (n > 0) { t[i++] = (char)('0' + n % 10); n /= 10; }
    while (i) o[j++] = t[--i];
    o[j] = 0;
    return o;
}

/* a .vec (its libvpy image) placed by xf, its units scaled by `scale` */
int vpyx_draw_vec(const unsigned char *vec, const vpy_xf *xf, int32_t scale, int br)
{
    return vpy3d_draw_vec(vec, xf, scale, br, vpyx_args[0]);
}

/* s on the plane placed by xf (its x along the text, y up) */
int vpyx_text(const char *s, const vpy_xf *xf, int32_t height, int br)
{
    return vpy3d_text(s, xf, height, br, vpyx_args[0]);
}

/* the first face of mesh i placed by xf that the ray from o along d meets within
   max_dist: its index, or -1. out = { x, y, z, nx, ny, nz, dist }: the hit point,
   the face's normal (Q14, towards the ray), how far */
int vpyx_ray_mesh(int32_t *out, int i, const vpy_xf *xf, int32_t ox)
{
    vpy3d_hit h;
    const int face = vpy3d_ray_mesh(&s_mesh[i], xf, ox, vpyx_args[0], vpyx_args[1],
                                    vpyx_args[2], vpyx_args[3], vpyx_args[4], vpyx_args[5], &h);
    if (face >= 0) {
        out[0] = h.x; out[1] = h.y; out[2] = h.z;
        out[3] = h.nx; out[4] = h.ny; out[5] = h.nz; out[6] = h.dist;
    }
    return face;
}

/* damage marks: set k (0 .. VPYX_MARK_SETS - 1) belongs to one object */
#ifndef VPYX_MARK_SETS
#define VPYX_MARK_SETS 4
#endif
static vpy3d_marks s_marks[VPYX_MARK_SETS];
static vpy3d_marks *marks(int k) { return k >= 0 && k < VPYX_MARK_SETS ? &s_marks[k] : 0; }

void vpyx_marks_clear(int k) { if (marks(k)) vpy3d_marks_clear(marks(k)); }
/* a hit at (x, y, z), face normal (nx, ny, nz), on the object placed by xf */
void vpyx_marks_add(int k, const vpy_xf *xf, int32_t x, int32_t y)
{
    if (marks(k)) vpy3d_marks_add(marks(k), xf, x, y, vpyx_args[0], vpyx_args[1], vpyx_args[2], vpyx_args[3]);
}
/* style: 0 a scorch ring, 1 a crack; how many were drawn */
int vpyx_marks_draw(int k, const vpy_xf *xf, int32_t radius, int br)
{
    return marks(k) ? vpy3d_marks_draw(marks(k), xf, radius, br, vpyx_args[0]) : 0;
}

/* ---- effects (vpyfx) ---------------------------------------------------- */
#ifdef VPYX_FX
#define A(i) vpyx_args[i]
int vpyx_fx_spark(int32_t x, int32_t y, int32_t z, int32_t vx)
{
    return vpyfx_spark(x, y, z, vx, A(0), A(1), A(2), A(3));
}
int vpyx_fx_burst(int32_t x, int32_t y, int32_t z, int32_t vx)
{
    return vpyfx_burst(x, y, z, vx, A(0), A(1), A(2), A(3), A(4), A(5));
}
int vpyx_fx_stick(int32_t ax, int32_t ay, int32_t az, int32_t bx)
{
    return vpyfx_stick(ax, ay, az, bx, A(0), A(1), A(2), A(3), A(4), A(5), A(6), A(7));
}
int vpyx_fx_shatter(int i, const vpy_xf *xf, int32_t vx, int32_t vy)
{
    return vpyfx_shatter(&s_mesh[i], xf, vx, vy, A(0), A(1), A(2), A(3), A(4), A(5), A(6), A(7));
}
int vpyx_fx_disintegrate(int i, const vpy_xf *xf, int32_t cx, int32_t cy)
{
    return vpyfx_disintegrate(&s_mesh[i], xf, cx, cy, A(0), A(1), A(2), A(3), A(4), A(5), A(6));
}
int vpyx_fx_assemble(int i, const vpy_xf *xf, int per_edge, int32_t scatter)
{
    return vpyfx_assemble(&s_mesh[i], xf, per_edge, scatter, A(0), A(1), A(2));
}
int vpyx_fx_ring(int32_t cx, int32_t cy, int32_t cz, int32_t nx)
{
    return vpyfx_ring(cx, cy, cz, nx, A(0), A(1), A(2), A(3), A(4), A(5), A(6));
}
int vpyx_fx_line(int32_t ax, int32_t ay, int32_t az, int32_t bx)
{
    return vpyfx_line(ax, ay, az, bx, A(0), A(1), A(2), A(3));
}
#undef A
#endif

/* ---- skeletons (vpybone) ------------------------------------------------ */
#ifdef VPYX_BONES
#ifndef VPYX_SKELETONS
#define VPYX_SKELETONS 2
#endif
static vpyb_skeleton s_skel[VPYX_SKELETONS];
static vpyb_quat s_root[VPYX_SKELETONS];   /* the root rotation BONE_POSE uses */

static vpyb_skeleton *skel(int k) { return k >= 0 && k < VPYX_SKELETONS ? &s_skel[k] : 0; }

/* a * b: apply b, then a (the game's own qmul) */
static vpyb_quat qmul(vpyb_quat a, vpyb_quat b)
{
    vpyb_quat r;
    r.w = (a.w * b.w - a.x * b.x - a.y * b.y - a.z * b.z) >> 14;
    r.x = (a.w * b.x + a.x * b.w + a.y * b.z - a.z * b.y) >> 14;
    r.y = (a.w * b.y - a.x * b.z + a.y * b.w + a.z * b.x) >> 14;
    r.z = (a.w * b.z + a.x * b.y - a.y * b.x + a.z * b.w) >> 14;
    return r;
}

/* the rotation of bone b, or of the root for b = -1 */
static vpyb_quat *rot_of(int k, int b)
{
    vpyb_skeleton *s = skel(k);
    if (!s) return 0;
    if (b < 0) return &s_root[k];
    return b < s->n ? &s->rot[b] : 0;
}

void vpyx_bone_init(int k)
{
    vpyb_skeleton *s = skel(k);
    if (!s) return;
    vpyb_init(s);
    s_root[k] = vpyb_quat_identity();
}
/* returns the bone's index, -1 if refused; mesh -1 = none */
int vpyx_bone_add(int k, int parent, int32_t ox, int32_t oy)
{
    vpyb_skeleton *s = skel(k);
    const int mesh = vpyx_args[1];
    if (!s) return -1;
    return vpyb_add(s, parent, ox, oy, vpyx_args[0], mesh >= 0 ? &s_mesh[mesh] : 0);
}
/* bone (or root, -1) rotation = (ax, ay, az) by angle */
void vpyx_bone_rot(int k, int b, int32_t ax, int32_t ay)
{
    vpyb_quat *q = rot_of(k, b);
    if (q) *q = vpyb_quat_axis(ax, ay, vpyx_args[0], vpyx_args[1]);
}
/* bone (or root) rotation = rotation * (ax, ay, az) by angle */
void vpyx_bone_rot_mul(int k, int b, int32_t ax, int32_t ay)
{
    vpyb_quat *q = rot_of(k, b);
    if (q) *q = qmul(*q, vpyb_quat_axis(ax, ay, vpyx_args[0], vpyx_args[1]));
}
void vpyx_bone_pose(int k, int32_t x, int32_t y, int32_t z)
{
    vpyb_skeleton *s = skel(k);
    const int32_t pos[3] = { x, y, z };
    if (s) vpyb_pose(s, pos, s_root[k]);
}
void vpyx_bone_xf(vpy_xf *d, int k, int b)
{
    vpyb_skeleton *s = skel(k);
    if (s && b >= 0 && b < s->n) *d = vpyb_xf(s, b);
}
void vpyx_bone_pos(int32_t *out, int k, int b)
{
    vpyb_skeleton *s = skel(k);
    if (s && b >= 0 && b < s->n) { out[0] = s->pos[b][0]; out[1] = s->pos[b][1]; out[2] = s->pos[b][2]; }
}
/* what: 1 meshes (default), 2 lines, 3 both */
int vpyx_bone_draw(int k, int br, int what)
{
    vpyb_skeleton *s = skel(k);
    return s ? vpyb_draw(s, br, what ? what : VPYB_DRAW_MESH) : 0;
}
int vpyx_bone_ik(int k, int upper, int32_t tx, int32_t ty)
{
    vpyb_skeleton *s = skel(k);
    const int32_t target[3] = { tx, ty, vpyx_args[0] };
    const int32_t pole[3] = { vpyx_args[1], vpyx_args[2], vpyx_args[3] };
    return s ? vpyb_ik(s, upper, target, pole) : 0;
}
#endif

/* ---- soft bodies and cloth (vpysoft) ------------------------------------ */
#ifdef VPYX_SOFT
int vpyx_soft_cloth(int32_t x, int32_t y, int32_t z, int w)
{
    return vpysoft_cloth(x, y, z, w, vpyx_args[0], vpyx_args[1], vpyx_args[2]);
}
int vpyx_soft_blob(int32_t x, int32_t y, int32_t z, int n)
{
    return vpysoft_blob(x, y, z, n, vpyx_args[0], vpyx_args[1], vpyx_args[2]);
}
int vpyx_soft_mesh(int i, int32_t x, int32_t y, int32_t z)
{
    return vpysoft_mesh(&s_mesh[i], x, y, z, vpyx_args[0]);
}
void vpyx_soft_point(int32_t *out, int body, int i) { vpysoft_point(body, i, &out[0], &out[1], &out[2]); }
void vpyx_soft_pin(int body, int i, int32_t x, int32_t y) { vpysoft_pin(body, i, x, y, vpyx_args[0]); }
#endif
