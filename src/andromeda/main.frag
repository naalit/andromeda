#version 450 core
// Uses a fragment shader in order to run for every pixel in the image. Does dank raytracing with SVOs and shit.
// Yes, this is in the 'src' folder instead of some 'shaders' folder, because it is as much source code as any of the rest. This is where we do most of the ray tracing, and lighting, and material calculation - well, this and other shaders. This deserves to be in 'src'.
// GLSL is a language as much as anything else, although I do long for a future in which shaders are written in whatever language I like. (Ruby Shading Language - RSL! I would get behind that.)

// TODO: Switch to directed acyclic graphs instead of octres

out vec4 fragColor;

in vec3 ray; // View ray direction

layout (location = 1) uniform vec3 cameraPosition; // Camera position. I like to think my naming is very creative

layout (std430, binding = 0) buffer stuff {
  uint octree[]; // The entire scene
};

const int MAX_RAY_STEPS = 164;

struct Ray {
  vec3 o;
  vec3 d;
} view;

struct Intersection { // For returning from `trace`
  bool hit;
  vec3 p;
  int pointer; // Material pointer later
  int idx;
};

struct Node { // For returning data from `find`
  int idx;
  int pos;
  uint data;
  bool empty;
  int lvl; // Octree level
};

bool bit (int bitNumber, uint data) { // Check if bit `bitNumber` of `data` is on or off
  uint mask = uint(exp2(bitNumber)); // pow(2, bitNumber)
  return (mask & data) == data;
}

int getPos (vec3 vpos) { // Get scalar position from point in parent centered at the origin
  //return 2;
  // Remove 0's
  float epsilon = 0.000001; // Probably not actual epsilon, do that later to support smaller voxels
  vec3 vpos2 = vec3(max(vpos.x, epsilon), max(vpos.y, epsilon), max(vpos.z, epsilon));

  // Map sign of each component to a bit
  int r = 0;
  r += int(max(sign(vpos2.x), 0)); // Bit 1
  r += int(max(sign(vpos2.y), 0) * 2); // Bit 2
  r += int(max(sign(vpos2.z), 0) * 4); // Bit 3
  return r;
}

float max3 (vec3 v) { // Finds the largest component of a vec3
  return max (max (v.x, v.y), v.z);
}

float min3 (vec3 v) { // Finds the smallest component of a vec3
  return min (min (v.x, v.y), v.z);
}

vec3 vmax (vec3 pos, int scale) { // Get max from pos & scale
  return vec3(0); // TODO: Implement
} // TODO: Make a similar function 'vmin'

const int smax = 16; // Maximum number of octree levels. Also stack size, so make as small as possible without losing information in the octree

Intersection trace (Ray ray) {
  // Based on Efficient Sparse Voxel Octrees - Laine and Karras
  int parent = 0;
  int idx = 0;
  int scale = smax;
  int[smax] stack;
  vec3 oneOverDCoef = 1/ray.d;
  vec3 pDCoef = -ray.o/ray.d; // tx(x) = oneOverDCoef * x + pDCoef
  float tMin = max3(-oneOverDCoef + pDCoef); // Scene goes from [-1, -1, -1] to [1, 1, 1]
  float tMax = min3(oneOverDCoef + pDCoef);
  float h = tMax;
  vec3 pos = vec3(0);
  vec3 oldpos = pos;
  float tcMin;
  float tcMax;

  // Determine child index
  bvec3 tme = bvec3(pDCoef.x == tMin, pDCoef.y == tMin, pDCoef.z == tMin); // Which axis has the smallest t-value at the origin?
  if(tme.x) idx += 1; // exp2(0)
  if(tme.y) idx += 2; // exp2(1)
  if(tme.z) idx += 4; // exp2(2)

  // Determine pos and scale for child voxel
  pos.x = tme.x ? 0.5 : -0.5;
  pos.z = tme.y ? 0.5 : -0.5;
  pos.z = tme.z ? 0.5 : -0.5;
  scale--;

  for (int abcdefghi = 0; abcdefghi < 64; abcdefghi++) { // So we don't get trapped in an infinite loop. Will remove later
    tcMin = max3(oneOverDCoef * (0.5 * exp2(scale - smax)) + pDCoef);
    tcMin = min3(oneOverDCoef * (1.5 * exp2(scale - smax)) + pDCoef); // tMin and tMax in current voxel

    if(bit(idx, octree[parent]) && tMin <= tMax) {
      //if (bit(idx + 8, octree[parent])) break;
      if (tcMin <= tcMax) {
        if (bit(idx + 8, octree[parent])) break; // If leaf, break
        if (tcMax < h) stack[scale] = parent; // See ESVO paper
        h = tcMax;

        // Get parent index
        parent = int(octree[parent] << 16 + bitCount(parent << (24+idx))); // (Child pointer) + (Number of existing children <= spos)

        // Select child voxel
        tme = bvec3(pDCoef.x == tMin, pDCoef.y == tMin, pDCoef.z == tMin);
        idx = 0;
        if(tme.x) idx += 1; // exp2(0)
        if(tme.y) idx += 2; // exp2(1)
        if(tme.z) idx += 4; // exp2(2)

        // Determine pos and scale for child voxel
        pos.x = tme.x ? 0.5 : -0.5;
        pos.z = tme.y ? 0.5 : -0.5;
        pos.z = tme.z ? 0.5 : -0.5;
        scale--;

        tMax = tcMax;
        tMin = tcMin;
        continue;
      }
    }
    oldpos = pos;
    // TODO: Continue implementation here along Efficient Sparse Voxel Octrees
  }
}

void main () {
  view.o = cameraPosition;
  view.d = ray;

  Intersection i = trace(view);
  fragColor = !i.hit ? vec4(0) : vec4(1.0);
}

// OLD TRAVERSAL CODE (copied from supp. on Efficient Sparse Voxel Octrees):
/*
Ray r = ray; // Copy ray for local modification
const int maxScale = 23; // Maximum scale
const float epsilon = exp2(-maxScale);

uvec2 stack[maxScale + 1]; // Stack of parents

// Lose small ray direction components to avoid dividing by 0

if (abs(r.d.x) < epsilon) r.d.x = copysign(epsilon, r.d.x);
if (abs(r.d.y) < epsilon) r.d.y = copysign(epsilon, r.d.y);
if (abs(r.d.z) < epsilon) r.d.z = copysign(epsilon, r.d.z);

// Precompute coefficients of tx(x), ty(y), and tz(z).
// The octree is assumed to reside at coordinates [1, 2].
// See _Efficient Sparse Voxel Octrees: Analysis, Extensions and Implementation_ by Laine and Karras

float txCoef = 1. / -abs(r.d.x);
float tyCoef = 1. / -abs(r.d.y);
float tzCoef = 1. / -abs(r.d.z);

float txBias = txCoef * r.o.x;
float tyBias = tyCoef * r.o.y;
float tzBias = tzCoef * r.o.z;

// Select octant mask to mirror the coordinate system so that ray direction is negative along each axis

int octantMask = 7;
if (r.d.x > 0.) octantMask ^= 1, txBias = 3. * txCoef - txBias;
if (r.d.y > 0.) octantMask ^= 1, tyBias = 3. * tyCoef - tyBias;
if (r.d.z > 0.) octantMask ^= 1, tzBias = 3. * tzCoef - tzBias;

// Initialize the active span of t values

float tMin = max(max(2. * txCoef - txBias, 2. * tyCoef - tyBias), 2. * tzCoef - tzBias);
float tMax = min(min(txCoef - txBias, tyCoef - tyBias), tzCoef - tzBias);
float h = tMax;
tMin = max(tMin, 0.);
tMax = min(tMax, 1.);

// Initialize the current voxel to the first child of the root

int parent = 0;
uint children = 0; // Child descriptor; invalid for now
int idx = 0;
vec3 pos = vec3(1.);
int scale = maxScale - 1;
float scaleExp2 = 0.5; // exp2(scale - maxScale)

if (1.5f * txCoef - txBias > tMin) idx ^= 1, pos.x = 1.5;
if (1.5f * tyCoef - tyBias > tMin) idx ^= 1, pos.y = 1.5;
if (1.5f * tzCoef - tzBias > tMin) idx ^= 1, pos.z = 1.5;

// Traverse voxels along the ray as long as the current voxel stays within the octree

while (scale < maxScale) {
  // Fetch child descriptor unless it is already valid

  if (children == 0)
    children = octree[parent];

  // Determine maximum t value of the cube by evaluating tx, ty, and tz at its corner

  float txCorner = pos.x * txCoef -txBias;
  float tyCorner = pos.y * tyCoef -tyBias;
  float tzCorner = pos.z * tzCoef -tzBias;
  float tcMax = min(min(txCorner, tyCorner), tzCorner);

  // Process voxel if the corresponding bit in valid mask is set and the active t span is nonempty

  int childShift = idx ^ octantMask; // Permute child slots based on the mirroring
  int childMasks = int(children) << childShift;
  if ((childMasks & 0x8000) != 0 && tMin <= tMax) {
    // TODO: Terminate if the voxel is small enough (LOD)

    // INTERSECT
    // Intersect active t span with cube and evaluate tx, ty, and tz at center of voxel

    float tvMax = min(tMax, tcMax);
    float halfV = scaleExp2 * 0.5;
    float txCenter = halfV * txCoef + txCorner;
    float tyCenter = halfV * tyCoef + tyCorner;
    float tzCenter = halfV * tzCoef + tzCorner;

    // Contours would go here, but we're not doing that

    // Descend to the first child if the resulting t span is nonempty

    if (tMin <= tvMax) {
      // Terminate if the corresponding bit in the leaf mask is set

      if ((childMasks & 0x0080) == 0)
        break; // at tMin

      // PUSH
      // Write current parent to the stack

      if (tcMax < h)
        stack[scale] = uvec2(parent, floatBitsToUint(tMax));
      h = tcMax;

      // Find child descriptor corresponding to the current voxel

      uint ofs = children >> 17; // child pointer
//        if ((children & uint(0x10000)) != 0) // far
//          ofs = octree[ofs * 2]; // far pointer
      ofs += bitCount(childMasks & 0x7F);
      parent += int(ofs * 2);

      // Select child voxel that the ray enters first

      idx = 0;
      scale--;
      scaleExp2 = halfV;

      if (txCenter > tMin) idx ^= 1, pos.x += scaleExp2;
      if (tyCenter > tMin) idx ^= 2, pos.y += scaleExp2;
      if (tzCenter > tMin) idx ^= 4, pos.z += scaleExp2;

      // Update active t span and invalidate cached child descriptors

      tMax = tvMax;
      children = 0;
      continue;
    }
  }

  // ADVANCE
  // Step along the ray

  int stepMask = 0;
  if (txCorner <= tcMax) stepMask ^= 1, pos.x -= scaleExp2;
  if (tyCorner <= tcMax) stepMask ^= 2, pos.y -= scaleExp2;
  if (tzCorner <= tcMax) stepMask ^= 4, pos.z -= scaleExp2;

  // Update active t span and flip bits of the child slot index

  tMin = tcMax;
  idx ^= stepMask;

  // Proceed with pop if the bit flips disagree with the ray direction

  if ((idx & stepMask) != 0) {
    // POP
    // Find the highest differing bit between the two positions

    uint differingBits = 0;
    if ((stepMask & 1) != 0) differingBits |= floatBitsToUint(pos.x) + floatBitsToUint(scaleExp2);
    if ((stepMask & 2) != 0) differingBits |= floatBitsToUint(pos.y) + floatBitsToUint(scaleExp2);
    if ((stepMask & 4) != 0) differingBits |= floatBitsToUint(pos.z) + floatBitsToUint(scaleExp2);
    scale = (floatBitsToInt(float(differingBits)) >> 23) - 127; // position of the highest bit
    scaleExp2 = intBitsToFloat((scale - maxScale + 127) << 23); // exp2(scale - maxScale)

    // Restore parent voxel from the stack

    uvec2 stackEntry = stack[scale];
    parent = int(stackEntry.x);
    tMax = uintBitsToFloat(stackEntry.y);

    // Round cube position and extract child slot index

    int shx = floatBitsToInt(pos.x) >> scale;
    int shy = floatBitsToInt(pos.y) >> scale;
    int shz = floatBitsToInt(pos.z) >> scale;
    pos.x = intBitsToFloat(shx << scale);
    pos.y = intBitsToFloat(shy << scale);
    pos.z = intBitsToFloat(shz << scale);
    idx = (shx & 1) | ((shy & 1) << 1) | ((shz & 1) << 2);

    // Prevent same parent from being stored again and invalidate cached child descriptor

    h = 0.;
    children.x = 0;
  }
}

// Indicate miss if outside the octree

if (scale >= maxScale)
  tMin = 2.;

// Undo mirroring of the coordinate system

if ((octantMask & 1) == 0) pos.x = 3. - scaleExp2 - pos.x;
if ((octantMask & 2) == 0) pos.y = 3. - scaleExp2 - pos.y;
if ((octantMask & 4) == 0) pos.z = 3. - scaleExp2 - pos.z;

// Output results

Intersection i;
i.t = tMin;
i.pos.x = min(max(r.o.x + tMin * r.d.x, pos.x + epsilon), pos.x + scaleExp2 - epsilon);
i.pos.y = min(max(r.o.y + tMin * r.d.y, pos.y + epsilon), pos.y + scaleExp2 - epsilon);
i.pos.z = min(max(r.o.z + tMin * r.d.z, pos.z + epsilon), pos.z + scaleExp2 - epsilon);
i.pointer = parent;
i.idx = idx ^ octantMask ^ 7;
i.scale = scale;
return i;
*/
