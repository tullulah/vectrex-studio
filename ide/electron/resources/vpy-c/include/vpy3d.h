/*
 * vpy3d.h — the 3D layer of libvpy: transforms, a camera, true perspective,
 * and surface meshes drawn with hidden-line removal.
 *
 * WHAT THIS IS FOR. A vector display has no fill, so a solid drawn as all of
 * its edges reads as a wireframe cage and not as an object. The fix is to give
 * the solid real FACES and draw an edge only when it is a silhouette (one face
 * toward the viewer, one away) or a hard crease with a visible face. A smooth
 * curve then shows only its moving outline, the way a person would draw it.
 * That is what this module does, and it is the part a game cannot reasonably
 * write for itself.
 *
 * INTEGER ONLY, like the rest of libvpy — no <math.h>, no floats anywhere. The
 * same C runs on the cartridge, on PiTrex and in the IDE simulator. Rotations
 * are Q14 (16384 = 1.0) and angles are the 4096-per-turn units of
 * vpy_sin_q14(); 128 steps would show as a staircase on a moving camera.
 *
 * UNITS
 *   model      int16, whatever the model is authored in (mm works well)
 *   world      int32, same unit as the model
 *   camera     int32, +x right, +y up, +z INTO the screen (away from you)
 *   screen     PiTrex deflection units, straight into the libvpy stroke buffer
 *              via vpy_draw_line_dev — so 3D shares the frame, the priorities
 *              and the flush with everything else the game draws
 *   angles     4096 per full turn
 *   brightness 0..127
 *
 * WHAT COSTS TIME is the number of strokes, not their length: a stroke is ~13
 * bus commands on the UVM2 whatever it spans, and a blanked jump before it is
 * ~5 more. So straight runs across several faces are merged into ONE stroke,
 * which is exact — a straight line in 3D projects to a straight line in 2D.
 * Use vpy_set_priority() to say what may be shed when a frame will not fit.
 */
#ifndef VPY3D_H
#define VPY3D_H

#include <stdint.h>
#include "vpy.h"

#ifdef __cplusplus
extern "C" {
#endif

/* ---- pool sizes -----------------------------------------------------------
 * All meshes share these, filled once at start-up. Override with -D if a game
 * needs more; vpy3d_pool_used() reports the high-water marks so the numbers
 * come from a measurement and not from a guess. */
#ifndef VPY3D_POOL_V
#define VPY3D_POOL_V  512      /* vertices, all meshes together */
#endif
#ifndef VPY3D_POOL_F
#define VPY3D_POOL_F  512      /* faces */
#endif
#ifndef VPY3D_POOL_FV
#define VPY3D_POOL_FV 2048     /* face->vertex index entries */
#endif
#ifndef VPY3D_POOL_E
#define VPY3D_POOL_E  1024     /* edges */
#endif
#ifndef VPY3D_MESH_MAXV
#define VPY3D_MESH_MAXV 256    /* vertices in ONE mesh (the per-draw scratch) */
#endif
#ifndef VPY3D_MESH_MAXF
#define VPY3D_MESH_MAXF 256
#endif

#define VPY3D_ONE 16384        /* Q14: this is 1.0 */

/* ---- a transform ----------------------------------------------------------
 * A 3x3 rotation in Q14 plus an integer translation. Column-major is a trap
 * waiting to happen, so: m[row*3 + col], and applying it is
 *   out[r] = (m[r*3+0]*v0 + m[r*3+1]*v1 + m[r*3+2]*v2) >> 14 + t[r]. */
typedef struct { int32_t m[9]; int32_t t[3]; } vpy_xf;

vpy_xf vpy3d_identity(void);
vpy_xf vpy3d_mul(const vpy_xf *a, const vpy_xf *b);   /* apply b, then a */
vpy_xf vpy3d_rot_x(int ang);
vpy_xf vpy3d_rot_y(int ang);
vpy_xf vpy3d_rot_z(int ang);
vpy_xf vpy3d_translate(int32_t x, int32_t y, int32_t z);

/* ---- the camera ---- */
void vpy3d_set_camera(const vpy_xf *world_to_camera);
/* Point the camera at something. `up` is the world direction that should end
 * up pointing up on screen; pass 0,1,0 unless you are doing something clever.
 * Returns 0 and leaves the camera alone if eye and target coincide. */
int  vpy3d_look_at(int32_t ex, int32_t ey, int32_t ez,
                   int32_t tx, int32_t ty, int32_t tz,
                   int32_t ux, int32_t uy, int32_t uz);
const vpy_xf *vpy3d_camera(void);
/* Where the camera IS, in world coordinates.
 *
 * The transform holds world->camera, so the eye is -R^T * t and not something
 * that can be read off it directly. Worth having as a call: culling an axis
 * aligned face is one comparison against the eye — a +x face is visible when
 * the eye is further out in x than the face is — and that is the whole of
 * hidden-surface removal for a grid of boxes. */
void vpy3d_eye(int32_t *out);

/* Field of view, as deflection units per unit of x over z. Bigger = narrower.
 * The default (28000) is about 58 degrees across. */
void vpy3d_set_focal(int32_t focal);
/* Nothing closer to the camera than this is drawn; lines crossing it are cut.
 * In world units. Default 600. */
void vpy3d_set_near(int32_t near_z);
/* Half-width of the visible square in deflection units. Default 15500. */
void vpy3d_set_clip(int32_t half);

/* ---- drawing without a mesh ---- */
void vpy3d_line_cam(const int32_t *a, const int32_t *b, int br);   /* camera space */
void vpy3d_line_world(int32_t ax, int32_t ay, int32_t az,
                      int32_t bx, int32_t by, int32_t bz, int br);
/* Project one camera-space point to deflection units. 0 if behind the near
 * plane, in which case sx and sy are untouched. */
int  vpy3d_project(const int32_t *cam, int32_t *sx, int32_t *sy);
/* Move a point from world into camera space. */
void vpy3d_to_camera(int32_t wx, int32_t wy, int32_t wz, int32_t *out);

/* ---- meshes ---------------------------------------------------------------
 * Build once at start-up, draw every frame:
 *
 *   vpy_mesh cube;
 *   vpy3d_mesh_begin(&cube);
 *   int v[8]; for (...) v[i] = vpy3d_vertex(x, y, z);
 *   int f[4] = { v[0], v[1], v[2], v[3] }; vpy3d_face(f, 4);
 *   ...
 *   vpy3d_mesh_end(VPY3D_HARD_45);
 *
 * Wind each face so its vertices go ANTICLOCKWISE seen from outside. If a
 * model comes out inside-out, that winding is why — vpy3d_mesh_end flips any
 * normal that points at the mesh centroid, which rescues most cases but not a
 * face whose plane passes near the centroid. */
typedef struct {
    uint16_t v0, nv;
    uint16_t f0, nf;
    uint16_t e0, ne;
    uint8_t  open;    /* 1 = a plate, not a solid: its outline is always drawn */
} vpy_mesh;

/* Crease threshold: two faces meeting at a sharper angle than this keep their
 * shared edge. Q14 cosine — a bigger number is a stricter test (fewer lines). */
#define VPY3D_HARD_30  14189   /* cos 30 deg */
#define VPY3D_HARD_45  11585   /* cos 45 deg */
#define VPY3D_HARD_60   8192   /* cos 60 deg */
#define VPY3D_HARD_ALL 16384   /* every edge is a crease: a full wireframe */

int  vpy3d_mesh_begin(vpy_mesh *m);           /* 0 if the pools are exhausted */
int  vpy3d_vertex(int x, int y, int z);       /* returns its index, or -1 */
int  vpy3d_face(const int *idx, int n);       /* indices from vpy3d_vertex */
int  vpy3d_quad(int a, int b, int c, int d);
int  vpy3d_tri(int a, int b, int c);
int  vpy3d_mesh_end(int hard_cos_q14);        /* 0 on overflow; see vpy3d_error() */
void vpy3d_mesh_open(vpy_mesh *m, int open);  /* mark a plate after building it */

void vpy3d_draw_mesh(const vpy_mesh *m, const vpy_xf *place, int br);

/* CAGE MODE: draw every edge of the next meshes, the hidden ones too.
 *
 * A solid and a cage of the same shape read as two different objects at any
 * distance and at any brightness — which is what makes this worth having on a
 * monochrome tube, where brightness is usually already spent on depth. It costs
 * the edges it adds and nothing else: no second mesh to author and keep in step
 * with the first, and no geometry that can drift apart from it.
 *
 * A draw-time mode rather than a property of the mesh, like the priority: the
 * same cube can be a solid in one place on the board and a cage in another. */
void vpy3d_set_wire(int on);
int  vpy3d_get_wire(void);

/* Emit a mesh's strokes in an order that follows its own connectivity, so a
 * stroke starts where the last one ended and pays neither a blanked jump nor
 * the beam re-centre that a long jump forces. On by default. Turn it off only
 * to measure what it is worth — it is the difference between a small rotating
 * solid sitting still and one that shakes as it turns. */
void vpy3d_set_chaining(int on);
int  vpy3d_get_chaining(void);

/* ---- compiled meshes (.vmesh) ---------------------------------------------
 * `data` is the byte image from
 *   vpy_cli compile-asset <file>.vmesh --format c --out <name>.h
 * Building it goes through the very same vpy3d_vertex / vpy3d_face /
 * vpy3d_mesh_end as a hand-built mesh — there is ONE mesh builder, so a
 * compiled cube and a cube written out in C draw identically.
 *
 * Returns 0 and leaves `m` alone if the magic or the version is wrong, or if
 * the pools are full; vpy3d_error() says which. */
int vpy3d_load_mesh(vpy_mesh *m, const unsigned char *data);

/* Why the last vpy3d_load_mesh returned 0. */
typedef enum {
    VPY3D_OK = 0,
    VPY3D_ERR_MAGIC,     /* not a .vmesh */
    VPY3D_ERR_VERSION,   /* a newer .vmesh than this runtime understands */
    VPY3D_ERR_POOL,      /* the shared pools are full: raise VPY3D_POOL_* */
    VPY3D_ERR_DATA       /* the image is self-inconsistent */
} vpy3d_error_t;
vpy3d_error_t vpy3d_error(void);

/* ---- what did it cost, and did anything not fit ---- */
typedef struct {
    uint16_t verts, faces, face_idx, edges;   /* pool high-water marks */
    uint32_t strokes;      /* strokes the last vpy3d_draw_mesh emitted */
    uint32_t culled;       /* edges hidden by the visibility test */
    uint32_t merged;       /* edges folded into a longer run */
    uint32_t chained;      /* strokes that started where the last one ended */
    uint32_t overflow;     /* builds that did not fit a pool. NOT ZERO = broken */
} vpy3d_stats_t;
const vpy3d_stats_t *vpy3d_stats(void);
void vpy3d_reset_counts(void);   /* zero the per-frame counters, keep the marks */

#ifdef __cplusplus
}
#endif

#endif /* VPY3D_H */
