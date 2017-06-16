#version 450 core
// Uses a fragment shader in order to run for every pixel in the image. Does dank raytracing with SVOs and shit.
// Yes, this is in the 'src' folder instead of some 'shaders' folder, because it is as much source code as any of the rest. This is where we do most of the ray tracing, and lighting, and material calculation - well, this and other shaders. This deserves to be in 'src'.
// GLSL is a language as much as anything else, although I do long for a future in which shaders are written in whatever language I like. (Ruby Shading Language - RSL! I would get behind that.)

out vec4 fragColor;

in vec3 ray; // View ray direction

layout (location = 1) uniform vec3 cameraPosition; // Camera position. I like to think my naming is very creative

layout (std430, binding = 0) buffer stuff {
  uint octree[];
};

struct Ray {
  vec3 o;
  vec3 d;
} view;

struct Node {
  bool children[8];
  bool leaf;
  bool empty;
  uint pointer;
  bool inside;
  vec3 min, max;
  uint matID;
} root;

struct INode {
  bool exists;
  Node parent;
  int pos;
  vec3 min, max;
};

// Utility function to get *pos* for `decode`
uvec3 getPos (int i) {  //   0  1    xx
  switch (i) {          //   2  3    y  z
    case 0:             //           y   z
      return uvec3(0);  //   4  5
    case 1:             //   6  7
      return uvec3(1, 0, 0);
    case 2:
      return uvec3(0, 1, 0);
    case 3:
      return uvec3(1, 1, 0);
    case 4:
      return uvec3(0, 0, 1);
    case 5:
      return uvec3(1, 0, 1);
    case 6:
      return uvec3(0, 1, 1);
    case 7:
      return uvec3(1, 1, 1);
    default:
      return uvec4(0);
  }
}

// We store our nodes in `octree` using bitmasks. First 8 bits = childmask, then child pointer. Child pointer of 0 means leaf, no children means empty. DAG upgrade coming soon.
Node decode (uint data, Node parent, uvec3 pos) {
  Node n;
  uint datas = data;
  uint mask;
  n.empty = true;

  for (int i = 0; i < 8; i++) { // First 8 bits to childmask
    mask = 1 << (31-i);
    n.children[i] = (mask & datas) == mask;
    datas &= ~mask;
    if (n.children[i]) {
      n.empty = false;
    }
  }

  n.pointer = datas; // Twenty-four bits to pointers. When we upgrade to DAGs we'll have thirty-two for pointers.
  if (n.pointer == 0) {
    n.leaf = true;
  }

  n.min.x = mix(parent.min.x, parent.max.x, 0.5 * pos.x);
  n.max.x = mix(parent.min.x, parent.max.x, 0.5*pos.x+0.5);
  n.min.y = mix(parent.min.y, parent.max.y, 0.5 * pos.y);
  n.max.y = mix(parent.min.y, parent.max.y, 0.5*pos.y+0.5);
  n.min.z = mix(parent.min.z, parent.max.z, 0.5 * pos.z);
  n.max.z = mix(parent.min.z, parent.max.z, 0.5*pos.z+0.5);

  n.inside = true;

  return n;
}

INode child (Node parent, int posI) {
  if (parent.children[posI]) {
    INode n;
    n.parent = parent;
    n.pos = posI;
    uvec3 pos = getPos(posI);

    n.min.x = mix(parent.min.x, parent.max.x, 0.5 * pos.x);
    n.max.x = mix(parent.min.x, parent.max.x, 0.5*pos.x+0.5);
    n.min.y = mix(parent.min.y, parent.max.y, 0.5 * pos.y);
    n.max.y = mix(parent.min.y, parent.max.y, 0.5*pos.y+0.5);
    n.min.z = mix(parent.min.z, parent.max.z, 0.5 * pos.z);
    n.max.z = mix(parent.min.z, parent.max.z, 0.5*pos.z+0.5);

    n.exists = true;
    return n;
  }
  INode n;
  n.exists = false;
  return n;
}

Node decode (uint data, Node parent, int pos) { // Overloading
  return decode(data, parent, getPos(pos));
}

bool q = false; // BUG checking mechanism, remove

// Find lowest node *p* is in
INode find (vec3 p) {
  INode current = child(root, 0);
  uint texel;
  do {
    for (int i = 0; i < 8; i++) {
      current = child(root, i);
      if (current.exists) { // If this node exists
        if (all(greaterThan(p, current.min)) && all(greaterThan(current.max, p))) { // In this node
          break;
        }
      }
    }
    return current;
  }while (!current.parent.leaf);

  return current;
}

struct Intersection {
  INode result;
  vec3 hitpoint;
  bool hit;
};

// Sparse Voxel Octrees combined with A Fast Grid Traversal Algorithm for Ray Tracing
Intersection trace (Ray r) {
  Intersection result;
  INode current = find(r.o); // Find lowest node ro is in
  ivec3 stepV = ivec3(sign(r.d));
  float size = current.max.x - current.min.x;
  vec3 pos = r.o;

  for (; current.exists && !current.parent.leaf; size = current.max.x - current.min.x) {
    // Advance
    vec3 delta = size / r.d; // Length diagonally of the voxel
    vec3 tMax = delta * (1.0 - fract(pos / size)); // The distance to the next voxel along r.d
    pos += min(min(tMax.x, tMax.y), tMax.z); // Go to the edge of the next voxel. No branches here!
    current = find(pos); // kd-restart. Seems slower, but I'm pretty sure on GPUs it's actually faster. Our `find` function better be fast, though
  }
  if (current.exists) {
    result.result = current;
    result.hitpoint = pos;
    result.hit = true; // We hit!
    return result;
  }

  result.hit = false; // We didn't hit. *result* and *hitpoint* are NULL, so always check if your `Intersection`'s *hit* is true or false before accessing the rest.
  return result;
}

void main () {
  view.o = cameraPosition;
  view.d = ray;
  Node rootRoot;
  rootRoot.min = vec3(-10.0, -10.0, -10.0);
  rootRoot.max = vec3(10.0, 10.0, 10.0);
  root = decode(octree[0], rootRoot, 0);

  root.min = vec3(-10.0, -10.0, -10.0);
  root.max = vec3(10.0, 10.0, 10.0);

  Intersection i = trace(view);
  fragColor = !i.hit ? vec4(0) : vec4(i.hitpoint, 1.0);
}

// We're going to store material data in main memory and then put in onto the GPU as needed, evaluating in another shader a la Laine, Aila, Megakernels Considered Harmful: Wavefront Path Tracing on GPUs
