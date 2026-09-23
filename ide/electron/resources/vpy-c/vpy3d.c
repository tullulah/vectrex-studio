/*
 * vpy3d.c — see vpy3d.h. Integer only, like the rest of libvpy.
 *
 * The three parts, in the order they run:
 *   BUILD (once)  vertices and faces in, normals + an edge table with
 *                 adjacency and straight-run links out.
 *   DRAW (frame)  transform the vertices, test every face against the camera,
 *                 decide each edge, merge straight runs, push strokes.
 *   The strokes go to libvpy's buffer, so 3D shares the frame, the priorities
 *   and the flush with the rest of the game.
 */
#include "vpy3d.h"

/* ── pools, shared by every mesh ─────────────────────────────────────────── */
typedef struct {
    uint16_t a, b;      /* its two vertices, mesh-local */
    int16_t  f0, f1;    /* the faces either side, mesh-local; f1 < 0 = boundary */
    int16_t  ca, cb;    /* edge continuing the straight run past a / past b */
    uint8_t  hard;      /* the faces meet sharply: keep it when one is visible */
} vpy3d_edge;

static int16_t     PV[VPY3D_POOL_V][3];
static int16_t     PN[VPY3D_POOL_F][3];     /* face normals, Q14 unit vectors */
static uint16_t    PFs[VPY3D_POOL_F];       /* where the face's indices start */
static uint8_t     PFn[VPY3D_POOL_F];       /* how many it has */
static uint16_t    PFV[VPY3D_POOL_FV];
static vpy3d_edge  PE[VPY3D_POOL_E];
static int nPV, nPF, nPFV, nPE;

static vpy_mesh   *B;                        /* the mesh being built */
static vpy3d_stats_t s_stats;

/* per-draw scratch */
static int32_t TC[VPY3D_MESH_MAXV][3];       /* vertices in camera space */
static uint8_t FV[VPY3D_MESH_MAXF];          /* 1 = face turned toward us */
static uint8_t ED[VPY3D_POOL_E];             /* 0 skip, 1 draw, 2 already drawn */
static uint8_t ES[VPY3D_POOL_E];             /* 1 = silhouette, 0 = interior */
/* the runs of one mesh, as vertex pairs, before they are put in an order */
static uint16_t RA[VPY3D_POOL_E], RB[VPY3D_POOL_E];
static uint8_t  RU[VPY3D_POOL_E];            /* already emitted */
static int      s_chain = 1;                 /* follow connectivity when emitting */
static int      s_wire;                      /* draw hidden edges too: see the header */

/* ── camera and lens ─────────────────────────────────────────────────────── */
static vpy_xf  s_cam;
static int     s_cam_set;
static int32_t s_focal = 28000;   /* deflection units per unit of x/z (~58 deg) */
static int32_t s_near  = 600;     /* world units */
static int32_t s_clip  = 15500;   /* half the visible square, deflection units */

/* ── small integer maths ─────────────────────────────────────────────────── */
static int64_t isqrt64(int64_t n)
{
    if (n <= 0) return 0;
    int64_t r = 0, bit = (int64_t)1 << 62;
    while (bit > n) bit >>= 2;
    while (bit) {
        if (n >= r + bit) { n -= r + bit; r = (r >> 1) + bit; }
        else              { r >>= 1; }
        bit >>= 2;
    }
    return r;
}

/* Scale (x,y,z) to a Q14 unit vector. 0 if it has no length to speak of. */
static int norm_q14(int64_t x, int64_t y, int64_t z, int32_t *out)
{
    int64_t len = isqrt64(x * x + y * y + z * z);
    if (len == 0) return 0;
    out[0] = (int32_t)((x * VPY3D_ONE) / len);
    out[1] = (int32_t)((y * VPY3D_ONE) / len);
    out[2] = (int32_t)((z * VPY3D_ONE) / len);
    return 1;
}

static void cross64(const int64_t *a, const int64_t *b, int64_t *o)
{
    o[0] = a[1] * b[2] - a[2] * b[1];
    o[1] = a[2] * b[0] - a[0] * b[2];
    o[2] = a[0] * b[1] - a[1] * b[0];
}

/* ── transforms ──────────────────────────────────────────────────────────── */
vpy_xf vpy3d_identity(void)
{
    vpy_xf r;
    r.m[0] = VPY3D_ONE; r.m[1] = 0;          r.m[2] = 0;
    r.m[3] = 0;         r.m[4] = VPY3D_ONE;  r.m[5] = 0;
    r.m[6] = 0;         r.m[7] = 0;          r.m[8] = VPY3D_ONE;
    r.t[0] = r.t[1] = r.t[2] = 0;
    return r;
}

vpy_xf vpy3d_mul(const vpy_xf *a, const vpy_xf *b)   /* a applied after b */
{
    vpy_xf r;
    for (int i = 0; i < 3; i++) {
        for (int j = 0; j < 3; j++) {
            int64_t s = 0;
            for (int k = 0; k < 3; k++)
                s += (int64_t)a->m[i * 3 + k] * b->m[k * 3 + j];
            r.m[i * 3 + j] = (int32_t)(s >> 14);
        }
        int64_t t = 0;
        for (int k = 0; k < 3; k++) t += (int64_t)a->m[i * 3 + k] * b->t[k];
        r.t[i] = (int32_t)(t >> 14) + a->t[i];
    }
    return r;
}

vpy_xf vpy3d_rot_x(int ang)
{
    int32_t c = vpy_cos_q14(ang), s = vpy_sin_q14(ang);
    vpy_xf r = vpy3d_identity();
    r.m[4] = c; r.m[5] = -s;
    r.m[7] = s; r.m[8] =  c;
    return r;
}
vpy_xf vpy3d_rot_y(int ang)
{
    int32_t c = vpy_cos_q14(ang), s = vpy_sin_q14(ang);
    vpy_xf r = vpy3d_identity();
    r.m[0] =  c; r.m[2] = s;
    r.m[6] = -s; r.m[8] = c;
    return r;
}
vpy_xf vpy3d_rot_z(int ang)
{
    int32_t c = vpy_cos_q14(ang), s = vpy_sin_q14(ang);
    vpy_xf r = vpy3d_identity();
    r.m[0] = c; r.m[1] = -s;
    r.m[3] = s; r.m[4] =  c;
    return r;
}
vpy_xf vpy3d_translate(int32_t x, int32_t y, int32_t z)
{
    vpy_xf r = vpy3d_identity();
    r.t[0] = x; r.t[1] = y; r.t[2] = z;
    return r;
}

/* ── the camera ──────────────────────────────────────────────────────────── */
void vpy3d_set_camera(const vpy_xf *c) { s_cam = *c; s_cam_set = 1; }
const vpy_xf *vpy3d_camera(void)
{
    if (!s_cam_set) { s_cam = vpy3d_identity(); s_cam_set = 1; }
    return &s_cam;
}
void vpy3d_eye(int32_t *out)
{
    const vpy_xf *c = vpy3d_camera();
    /* R is orthonormal, so its inverse is its transpose: eye = -R^T * t. */
    for (int i = 0; i < 3; i++) {
        int64_t s = (int64_t)c->m[0 * 3 + i] * c->t[0]
                  + (int64_t)c->m[1 * 3 + i] * c->t[1]
                  + (int64_t)c->m[2 * 3 + i] * c->t[2];
        out[i] = (int32_t)(-(s >> 14));
    }
}

void vpy3d_set_focal(int32_t f) { if (f > 0) s_focal = f; }
void vpy3d_set_near(int32_t n)  { if (n > 0) s_near  = n; }
void vpy3d_set_clip(int32_t h)  { if (h > 0) s_clip  = h; }

int vpy3d_look_at(int32_t ex, int32_t ey, int32_t ez,
                  int32_t tx, int32_t ty, int32_t tz,
                  int32_t ux, int32_t uy, int32_t uz)
{
    /* Camera basis: f forward (+z into the screen), r right (+x), u up (+y).
     * The rotation that takes world into camera space has those as its ROWS,
     * because it is the inverse of the rotation that would orient the camera —
     * and the inverse of an orthonormal matrix is its transpose. */
    int32_t f[3], r[3], u[3];
    int64_t fv[3] = { (int64_t)tx - ex, (int64_t)ty - ey, (int64_t)tz - ez };
    if (!norm_q14(fv[0], fv[1], fv[2], f)) return 0;

    int64_t upv[3] = { ux, uy, uz }, rv[3];
    int64_t fq[3] = { f[0], f[1], f[2] };
    cross64(upv, fq, rv);                       /* right = up x forward */
    if (!norm_q14(rv[0], rv[1], rv[2], r)) return 0;   /* looking straight up */

    int64_t rq[3] = { r[0], r[1], r[2] }, uv[3];
    cross64(fq, rq, uv);                        /* true up = forward x right */
    if (!norm_q14(uv[0], uv[1], uv[2], u)) return 0;

    vpy_xf c;
    c.m[0] = r[0]; c.m[1] = r[1]; c.m[2] = r[2];
    c.m[3] = u[0]; c.m[4] = u[1]; c.m[5] = u[2];
    c.m[6] = f[0]; c.m[7] = f[1]; c.m[8] = f[2];
    /* translation = -R * eye */
    for (int i = 0; i < 3; i++) {
        int64_t s = (int64_t)c.m[i * 3 + 0] * ex
                  + (int64_t)c.m[i * 3 + 1] * ey
                  + (int64_t)c.m[i * 3 + 2] * ez;
        c.t[i] = (int32_t)(-(s >> 14));
    }
    vpy3d_set_camera(&c);
    return 1;
}

void vpy3d_to_camera(int32_t wx, int32_t wy, int32_t wz, int32_t *out)
{
    const vpy_xf *c = vpy3d_camera();
    for (int i = 0; i < 3; i++) {
        int64_t s = (int64_t)c->m[i * 3 + 0] * wx
                  + (int64_t)c->m[i * 3 + 1] * wy
                  + (int64_t)c->m[i * 3 + 2] * wz;
        out[i] = (int32_t)(s >> 14) + c->t[i];
    }
}

/* ── projection and clipping ─────────────────────────────────────────────── */
static int64_t lim(int64_t v)
{
    const int64_t L = (int64_t)1 << 30;
    return v > L ? L : (v < -L ? -L : v);
}

int vpy3d_project(const int32_t *p, int32_t *sx, int32_t *sy)
{
    if (p[2] < s_near) return 0;
    *sx = (int32_t)lim((int64_t)p[0] * s_focal / p[2]);
    *sy = (int32_t)lim((int64_t)p[1] * s_focal / p[2]);
    return 1;
}

static int outcode(int64_t x, int64_t y)
{
    return (x < -s_clip) | ((x > s_clip) << 1) | ((y < -s_clip) << 2) | ((y > s_clip) << 3);
}

/* Cohen-Sutherland against the visible square, then into libvpy's buffer. */
static void line_screen(int64_t x0, int64_t y0, int64_t x1, int64_t y1, int br)
{
    int c0 = outcode(x0, y0), c1 = outcode(x1, y1);
    for (int guard = 0; guard < 8; guard++) {
        if (!(c0 | c1)) {
            vpy_draw_line_dev((int32_t)x0, (int32_t)y0, (int32_t)x1, (int32_t)y1, br);
            s_stats.strokes++;
            return;
        }
        if (c0 & c1) return;                 /* wholly outside the same edge */
        int c = c0 ? c0 : c1;
        int64_t x, y, dx = x1 - x0, dy = y1 - y0;
        if      (c & 8) { y =  s_clip; x = x0 + (dy ? dx * (y - y0) / dy : 0); }
        else if (c & 4) { y = -s_clip; x = x0 + (dy ? dx * (y - y0) / dy : 0); }
        else if (c & 2) { x =  s_clip; y = y0 + (dx ? dy * (x - x0) / dx : 0); }
        else            { x = -s_clip; y = y0 + (dx ? dy * (x - x0) / dx : 0); }
        if (c == c0) { x0 = x; y0 = y; c0 = outcode(x0, y0); }
        else         { x1 = x; y1 = y; c1 = outcode(x1, y1); }
    }
}

void vpy3d_line_cam(const int32_t *a, const int32_t *b, int br)
{
    int64_t x0 = a[0], y0 = a[1], z0 = a[2];
    int64_t x1 = b[0], y1 = b[1], z1 = b[2];
    if (z0 < s_near && z1 < s_near) return;          /* all of it is behind us */
    if (z0 < s_near) {                                /* cut it at the near plane */
        int64_t k = ((s_near - z0) << 16) / (z1 - z0);
        x0 += ((x1 - x0) * k) >> 16;
        y0 += ((y1 - y0) * k) >> 16;
        z0 = s_near;
    }
    if (z1 < s_near) {
        int64_t k = ((s_near - z1) << 16) / (z0 - z1);
        x1 += ((x0 - x1) * k) >> 16;
        y1 += ((y0 - y1) * k) >> 16;
        z1 = s_near;
    }
    line_screen(lim(x0 * s_focal / z0), lim(y0 * s_focal / z0),
                lim(x1 * s_focal / z1), lim(y1 * s_focal / z1), br);
}

void vpy3d_line_world(int32_t ax, int32_t ay, int32_t az,
                      int32_t bx, int32_t by, int32_t bz, int br)
{
    int32_t a[3], b[3];
    vpy3d_to_camera(ax, ay, az, a);
    vpy3d_to_camera(bx, by, bz, b);
    vpy3d_line_cam(a, b, br);
}

/* ── building a mesh ─────────────────────────────────────────────────────── */
int vpy3d_mesh_begin(vpy_mesh *m)
{
    B = m;
    m->v0 = (uint16_t)nPV; m->nv = 0;
    m->f0 = (uint16_t)nPF; m->nf = 0;
    m->e0 = (uint16_t)nPE; m->ne = 0;
    m->open = 0;
    return 1;
}

int vpy3d_vertex(int x, int y, int z)
{
    if (!B || nPV >= VPY3D_POOL_V || B->nv >= VPY3D_MESH_MAXV) {
        s_stats.overflow++; return -1;
    }
    PV[nPV][0] = (int16_t)x; PV[nPV][1] = (int16_t)y; PV[nPV][2] = (int16_t)z;
    nPV++;
    return B->nv++;
}

int vpy3d_face(const int *idx, int n)
{
    if (!B || n < 3 || nPF >= VPY3D_POOL_F || B->nf >= VPY3D_MESH_MAXF
           || nPFV + n > VPY3D_POOL_FV) {
        s_stats.overflow++; return -1;
    }
    PFs[nPF] = (uint16_t)nPFV;
    PFn[nPF] = (uint8_t)n;
    for (int i = 0; i < n; i++) PFV[nPFV++] = (uint16_t)idx[i];
    nPF++;
    return B->nf++;
}
int vpy3d_quad(int a, int b, int c, int d) { int i[4] = {a,b,c,d}; return vpy3d_face(i, 4); }
int vpy3d_tri (int a, int b, int c)        { int i[3] = {a,b,c};   return vpy3d_face(i, 3); }

void vpy3d_mesh_open(vpy_mesh *m, int open) { m->open = (uint8_t)(open ? 1 : 0); }

static const int16_t *MV(const vpy_mesh *m, int i) { return PV[m->v0 + i]; }

/* Find the edge (a,b) inside the mesh, or add it. */
static int edge_of(vpy_mesh *m, int a, int b, int face)
{
    int lo = a < b ? a : b, hi = a < b ? b : a;
    for (int e = 0; e < m->ne; e++) {
        vpy3d_edge *E = &PE[m->e0 + e];
        if (E->a == lo && E->b == hi) {
            if (E->f1 < 0) E->f1 = (int16_t)face;
            return e;
        }
    }
    if (nPE >= VPY3D_POOL_E) { s_stats.overflow++; return -1; }
    vpy3d_edge *E = &PE[nPE++];
    E->a = (uint16_t)lo; E->b = (uint16_t)hi;
    E->f0 = (int16_t)face; E->f1 = -1;
    E->ca = E->cb = -1; E->hard = 0;
    return m->ne++;
}

int vpy3d_mesh_end(int hard_cos_q14)
{
    if (!B) return 0;
    vpy_mesh *m = B;
    B = 0;
    uint32_t bad = s_stats.overflow;

    /* --- face normals, by Newell's method ---------------------------------
     * Newell rather than a cross product of the first three vertices: it uses
     * every vertex, so it survives a quad that is slightly non-planar and a
     * face whose first three corners are nearly in line. Wind anticlockwise
     * seen from outside and it points outward. */
    int64_t cx = 0, cy = 0, cz = 0;
    for (int i = 0; i < m->nv; i++) {
        const int16_t *v = MV(m, i);
        cx += v[0]; cy += v[1]; cz += v[2];
    }
    if (m->nv) { cx /= m->nv; cy /= m->nv; cz /= m->nv; }

    for (int f = 0; f < m->nf; f++) {
        int fi = m->f0 + f;
        int n = PFn[fi];
        const uint16_t *iv = &PFV[PFs[fi]];
        int64_t nx = 0, ny = 0, nz = 0, gx = 0, gy = 0, gz = 0;
        for (int i = 0; i < n; i++) {
            const int16_t *p = MV(m, iv[i]);
            const int16_t *q = MV(m, iv[(i + 1) % n]);
            nx += (int64_t)(p[1] - q[1]) * (p[2] + q[2]);
            ny += (int64_t)(p[2] - q[2]) * (p[0] + q[0]);
            nz += (int64_t)(p[0] - q[0]) * (p[1] + q[1]);
            gx += p[0]; gy += p[1]; gz += p[2];
        }
        gx /= n; gy /= n; gz /= n;
        int32_t u[3];
        if (!norm_q14(nx, ny, nz, u)) { u[0] = 0; u[1] = 0; u[2] = VPY3D_ONE; }
        /* A normal pointing back at the middle of the mesh is inside-out. This
         * rescues a face wound the wrong way; it cannot rescue one whose plane
         * runs through the centroid, so winding still matters. */
        int64_t outward = (int64_t)u[0] * (gx - cx)
                        + (int64_t)u[1] * (gy - cy)
                        + (int64_t)u[2] * (gz - cz);
        if (outward < 0) { u[0] = -u[0]; u[1] = -u[1]; u[2] = -u[2]; }
        PN[fi][0] = (int16_t)u[0]; PN[fi][1] = (int16_t)u[1]; PN[fi][2] = (int16_t)u[2];
    }

    /* --- the edge table, with the face either side ------------------------ */
    for (int f = 0; f < m->nf; f++) {
        int fi = m->f0 + f;
        int n = PFn[fi];
        const uint16_t *iv = &PFV[PFs[fi]];
        for (int i = 0; i < n; i++)
            if (edge_of(m, iv[i], iv[(i + 1) % n], f) < 0) break;
    }

    /* --- which edges are creases ------------------------------------------ */
    for (int e = 0; e < m->ne; e++) {
        vpy3d_edge *E = &PE[m->e0 + e];
        if (E->f1 < 0) { E->hard = 1; continue; }        /* a rim is always a line */
        const int16_t *p = PN[m->f0 + E->f0], *q = PN[m->f0 + E->f1];
        int32_t dot = ((int32_t)p[0] * q[0] + (int32_t)p[1] * q[1]
                     + (int32_t)p[2] * q[2]) >> 14;
        E->hard = (uint8_t)(dot < hard_cos_q14);
    }

    /* --- straight-run links ------------------------------------------------
     * Two edges meeting at a vertex continue one straight line when their
     * directions away from that vertex are exactly opposite. Exact integer
     * test, no tolerance: these are lattice points. If more than one candidate
     * meets there the run is ambiguous and stops, which is the safe answer. */
    for (int e = 0; e < m->ne; e++) {
        vpy3d_edge *E = &PE[m->e0 + e];
        for (int side = 0; side < 2; side++) {
            int v     = side ? E->b : E->a;
            int other = side ? E->a : E->b;
            const int16_t *pv = MV(m, v), *po = MV(m, other);
            int64_t d1[3] = { po[0]-pv[0], po[1]-pv[1], po[2]-pv[2] };
            int found = -1, count = 0;
            for (int g = 0; g < m->ne; g++) {
                if (g == e) continue;
                vpy3d_edge *G = &PE[m->e0 + g];
                int w;
                if      (G->a == v) w = G->b;
                else if (G->b == v) w = G->a;
                else continue;
                const int16_t *pw = MV(m, w);
                int64_t d2[3] = { pw[0]-pv[0], pw[1]-pv[1], pw[2]-pv[2] };
                int64_t cr[3]; cross64(d1, d2, cr);
                int64_t dp = d1[0]*d2[0] + d1[1]*d2[1] + d1[2]*d2[2];
                if (cr[0] == 0 && cr[1] == 0 && cr[2] == 0 && dp < 0) {
                    found = g; count++;
                }
            }
            int16_t link = (count == 1) ? (int16_t)found : (int16_t)-1;
            if (side) E->cb = link; else E->ca = link;
        }
    }

    if (nPV > s_stats.verts)    s_stats.verts    = (uint16_t)nPV;
    if (nPF > s_stats.faces)    s_stats.faces    = (uint16_t)nPF;
    if (nPFV > s_stats.face_idx) s_stats.face_idx = (uint16_t)nPFV;
    if (nPE > s_stats.edges)    s_stats.edges    = (uint16_t)nPE;
    return s_stats.overflow == bad;
}

/* ── drawing a mesh ──────────────────────────────────────────────────────── */
void vpy3d_draw_mesh(const vpy_mesh *m, const vpy_xf *place, int br)
{
    if (m->nv > VPY3D_MESH_MAXV || m->nf > VPY3D_MESH_MAXF) { s_stats.overflow++; return; }
    const vpy_xf *cam = vpy3d_camera();
    vpy_xf mv = vpy3d_mul(cam, place);         /* model -> camera, in one go */

    for (int i = 0; i < m->nv; i++) {
        const int16_t *p = MV(m, i);
        for (int r = 0; r < 3; r++) {
            int32_t s = (mv.m[r*3+0] * p[0] + mv.m[r*3+1] * p[1] + mv.m[r*3+2] * p[2]) >> 14;
            TC[i][r] = s + mv.t[r];
        }
    }

    /* A face is turned toward us when its normal leans back at the camera —
     * the camera sits at the origin, so the vector to any of its vertices IS
     * the view direction and the sign of the dot product decides. */
    for (int f = 0; f < m->nf; f++) {
        const int16_t *n = PN[m->f0 + f];
        int64_t nx = (int64_t)(mv.m[0]*n[0] + mv.m[1]*n[1] + mv.m[2]*n[2]) >> 14;
        int64_t ny = (int64_t)(mv.m[3]*n[0] + mv.m[4]*n[1] + mv.m[5]*n[2]) >> 14;
        int64_t nz = (int64_t)(mv.m[6]*n[0] + mv.m[7]*n[1] + mv.m[8]*n[2]) >> 14;
        const int32_t *v = TC[PFV[PFs[m->f0 + f]]];
        FV[f] = (uint8_t)((nx*v[0] + ny*v[1] + nz*v[2]) < 0);
    }

    for (int e = 0; e < m->ne; e++) {
        const vpy3d_edge *E = &PE[m->e0 + e];
        int draw;
        if (E->f1 < 0)         draw = m->open ? 1 : FV[E->f0];   /* a rim */
        else if (E->hard)      draw = FV[E->f0] | FV[E->f1];     /* a crease */
        else                   draw = FV[E->f0] != FV[E->f1];    /* a silhouette */
        ES[e] = (uint8_t)(E->f1 < 0 || FV[E->f0] != FV[E->f1]);
        if (s_wire) draw = 1;             /* a cage keeps what the solid hides */
        ED[e] = (uint8_t)draw;
        if (!draw) s_stats.culled++;
    }

    /* Emit, folding straight runs into one stroke. A straight line in 3D
     * projects to a straight line in 2D, so this is exact, not an approximation
     * — and a stroke costs the beam the same whatever its length. */
    int ns = 0;
    for (int e = 0; e < m->ne; e++) {
        if (ED[e] != 1) continue;
        int c = e, v = PE[m->e0 + e].a;
        for (int g = 0; g < 64; g++) {               /* walk back to the start */
            const vpy3d_edge *C = &PE[m->e0 + c];
            int nb = (C->a == v) ? C->ca : C->cb;
            if (nb < 0 || ED[nb] != 1) break;
            const vpy3d_edge *N = &PE[m->e0 + nb];
            v = (N->a == v) ? N->b : N->a;
            c = nb;
        }
        int start = v;
        for (int g = 0; g < 64; g++) {               /* ...then on to the end */
            const vpy3d_edge *C = &PE[m->e0 + c];
            ED[c] = 2;
            if (g) s_stats.merged++;
            v = (C->a == v) ? C->b : C->a;
            int nb = (C->a == v) ? C->ca : C->cb;
            if (nb < 0 || ED[nb] != 1) break;
            c = nb;
        }
        if (ns < VPY3D_POOL_E) { RA[ns] = (uint16_t)start; RB[ns] = (uint16_t)v; RU[ns] = 0; ns++; }
    }

    /* Put them in an order the BEAM likes. A stroke that starts where the last
     * one ended pays no blanked jump (~48 cycles), and — the part that is not
     * just cost — no re-centre either: the SDK re-zeroes the integrators before
     * any jump over uvm2_zero_jump, and on a small object nearly every jump is
     * over it. Emitting in edge-index order measured 1 of 9 strokes chained and
     * 78% of jumps forcing a re-zero, and because WHICH edges survive changes as
     * the object turns, that pattern changed every frame and the figure shook.
     *
     * This is not the nearest-neighbour reordering that is known to backfire: it
     * follows the mesh's own connectivity, which is exact — two runs meet or they
     * do not — so it cannot invent a join that is not there. */
    if (!s_chain) {
        for (int i = 0; i < ns; i++) vpy3d_line_cam(TC[RA[i]], TC[RB[i]], br);
        return;
    }
    int cur = -1;
    for (int done = 0; done < ns; done++) {
        int pick = -1, flip = 0;
        if (cur >= 0) {
            for (int i = 0; i < ns; i++) {
                if (RU[i]) continue;
                if (RA[i] == cur) { pick = i; flip = 0; break; }
                if (RB[i] == cur) { pick = i; flip = 1; break; }
            }
        }
        if (pick < 0) {                       /* nothing meets the beam: lift it */
            for (int i = 0; i < ns; i++) if (!RU[i]) { pick = i; flip = 0; break; }
            if (pick < 0) break;
        } else {
            s_stats.chained++;
        }
        RU[pick] = 1;
        int a = flip ? RB[pick] : RA[pick];
        int b = flip ? RA[pick] : RB[pick];
        vpy3d_line_cam(TC[a], TC[b], br);
        cur = b;
    }
}

/* ── loading a compiled .vmesh ───────────────────────────────────────────
 * The layout is in vmeshres.rs; it is little-endian and byte-packed, so it is
 * read a byte at a time rather than cast over — the image may sit at any
 * alignment in ROM and a Cortex-M would not forgive a misaligned i16 load
 * through a struct pointer. */
static vpy3d_error_t s_err;
vpy3d_error_t vpy3d_error(void) { return s_err; }

static uint16_t rd16(const unsigned char *p) { return (uint16_t)(p[0] | (p[1] << 8)); }
static int16_t  rds16(const unsigned char *p) { return (int16_t)rd16(p); }

int vpy3d_load_mesh(vpy_mesh *m, const unsigned char *d)
{
    s_err = VPY3D_OK;
    if (!d || d[0] != 'V' || d[1] != 'M' || d[2] != 'S' || d[3] != 'H') {
        s_err = VPY3D_ERR_MAGIC; return 0;
    }
    if (d[4] != 1) { s_err = VPY3D_ERR_VERSION; return 0; }

    int      open      = d[5] & 1;
    int      hard_cos  = rds16(d + 6);
    unsigned nv        = rd16(d + 8);
    unsigned nf        = rd16(d + 10);
    unsigned nidx      = rd16(d + 12);

    uint32_t before = s_stats.overflow;
    vpy3d_mesh_begin(m);

    const unsigned char *v = d + 16;
    for (unsigned i = 0; i < nv; i++, v += 6)
        if (vpy3d_vertex(rds16(v), rds16(v + 2), rds16(v + 4)) < 0) {
            s_err = VPY3D_ERR_POOL; B = 0; return 0;
        }

    const unsigned char *f = v;
    unsigned seen = 0;
    int idx[VPY3D_MESH_MAXV];
    for (unsigned i = 0; i < nf; i++) {
        unsigned n = *f++;
        if (n < 3 || n > VPY3D_MESH_MAXV || seen + n > nidx) {
            s_err = VPY3D_ERR_DATA; B = 0; return 0;
        }
        for (unsigned k = 0; k < n; k++, f += 2) {
            unsigned vi = rd16(f);
            if (vi >= nv) { s_err = VPY3D_ERR_DATA; B = 0; return 0; }
            idx[k] = (int)vi;
        }
        seen += n;
        if (vpy3d_face(idx, (int)n) < 0) { s_err = VPY3D_ERR_POOL; B = 0; return 0; }
    }
    if (seen != nidx) { s_err = VPY3D_ERR_DATA; B = 0; return 0; }

    if (!vpy3d_mesh_end(hard_cos)) {
        s_err = (s_stats.overflow != before) ? VPY3D_ERR_POOL : VPY3D_ERR_DATA;
        return 0;
    }
    vpy3d_mesh_open(m, open);
    return 1;
}

void vpy3d_set_wire(int on) { s_wire = on ? 1 : 0; }
int  vpy3d_get_wire(void)   { return s_wire; }

void vpy3d_set_chaining(int on) { s_chain = on ? 1 : 0; }
int  vpy3d_get_chaining(void)    { return s_chain; }

/* ── counters ────────────────────────────────────────────────────────────── */
const vpy3d_stats_t *vpy3d_stats(void) { return &s_stats; }
void vpy3d_reset_counts(void) { s_stats.strokes = 0; s_stats.culled = 0; s_stats.merged = 0; }
