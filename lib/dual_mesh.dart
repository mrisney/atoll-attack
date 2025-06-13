// dual_mesh.dart
import 'dart:math' as math;
import 'dart:typed_data';

class Point2D {
  final double x, y;
  const Point2D(this.x, this.y);

  double distanceTo(Point2D other) {
    return math.sqrt(math.pow(x - other.x, 2) + math.pow(y - other.y, 2));
  }

  Point2D operator +(Point2D other) => Point2D(x + other.x, y + other.y);
  Point2D operator -(Point2D other) => Point2D(x - other.x, y - other.y);
  Point2D operator *(double scalar) => Point2D(x * scalar, y * scalar);

  List<double> toList() => [x, y];
}

// Simplified Delaunator result structure
class DelaunatorResult {
  final Int32List triangles;
  final Int32List halfedges;
  final List<Point2D> coords;

  DelaunatorResult({
    required this.triangles,
    required this.halfedges,
    required this.coords,
  });
}

// Port of the TriangleMesh class from TypeScript
class TriangleMesh {
  // Public data
  late int numSides;
  late int numSolidSides;
  late int numRegions;
  late int numSolidRegions;
  late int numTriangles;
  late int numSolidTriangles;
  late int numBoundaryRegions;

  // Internal data
  late Int32List _halfedges;
  late Int32List _triangles;
  late Int32List _s_of_r;
  late List<Point2D> _vertex_r;
  late List<Point2D> _vertex_t;

  // Static helper methods
  static int t_from_s(int s) => s ~/ 3;
  static int s_prev_s(int s) => (s % 3 == 0) ? s + 2 : s - 1;
  static int s_next_s(int s) => (s % 3 == 2) ? s - 2 : s + 1;

  TriangleMesh.fromDelaunator({
    required List<Point2D> points,
    required DelaunatorResult delaunator,
    int numBoundaryPoints = 0,
    int numSolidSides = 0,
  }) {
    this.numBoundaryRegions = numBoundaryPoints;
    this.numSolidSides = numSolidSides;
    _vertex_r = points;
    _triangles = delaunator.triangles;
    _halfedges = delaunator.halfedges;
    _vertex_t = [];
    _update();
  }

  void _update() {
    numSides = _triangles.length;
    numRegions = _vertex_r.length;
    numSolidRegions = numRegions - 1; // Assuming ghost structure
    numTriangles = numSides ~/ 3;
    numSolidTriangles = numSolidSides ~/ 3;

    // Extend vertex_t array if needed
    while (_vertex_t.length < numTriangles) {
      _vertex_t.add(Point2D(0, 0));
    }

    // Construct index for finding sides connected to a region
    _s_of_r = Int32List(numRegions);
    for (int s = 0; s < _triangles.length; s++) {
      int endpoint = _triangles[s_next_s(s)];
      if (_s_of_r[endpoint] == 0 || _halfedges[s] == -1) {
        _s_of_r[endpoint] = s;
      }
    }

    // Construct triangle centroids
    for (int s = 0; s < _triangles.length; s += 3) {
      int t = s ~/ 3;
      Point2D a = _vertex_r[_triangles[s]];
      Point2D b = _vertex_r[_triangles[s + 1]];
      Point2D c = _vertex_r[_triangles[s + 2]];

      if (is_ghost_s(s)) {
        // Ghost triangle center is outside the unpaired side
        double dx = b.x - a.x;
        double dy = b.y - a.y;
        double scale = 10 / math.sqrt(dx * dx + dy * dy);
        _vertex_t[t] = Point2D(
          0.5 * (a.x + b.x) + dy * scale,
          0.5 * (a.y + b.y) - dx * scale,
        );
      } else {
        // Solid triangle center is at the centroid
        _vertex_t[t] = Point2D(
          (a.x + b.x + c.x) / 3,
          (a.y + b.y + c.y) / 3,
        );
      }
    }
  }

  // Add ghost structure to complete the mesh
  static MeshInitializer addGhostStructure(MeshInitializer init) {
    final triangles = init.delaunator.triangles;
    final halfedges = init.delaunator.halfedges;
    final numSolidSides = triangles.length;

    int numUnpairedSides = 0;
    int firstUnpairedEdge = -1;
    Map<int, int> s_unpaired_r = {};

    for (int s = 0; s < numSolidSides; s++) {
      if (halfedges[s] == -1) {
        numUnpairedSides++;
        s_unpaired_r[triangles[s]] = s;
        firstUnpairedEdge = s;
      }
    }

    final r_ghost = init.points.length;
    List<Point2D> newPoints = List.from(init.points)
      ..add(Point2D(double.nan, double.nan));

    Int32List r_newstart_s = Int32List(numSolidSides + 3 * numUnpairedSides);
    r_newstart_s.setRange(0, numSolidSides, triangles);

    Int32List s_newopposite_s = Int32List(numSolidSides + 3 * numUnpairedSides);
    s_newopposite_s.setRange(0, numSolidSides, halfedges);

    int s = firstUnpairedEdge;
    for (int i = 0; i < numUnpairedSides; i++) {
      // Construct a ghost side for s
      int s_ghost = numSolidSides + 3 * i;
      s_newopposite_s[s] = s_ghost;
      s_newopposite_s[s_ghost] = s;
      r_newstart_s[s_ghost] = r_newstart_s[s_next_s(s)];

      // Construct the rest of the ghost triangle
      r_newstart_s[s_ghost + 1] = r_newstart_s[s];
      r_newstart_s[s_ghost + 2] = r_ghost;

      int k = numSolidSides + (3 * i + 4) % (3 * numUnpairedSides);
      s_newopposite_s[s_ghost + 2] = k;
      s_newopposite_s[k] = s_ghost + 2;

      // Move to next unpaired side
      s = s_unpaired_r[r_newstart_s[s_next_s(s)]] ?? firstUnpairedEdge;
    }

    return MeshInitializer(
      points: newPoints,
      delaunator: DelaunatorResult(
        triangles: r_newstart_s,
        halfedges: s_newopposite_s,
        coords: newPoints,
      ),
      numBoundaryPoints: init.numBoundaryPoints,
      numSolidSides: numSolidSides,
    );
  }

  // Accessors
  double x_of_r(int r) => _vertex_r[r].x;
  double y_of_r(int r) => _vertex_r[r].y;
  double x_of_t(int t) => _vertex_t[t].x;
  double y_of_t(int t) => _vertex_t[t].y;
  Point2D pos_of_r(int r) => _vertex_r[r];
  Point2D pos_of_t(int t) => _vertex_t[t];

  int r_begin_s(int s) => _triangles[s];
  int r_end_s(int s) => _triangles[s_next_s(s)];

  int t_inner_s(int s) => t_from_s(s);
  int t_outer_s(int s) => t_from_s(_halfedges[s]);

  int s_opposite_s(int s) => _halfedges[s];

  List<int> s_around_t(int t) => [3 * t, 3 * t + 1, 3 * t + 2];

  List<int> r_around_t(int t) {
    return [_triangles[3 * t], _triangles[3 * t + 1], _triangles[3 * t + 2]];
  }

  List<int> t_around_t(int t) {
    return [t_outer_s(3 * t), t_outer_s(3 * t + 1), t_outer_s(3 * t + 2)];
  }

  List<int> s_around_r(int r) {
    final s0 = _s_of_r[r];
    int incoming = s0;
    List<int> result = [];

    do {
      result.add(_halfedges[incoming]);
      int outgoing = s_next_s(incoming);
      incoming = _halfedges[outgoing];
    } while (incoming != -1 && incoming != s0);

    return result;
  }

  List<int> r_around_r(int r) {
    final s0 = _s_of_r[r];
    int incoming = s0;
    List<int> result = [];

    do {
      result.add(r_begin_s(incoming));
      int outgoing = s_next_s(incoming);
      incoming = _halfedges[outgoing];
    } while (incoming != -1 && incoming != s0);

    return result;
  }

  List<int> t_around_r(int r) {
    final s0 = _s_of_r[r];
    int incoming = s0;
    List<int> result = [];

    do {
      result.add(t_from_s(incoming));
      int outgoing = s_next_s(incoming);
      incoming = _halfedges[outgoing];
    } while (incoming != -1 && incoming != s0);

    return result;
  }

  int r_ghost() => numRegions - 1;
  bool is_ghost_s(int s) => s >= numSolidSides;
  bool is_ghost_r(int r) => r == numRegions - 1;
  bool is_ghost_t(int t) => is_ghost_s(3 * t);
  bool is_boundary_s(int s) => is_ghost_s(s) && (s % 3 == 0);
  bool is_boundary_r(int r) => r < numBoundaryRegions;
}

// Helper class for mesh initialization
class MeshInitializer {
  final List<Point2D> points;
  final DelaunatorResult delaunator;
  final int numBoundaryPoints;
  final int numSolidSides;

  MeshInitializer({
    required this.points,
    required this.delaunator,
    this.numBoundaryPoints = 0,
    this.numSolidSides = 0,
  });
}

// Boundary point generation helpers
class BoundaryGenerator {
  static List<Point2D> generateInteriorBoundaryPoints({
    required double left,
    required double top,
    required double width,
    required double height,
    required double boundarySpacing,
  }) {
    const epsilon = 1e-4;
    const curvature = 1.0;

    int W = ((width - 2 * curvature) / boundarySpacing).ceil();
    int H = ((height - 2 * curvature) / boundarySpacing).ceil();
    List<Point2D> points = [];

    // Top and bottom
    for (int q = 0; q < W; q++) {
      double t = q / W;
      double dx = (width - 2 * curvature) * t;
      double dy = epsilon + curvature * 4 * math.pow(t - 0.5, 2);

      points.add(Point2D(left + curvature + dx, top + dy));
      points.add(Point2D(left + width - curvature - dx, top + height - dy));
    }

    // Left and right
    for (int r = 0; r < H; r++) {
      double t = r / H;
      double dy = (height - 2 * curvature) * t;
      double dx = epsilon + curvature * 4 * math.pow(t - 0.5, 2);

      points.add(Point2D(left + dx, top + height - curvature - dy));
      points.add(Point2D(left + width - dx, top + curvature + dy));
    }

    return points;
  }

  static List<Point2D> generateExteriorBoundaryPoints({
    required double left,
    required double top,
    required double width,
    required double height,
    required double boundarySpacing,
  }) {
    const curvature = 1.0;
    final diagonal = boundarySpacing / math.sqrt(2);
    List<Point2D> points = [];

    int W = ((width - 2 * curvature) / boundarySpacing).ceil();
    int H = ((height - 2 * curvature) / boundarySpacing).ceil();

    // Top and bottom
    for (int q = 0; q < W; q++) {
      double t = q / W;
      double dx = (width - 2 * curvature) * t + boundarySpacing / 2;

      points.add(Point2D(left + dx, top - diagonal));
      points.add(Point2D(left + width - dx, top + height + diagonal));
    }

    // Left and right
    for (int r = 0; r < H; r++) {
      double t = r / H;
      double dy = (height - 2 * curvature) * t + boundarySpacing / 2;

      points.add(Point2D(left - diagonal, top + height - dy));
      points.add(Point2D(left + width + diagonal, top + dy));
    }

    // Corners
    points.add(Point2D(left - diagonal, top - diagonal));
    points.add(Point2D(left + width + diagonal, top - diagonal));
    points.add(Point2D(left - diagonal, top + height + diagonal));
    points.add(Point2D(left + width + diagonal, top + height + diagonal));

    return points;
  }
}
