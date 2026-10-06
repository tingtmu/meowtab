// cutout.c - native port of cutout.py: make cartoon stickers (dark outline on a near-uniform light background)
// transparent and find the tight square to crop them to. Compiled to machine code by build-mcode.ps1 and run by
// cutout.ahk on a worker thread. Function names mirror cutout.py so the two can be compared step by step.
// Freestanding: no CRT, no globals, no static tables, no float (MCode has no constant pool), no library calls,
// no recursion. All memory comes from the caller's scratch buffer. Fractions are integer / fixed point:
// colours x2 (np.median of an even count ends in .5), tolerances x4, scale as S = scale * REF_SIZE.

// Every helper is force-inlined: a call between functions would need a relocation, which MCode can't have.
#define FN static inline __attribute__((always_inline))

typedef struct {                 // layout shared with cutout.ahk: keep offsets in sync (all 8-byte aligned)
    unsigned char *px;           //  0 in/out: w*h pixels, GDI+ PixelFormat32bppARGB (bytes B,G,R,A), stride w*4
    long long scratch_size;      //  8 bytes available at scratch
    unsigned char *scratch;      // 16
    int w, h;                    // 24, 28
    int flags;                   // 32 bit0 = use bottom seal (cutout.py default: on)
    int status;                  // 36 out, see codes
    int left, top, side;         // 40, 44, 48 out: crop square (left/top may be negative = transparent pad)
    int pad_;                    // 52
} CutoutJob;                     // 56 bytes

// Status codes (cutout.ahk maps them to messages)
#define ST_CLEANED 0             // background removed, px rewritten
#define ST_TRANSPARENT 1         // already transparent: crop only, px untouched
#define ST_NOT_UNIFORM 10        // background not uniform (border colours vary)
#define ST_NOT_LIGHT 11          // background is not light
#define ST_NO_OUTLINE 12         // no dark outline found
#define ST_NO_BG 13              // no background reachable from the border
#define ST_NOTHING 14            // nothing visible after processing
#define ST_INTERNAL 20           // scratch too small / bad size

// cutout.py's constants
#define INK_MAX 110              // max(R,G,B) below this = ink
#define CHROMA_MIN 25            // max-min above this (and not bg-coloured) = coloured fill
#define SEAL_R 4                 // closing radius for outline gaps (px at scale 1)
#define SEAL_GAP 100             // bottom seal: strokes must be this far from centre (px at scale 1)
#define SEAL_THICK 3             // bottom seal line thickness (px at scale 1)
#define REF_SIZE 780             // subject size (px) that corresponds to scale 1
#define MIN_SPECK 500            // opaque specks smaller than this are dropped (px^2 at scale 1000 px)
#define EDGE_REACH 3             // soft-edge width (px at scale 1)
#define TRANSP_ALPHA 16          // alpha below this counts as transparent ...
#define TRANSP_SHARE 100         // ... if more than 1/100 of pixels are
#define CROP_ALPHA 20            // content = alpha > ~8%
#define CROP_PAD 3               // padding per side, percent of content size
#define MAX_PIXELS (1LL << 26)   // hard limit (cutout.ahk refuses far smaller images already)

// Per-pixel mask bits in Ctx.f
#define INK 1                    // rgb.max < INK_MAX
#define NEAR_BG 2                // near_bg: within tol of the background colour
#define COLORED 4                // chroma > CHROMA_MIN and not near_bg
#define CORE 8                   // main_ink: ink without dust
#define CLOSED 16                // close_mask(ink)
#define LINE 32                  // bottom_seal's line
#define BG 64                    // background (flood from the border)
#define BG2 128                  // background with the bottom seal

typedef struct {
    unsigned char *px, *f, *a, *b;   // pixels (B,G,R,A), mask bits, two temp masks
    int *lab, *q, *areas, *hist;     // labels / visited tags, queue, component areas, histograms
    int *g, *rs, *rt, *rg;           // distance transform plane and its row arrays
    unsigned char *free, *end;       // uncarved scratch
    int w, h, n;
    int x0, y0, x1, y1;              // CORE's bounding box
    int S;                           // scale * REF_SIZE, 39..15600 (scale 0.05..20)
    int bg2[3], tol4, ink2[3];       // background colour x2, tolerance x4, ink colour x2 (B,G,R)
} Ctx;

// ---------- helpers ----------

FN int imax(int a, int b) { return a > b ? a : b; }
FN int imin(int a, int b) { return a < b ? a : b; }
FN int iabs(int a) { return a < 0 ? -a : a; }

FN long long round_div(long long a, long long b)   // Python round(a / b) for a >= 0, b > 0: half to even
{
    long long q = a / b, r = a % b;
    return 2 * r > b || (2 * r == b && (q & 1)) ? q + 1 : q;
}

FN void fill_int(int *p, long long n, int v)
{
    for (long long i = 0; i < n; i++)
        p[i] = v;
}

FN void *carve(Ctx *c, long long bytes)   // next 16-byte aligned block of scratch; 0 = doesn't fit
{
    unsigned char *p = c->free;
    bytes = (bytes + 15) & ~15LL;
    if (bytes < 0 || bytes > c->end - p)
        return 0;
    c->free = p + bytes;
    return p;
}

FN int border_index(Ctx *c, long long i)   // np.concatenate([rgb[0], rgb[-1], rgb[:, 0], rgb[:, -1]])[i]
{
    int w = c->w, h = c->h;
    if (i < w)
        return (int)i;
    if (i < 2LL * w)
        return (h - 1) * w + (int)(i - w);
    if (i < 2LL * w + h)
        return (int)(i - 2LL * w) * w;
    return (int)(i - 2LL * w - h) * w + w - 1;
}

FN int median2(const int *hist, int bins, long long cnt)   // np.median x2 (even count: sum of the middle two)
{
    long long lo = (cnt - 1) / 2, hi = cnt / 2, seen = 0;
    int a = -1, v;
    for (v = 0; v < bins - 1; v++) {
        seen += hist[v];
        if (a < 0 && seen > lo)
            a = v;
        if (seen > hi)
            break;
    }
    return (a < 0 ? v : a) + v;
}

FN int seed(Ctx *c, int p, int id, int len)   // put p on the queue, tagged
{
    c->lab[p] = id;
    c->q[len] = p;
    return len + 1;
}

// Breadth-first growth from the seeds in q[0..len): pixels of pl with (pl & mask) == want join, 4- or
// 8-connected (ndi.label), each tagged in lab with id. Returns the queue length = the component's pixels.
FN int grow(Ctx *c, const unsigned char *pl, int mask, int want, int conn8, int id, int len)
{
    int w = c->w, h = c->h;
    for (int head = 0; head < len; head++) {
        int p = c->q[head], x = p % w, y = p / w;
        for (int dy = -1; dy <= 1; dy++)
            for (int dx = -1; dx <= 1; dx++) {
                if ((dx == 0 && dy == 0) || (!conn8 && dx && dy))
                    continue;
                if (x + dx < 0 || y + dy < 0 || x + dx >= w || y + dy >= h)
                    continue;
                int np = p + dy * w + dx;
                if (c->lab[np] || (pl[np] & mask) != want)
                    continue;
                c->lab[np] = id;
                c->q[len++] = np;
            }
    }
    return len;
}

// ndi.binary_dilation: dst = src grown one step with the cross (4-conn) or 3x3 (8-conn); outside is empty.
FN void dilate(Ctx *c, const unsigned char *src, unsigned char *dst, int conn8)
{
    int w = c->w, h = c->h;
    for (int y = 0; y < h; y++)
        for (int x = 0; x < w; x++) {
            int v = 0;
            for (int dy = -1; dy <= 1 && !v; dy++)
                for (int dx = -1; dx <= 1 && !v; dx++) {
                    if (!conn8 && dx && dy)
                        continue;
                    if (x + dx >= 0 && y + dy >= 0 && x + dx < w && y + dy < h)
                        v = src[(y + dy) * w + x + dx];
                }
            dst[y * w + x] = v != 0;
        }
}

FN void bit_plane(Ctx *c, unsigned char *dst, int mask, int want)   // dst = (f & mask) == want
{
    for (int i = 0; i < c->n; i++)
        dst[i] = (c->f[i] & mask) == want;
}

// ---------- distance transform (ndi.distance_transform_edt, exact, squared) ----------

FN long long parab(long long x, long long i, const int *g) { return (x - i) * (x - i) + (long long)g[i] * g[i]; }

FN long long sep(long long i, long long u, const int *g)
{
    return (u * u - i * i + (long long)g[u] * g[u] - (long long)g[i] * g[i]) / (2 * (u - i));
}

FN void edt_row(Ctx *c, int *row, int W)   // Meijster phase 2: column distances -> squared distances
{
    int *g = c->rg, *s = c->rs, *t = c->rt, q = 0;
    for (int u = 0; u < W; u++)
        g[u] = row[u];
    s[0] = 0;
    t[0] = 0;
    for (int u = 1; u < W; u++) {      // lower envelope of the parabolas
        while (q >= 0 && parab(t[q], s[q], g) > parab(t[q], u, g))
            q--;
        if (q < 0) {
            q = 0;
            s[0] = u;
        } else {
            long long wv = 1 + sep(s[q], u, g);
            if (wv < W) {
                q++;
                s[q] = u;
                t[q] = (int)wv;
            }
        }
    }
    for (int u = W - 1; u >= 0; u--) {
        long long d = parab(u, s[q], g);
        row[u] = d > 0x7fffffff ? 0x7fffffff : (int)d;
        if (u == t[q] && q > 0)
            q--;
    }
}

// Squared distance from every cell of g (W x H) to the nearest 0; other cells must hold W + H on entry.
// Meijster et al.: column distances by a down and an up sweep (row order), then the envelope per row.
FN void edt(Ctx *c, int W, int H)
{
    int *g = c->g;
    for (int y = 1; y < H; y++)
        for (int x = 0; x < W; x++) {
            int *p = g + (long long)y * W + x;
            if (p[-W] + 1 < *p)
                *p = p[-W] + 1;
        }
    for (int y = H - 2; y >= 0; y--)
        for (int x = 0; x < W; x++) {
            int *p = g + (long long)y * W + x;
            if (p[W] + 1 < *p)
                *p = p[W] + 1;
        }
    for (int y = 0; y < H; y++)
        edt_row(c, g + (long long)y * W, W);
}

// ---------- input ----------

FN int has_transparency(Ctx *c)   // share of alpha < TRANSP_ALPHA pixels > 1%
{
    long long k = 0;
    for (int i = 0; i < c->n; i++)
        k += c->px[4 * i + 3] < TRANSP_ALPHA;
    return TRANSP_SHARE * k > c->n;
}

FN void flatten_on_white(Ctx *c)   // PIL alpha_composite on opaque white (7-bit coefficients, same rounding)
{
    for (int i = 0; i < c->n; i++) {
        unsigned char *p = c->px + 4 * i;
        unsigned a = p[3];
        for (int k = 0; k < 3; k++) {
            unsigned t = (p[k] * a + 255 * (255 - a)) * 128 + 0x4000;
            p[k] = (unsigned char)((((t >> 8) + t) >> 8) >> 7);
        }
        p[3] = 255;
    }
}

// ---------- background removal ----------

// estimate_background: median border colour, a tolerance from border noise; the border must mostly fit.
FN int estimate_background(Ctx *c)
{
    int *hc = c->hist, *hd = c->hist + 768;      // 3 x 256 channel counts, 511 deviation counts
    long long K = 2LL * c->w + 2LL * c->h, fit = 0;
    fill_int(c->hist, 768 + 512, 0);
    for (long long i = 0; i < K; i++)
        for (int k = 0; k < 3; k++)
            hc[256 * k + c->px[4 * border_index(c, i) + k]]++;
    for (int k = 0; k < 3; k++)
        c->bg2[k] = median2(hc + 256 * k, 256, K);
    for (long long i = 0; i < K; i++) {          // dev = max over channels |border - color|, x2
        const unsigned char *p = c->px + 4 * border_index(c, i);
        int d = 0;
        for (int k = 0; k < 3; k++)
            d = imax(d, iabs(2 * p[k] - c->bg2[k]));
        hd[d]++;
    }
    c->tol4 = imin(imax(6 * median2(hd, 511, K) + 32, 48), 160);   // clip(6 * median(dev) + 8, 12, 40), x4
    for (int d = 0; 2 * d <= c->tol4; d++)
        fit += hd[d];
    if (5 * fit < 4 * K)
        return ST_NOT_UNIFORM;
    if (c->bg2[0] + c->bg2[1] + c->bg2[2] < 6 * 150)
        return ST_NOT_LIGHT;
    return 0;
}

FN void classify(Ctx *c)   // near_bg, ink and colored masks
{
    for (int i = 0; i < c->n; i++) {
        const unsigned char *p = c->px + 4 * i;
        int mx = imax(p[0], imax(p[1], p[2])), mn = imin(p[0], imin(p[1], p[2])), d = 0, fl = 0;
        for (int k = 0; k < 3; k++)
            d = imax(d, iabs(2 * p[k] - c->bg2[k]));
        if (2 * d <= c->tol4)
            fl |= NEAR_BG;
        if (mx < INK_MAX)
            fl |= INK;
        if (mx - mn > CHROMA_MIN && !(fl & NEAR_BG))
            fl |= COLORED;
        c->f[i] = (unsigned char)fl;
    }
}

// main_ink: ink components (8-conn) at least 5% as big as the largest -> CORE; sets its box and S. 0 = none.
FN int main_ink(Ctx *c)
{
    int id = 0, big = 0, cnt = 0, w = c->w;
    fill_int(c->lab, c->n, 0);
    for (int i = 0; i < c->n; i++) {
        if (!(c->f[i] & INK) || c->lab[i])
            continue;
        id++;
        c->areas[id] = grow(c, c->f, INK, INK, 1, id, seed(c, i, id, 0));
        big = imax(big, c->areas[id]);
    }
    c->x0 = w, c->y0 = c->h, c->x1 = -1, c->y1 = -1;
    for (int i = 0; i < c->n; i++) {
        if (!c->lab[i] || 20LL * c->areas[c->lab[i]] < big)
            continue;
        int x = i % w, y = i / w;
        c->f[i] |= CORE, cnt++;
        c->x0 = imin(c->x0, x), c->x1 = imax(c->x1, x), c->y0 = imin(c->y0, y), c->y1 = imax(c->y1, y);
    }
    // scale = clip(max(ptp(ys), ptp(xs)) / REF_SIZE, 0.05, 20)
    c->S = imin(imax(imax(c->x1 - c->x0, c->y1 - c->y0), REF_SIZE / 20), 20 * REF_SIZE);
    return cnt;
}

FN int carve_edt(Ctx *c, int r)   // distance transform memory for close_mask's padded plane (and soft_edge)
{
    long long W = c->w + 2LL * (r + 2), H = c->h + 2LL * (r + 2);
    c->g = carve(c, 4 * W * H);
    c->rs = carve(c, 4 * W);
    c->rt = carve(c, 4 * W);
    c->rg = carve(c, 4 * W);
    return c->g && c->rs && c->rt && c->rg && W + H < 0x3fffffff;
}

// close_mask: binary closing of INK with a disk of radius r, from two exact distance transforms on a plane
// padded by r + 2 (dil = edt(~p) <= r, closed = edt(dil) > r); sets CLOSED.
FN void close_mask(Ctx *c, int r)
{
    int P = r + 2, W = c->w + 2 * P, H = c->h + 2 * P, inf = W + H;
    long long r2 = (long long)r * r, np = (long long)W * H;
    for (int y = 0; y < H; y++)
        for (int x = 0; x < W; x++) {
            int ix = x - P, iy = y - P;
            int in = ix >= 0 && iy >= 0 && ix < c->w && iy < c->h && (c->f[iy * c->w + ix] & INK);
            c->g[(long long)y * W + x] = in ? 0 : inf;
        }
    edt(c, W, H);
    for (long long i = 0; i < np; i++)
        c->g[i] = c->g[i] <= r2 ? inf : 0;
    edt(c, W, H);
    for (int y = 0; y < c->h; y++)
        for (int x = 0; x < c->w; x++)
            if (c->g[(long long)(y + P) * W + x + P] > r2)
                c->f[y * c->w + x] |= CLOSED;
}

// flood_from_border: 4-connected flood over pixels with no `seal` bit, seeded from the border; sets `out`.
FN int flood_from_border(Ctx *c, int seal, int out)
{
    int len = 0;
    fill_int(c->lab, c->n, 0);
    for (long long i = 0; i < 2LL * c->w + 2LL * c->h; i++) {
        int p = border_index(c, i);
        if (!c->lab[p] && !(c->f[p] & seal))
            len = seed(c, p, 1, len);
    }
    len = grow(c, c->f, seal, 0, 0, 1, len);
    for (int k = 0; k < len; k++)
        c->f[c->q[k]] |= out;
    return len;
}

// ---------- ImageDraw.line, as Pillow rasterizes it (integer version) ----------

FN long long half_up(long long p, long long q)     // Pillow's ROUND_UP(p / q), q > 0: half away from zero
{
    return p < 0 ? -((2 * -p + q) / (2 * q)) : (2 * p + q) / (2 * q);
}

FN long long half_down(long long p, long long q)   // Pillow's ROUND_DOWN(p / q), q > 0: half toward zero
{
    return p < 0 ? -((-2 * p + q - 1) / (2 * q)) : (2 * p + q - 1) / (2 * q);
}

FN int corner(int k, long long d, long long L2)   // ROUND_DOWN(k * d / sqrt(L2)), exact
{
    long long ad = d < 0 ? -d : d;
    int m = 0;
    while (4LL * k * k * ad * ad > (2LL * m + 1) * (2LL * m + 1) * L2)
        m++;
    return d < 0 ? -m : m;
}

FN void plot(Ctx *c, long long x, long long y)
{
    if (x >= 0 && y >= 0 && x < c->w && y < c->h)
        c->f[y * c->w + x] |= LINE;
}

FN void thin_line(Ctx *c, int x0, int y0, int x1, int y1)   // ImagingDrawLine: Bresenham, Pillow's stepping
{
    int dx = iabs(x1 - x0), dy = iabs(y1 - y0), xs = x1 >= x0 ? 1 : -1, ys = y1 >= y0 ? 1 : -1;
    int flat = dx > dy, n = flat ? dx : dy, e = flat ? 2 * dy - dx : 2 * dx - dy;
    for (int i = 0; i <= n; i++) {
        plot(c, x0, y0);
        if (e >= 0 && flat)
            y0 += ys, e -= 2 * dx;
        else if (e >= 0)
            x0 += xs, e -= 2 * dy;
        if (flat)
            e += 2 * dy, x0 += xs;
        else
            e += 2 * dx, y0 += ys;
    }
}

FN void widen(long long *b, long long p, long long q)   // b = {lo p, lo q, hi p, hi q}: take in x = p / q
{
    if (q < 0)
        p = -p, q = -q;
    if (!b[1] || p * b[1] < b[0] * q)
        b[0] = p, b[1] = q;
    if (!b[3] || p * b[3] > b[2] * q)
        b[2] = p, b[3] = q;
}

FN void quad_row(Ctx *c, const int *vx, const int *vy, int y)   // one scanline of the quad
{
    long long b[4];                          // leftmost / rightmost edge crossing (q = 0: none yet)
    b[0] = b[1] = b[2] = b[3] = 0;
    for (int i = 0; i < 4; i++) {
        int ax = vx[i], ay = vy[i], bx = vx[(i + 1) & 3], by = vy[(i + 1) & 3];
        if (y < imin(ay, by) || y > imax(ay, by))
            continue;
        if (ay == by)                        // a flat edge counts with both ends
            widen(b, ax, 1), widen(b, bx, 1);
        else
            widen(b, (long long)ax * (by - ay) + (long long)(y - ay) * (bx - ax), by - ay);
    }
    if (!b[1])
        return;
    for (long long x = imax((int)half_up(b[0], b[1]), 0), xe = half_down(b[2], b[3]); x <= xe && x < c->w; x++)
        plot(c, x, y);
}

// ImagingDrawWideLine: a quad around the segment with Pillow's rounded corners, filled scanline by scanline
// from the rounded left crossing to the rounded right one (matches Pillow 12 on almost every pixel).
FN void draw_line(Ctx *c, int x0, int y0, int x1, int y1, int t)
{
    long long dx = x1 - x0, dy = y1 - y0, L2 = dx * dx + dy * dy;
    if (t <= 1 || L2 == 0) {
        thin_line(c, x0, y0, x1, y1);
        return;
    }
    int ku = t / 2, kd = (t - 1) / 2;        // ROUND_UP / ROUND_DOWN of (t - 1) / 2
    int dxmin = corner(kd, dy, L2), dxmax = corner(ku, dy, L2), dymin = corner(kd, dx, L2), dymax = corner(ku, dx, L2);
    int vx[4], vy[4];
    vx[0] = x0 - dxmin, vy[0] = y0 + dymax, vx[1] = x1 - dxmin, vy[1] = y1 + dymax;
    vx[2] = x1 + dxmax, vy[2] = y1 - dymin, vx[3] = x0 + dxmax, vy[3] = y0 - dymin;
    int ylo = imin(imin(vy[0], vy[1]), imin(vy[2], vy[3])), yhi = imax(imax(vy[0], vy[1]), imax(vy[2], vy[3]));
    for (int y = imax(ylo, 0); y <= yhi && y < c->h; y++)
        quad_row(c, vx, vy, y);
}

// bottom_seal: line joining the lowest CORE pixel of the left and right parts of the subject (outlines left
// open at the bottom); sets LINE. 0 = doesn't apply.
FN int bottom_seal(Ctx *c, int thick)
{
    long long mid = 39LL * (c->x0 + c->x1), gap = 10LL * c->S;   // x 78: cx = (x0 + x1) / 2, gap = 100 * S / 780
    int xl = -1, yl = 0, xr = -1, yr = 0, w = c->w;
    for (int y = c->y1; y >= c->y0 && (xl < 0 || xr < 0); y--)
        for (int x = c->x0; x <= c->x1; x++) {
            if (!(c->f[y * w + x] & CORE))
                continue;
            if (xl < 0 && 78LL * x < mid - gap)
                xl = x, yl = y;
            if (xr < 0 && 78LL * x > mid + gap)
                xr = x, yr = y;
        }
    if (xl < 0 || xr < 0)
        return 0;
    long long h = c->y1 - c->y0 + 1;
    if (10LL * imin(yl, yr) < 10LL * c->y0 + 7 * h || 20LL * iabs(yl - yr) > 3 * h)   // must be bottom strokes
        return 0;
    draw_line(c, xl, yl, xr, yr, thick);
    return 1;
}

// stops_leak: is the area the seal protects (BG & ~BG2) a subject body? It must be sizeable and its 2-step
// cross dilation must touch >= 3 separate 8-connected ink/colour features.
FN int stops_leak(Ctx *c)
{
    long long cnt = 0;
    int found = 0;
    bit_plane(c, c->a, BG | BG2, BG);
    for (int i = 0; i < c->n; i++)
        cnt += c->a[i];
    if (500 * cnt < c->n)                    // region.sum() < 0.002 * region.size
        return 0;
    dilate(c, c->a, c->b, 0);
    dilate(c, c->b, c->a, 0);
    for (int i = 0; i < c->n; i++)
        c->b[i] = (c->f[i] & (INK | COLORED)) != 0;
    fill_int(c->lab, c->n, 0);
    for (int i = 0; i < c->n && found < 3; i++) {
        if (!c->a[i] || !c->b[i] || c->lab[i])
            continue;
        found++;
        grow(c, c->b, 1, 1, 1, found, seed(c, i, found, 0));
    }
    return found >= 3;
}

FN void use_seal(Ctx *c, int thick)   // bg = bg_sealed, then peel bg-coloured line pixels next to it
{
    for (int i = 0; i < c->n; i++)
        c->f[i] = (unsigned char)((c->f[i] & ~BG) | (c->f[i] & BG2 ? BG : 0));
    for (int k = 0; k < thick; k++) {
        bit_plane(c, c->a, BG, BG);
        dilate(c, c->a, c->b, 0);
        for (int i = 0; i < c->n; i++)
            if (c->b[i] && (c->f[i] & (LINE | NEAR_BG)) == (LINE | NEAR_BG))
                c->f[i] |= BG;
    }
}

FN void ink_color(Ctx *c, int cnt)   // per-channel median of the CORE pixels, x2
{
    fill_int(c->hist, 768, 0);
    for (int i = 0; i < c->n; i++)
        if (c->f[i] & CORE)
            for (int k = 0; k < 3; k++)
                c->hist[256 * k + c->px[4 * i + k]]++;
    for (int k = 0; k < 3; k++)
        c->ink2[k] = median2(c->hist + 256 * k, 256, cnt);
}

// paint_gaps: pale pixels in closed outline gaps (CLOSED, not ink or colour) whose 8-connected piece touches
// BG (3x3) -> ink colour (truncated, as numpy assigns it into int16).
FN void paint_gaps(Ctx *c)
{
    bit_plane(c, c->a, BG, BG);
    dilate(c, c->a, c->b, 1);
    fill_int(c->lab, c->n, 0);
    for (int i = 0; i < c->n; i++) {
        if (!c->b[i] || c->lab[i] || (c->f[i] & (CLOSED | INK | COLORED)) != CLOSED)
            continue;
        int len = grow(c, c->f, CLOSED | INK | COLORED, CLOSED, 1, 1, seed(c, i, 1, 0));
        for (int k = 0; k < len; k++)
            for (int ch = 0; ch < 3; ch++)
                c->px[4 * c->q[k] + ch] = (unsigned char)(c->ink2[ch] / 2);
    }
}

// drop_small(~bg): 8-connected opaque pieces smaller than MIN_SPECK * (max(h, w) / 1000)^2 -> BG.
FN void drop_small(Ctx *c)
{
    long long m = imax(c->w, c->h);
    fill_int(c->lab, c->n, 0);
    for (int i = 0; i < c->n; i++) {
        if ((c->f[i] & BG) || c->lab[i])
            continue;
        int len = grow(c, c->f, BG, 0, 1, 1, seed(c, i, 1, 0));
        if (len * (1000000LL / MIN_SPECK) < m * m)
            for (int k = 0; k < len; k++)
                c->f[c->q[k]] |= BG;
    }
}

// soft_edge + compose: BG within reach of the subject gets alpha from its darkness, (top - lum - 10) /
// max(top - low - 10, 1) * 255 truncated (x6 here: top = bg mean, low = ink mean); BG takes the ink colour.
FN void soft_edge(Ctx *c)
{
    long long top6 = c->bg2[0] + c->bg2[1] + c->bg2[2], low6 = c->ink2[0] + c->ink2[1] + c->ink2[2];
    long long den = top6 - low6 - 60 > 6 ? top6 - low6 - 60 : 6, s2 = (long long)c->S * c->S;
    long long k2 = (long long)(REF_SIZE / EDGE_REACH) * (REF_SIZE / EDGE_REACH);   // reach = max(1, S / 260)
    for (int i = 0; i < c->n; i++)
        c->g[i] = c->f[i] & BG ? c->w + c->h : 0;
    edt(c, c->w, c->h);                      // squared distance to the nearest opaque pixel
    for (int i = 0; i < c->n; i++) {
        unsigned char *p = c->px + 4 * i;
        if (!(c->f[i] & BG)) {
            p[3] = 255;
            continue;
        }
        long long d2 = c->g[i], a = 0;
        if (d2 <= 1 || d2 * k2 <= s2) {
            long long num = top6 - 2 * (p[0] + p[1] + p[2]) - 60;
            a = num <= 0 ? 0 : num >= den ? 255 : 255 * num / den;
        }
        for (int k = 0; k < 3; k++)
            p[k] = (unsigned char)(c->ink2[k] / 2);
        p[3] = (unsigned char)a;
    }
}

// remove_background: px (opaque, flattened) -> cleaned BGRA in place; returns a status code.
FN int remove_background(Ctx *c, int seal)
{
    int st = estimate_background(c);
    if (st)
        return st;
    classify(c);
    int cnt = main_ink(c);                   // the outline, without dust, for measuring
    if (!cnt)
        return ST_NO_OUTLINE;
    int r = imax(1, (int)round_div((long long)SEAL_R * c->S, REF_SIZE));
    int thick = imax(1, (int)round_div((long long)SEAL_THICK * c->S, REF_SIZE));
    if (!carve_edt(c, r))
        return ST_INTERNAL;
    close_mask(c, r);
    int bg = flood_from_border(c, CLOSED | COLORED, BG);
    if (seal && bottom_seal(c, thick)) {
        int bg_sealed = flood_from_border(c, CLOSED | COLORED | LINE, BG2);
        if (stops_leak(c))
            use_seal(c, thick), bg = bg_sealed;
    }
    if (!bg)
        return ST_NO_BG;
    ink_color(c, cnt);
    paint_gaps(c);
    drop_small(c);                           // opaque specks -> background
    soft_edge(c);
    return ST_CLEANED;
}

// ---------- crop ----------

// crop_square's box: tight square around alpha > CROP_ALPHA content, round(3%) padding per side.
FN int crop_box(CutoutJob *j)
{
    int w = j->w, h = j->h, x0 = w, y0 = h, x1 = -1, y1 = -1;
    for (int y = 0; y < h; y++)
        for (int x = 0; x < w; x++)
            if (j->px[4 * ((long long)y * w + x) + 3] > CROP_ALPHA)
                x0 = imin(x0, x), x1 = imax(x1, x), y0 = imin(y0, y), y1 = imax(y1, y);
    if (x1 < 0)
        return ST_NOTHING;
    int bw = x1 + 1 - x0, bh = y1 + 1 - y0, m = imax(bw, bh);
    int side = m + 2 * (int)round_div((long long)CROP_PAD * m, 100);
    j->left = x0 - (side - bw) / 2;
    j->top = y0 - (side - bh) / 2;
    j->side = side;
    return 0;
}

FN int setup(Ctx *c, CutoutJob *j)   // carve the per-pixel planes from scratch; 0 = too small
{
    long long n = c->n;
    c->free = (unsigned char *)(((unsigned long long)j->scratch + 15) & ~15ULL);
    c->end = j->scratch + j->scratch_size;
    if (j->scratch_size < 16 || c->free > c->end)
        return 0;
    c->f = carve(c, n);
    c->a = carve(c, n);
    c->b = carve(c, n);
    c->lab = carve(c, 4 * n);
    c->q = carve(c, 4 * n);
    c->areas = carve(c, 4 * (n + 1));
    c->hist = carve(c, 4 * (768 + 512));
    return c->f && c->a && c->b && c->lab && c->q && c->areas && c->hist;
}

// Entry (CreateThread start routine): has_transparency -> crop only, else remove_background; then the crop box.
unsigned long __stdcall cutout_run(CutoutJob *j)
{
    Ctx c;
    int st = ST_INTERNAL;
    if (!j)
        return ST_INTERNAL;
    j->left = j->top = j->side = 0;
    if (j->px && j->scratch && j->w > 0 && j->h > 0 && (long long)j->w * j->h <= MAX_PIXELS) {
        c.px = j->px, c.w = j->w, c.h = j->h, c.n = j->w * j->h;
        if (has_transparency(&c))
            st = ST_TRANSPARENT;
        else if (setup(&c, j)) {
            flatten_on_white(&c);
            st = remove_background(&c, j->flags & 1);
        }
        if (st <= ST_TRANSPARENT && crop_box(j))
            st = ST_NOTHING;
    }
    j->status = st;
    return (unsigned long)st;
}
