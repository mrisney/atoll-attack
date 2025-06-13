// delaunay.dart
import 'dart:math' as math;
import 'dart:typed_data';
import 'dual_mesh.dart';

class DelaunayTriangulation {
  final List<Point2D> points;
  late Int32List triangles;
  late Int32List halfedges;

  DelaunayTriangulation(this.points) {
    _triangulate();
  }

  void _triangulate() {
    if (points.length < 3) {
      triangles = Int32List(0);
      halfedges = Int32List(0);
      return;
    }

    // Sort points by x-coordinate for better performance
    List<int> ids = List.generate(points.length, (i) => i);
    ids.sort((i, j) => points[i].x.compareTo(points[j].x));

    // Create super-triangle
    double minX = double.infinity, minY = double.infinity;
    double maxX = double.negativeInfinity, maxY = double.negativeInfinity;

    for (final p in points) {
      if (p.x < minX) minX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.x > maxX) maxX = p.x;
      if (p.y > maxY) maxY = p.y;
    }

    double dx = maxX - minX;
    double dy = maxY - minY;
    double deltaMax = math.max(dx, dy);
    double midx = (minX + maxX) / 2;
    double midy = (minY + maxY) / 2;

    // Create super-triangle vertices
    Point2D p0 = Point2D(midx - 20 * deltaMax, midy - deltaMax);
    Point2D p1 = Point2D(midx, midy + 20 * deltaMax);
    Point2D p2 = Point2D(midx + 20 * deltaMax, midy - deltaMax);

    // Initialize with super-triangle
    List<Point2D> vertices = List.from(points)..addAll([p0, p1, p2]);
    List<Triangle> triangleList = [
      Triangle(points.length, points.length + 1, points.length + 2)
    ];

    // Bowyer-Watson algorithm
    for (int i in ids) {
      Point2D p = points[i];
      List<Edge> polygon = [];

      // Find bad triangles (containing the point in circumcircle)
      List<Triangle> badTriangles = [];
      for (Triangle t in triangleList) {
        if (_inCircumcircle(p, vertices[t.a], vertices[t.b], vertices[t.c])) {
          badTriangles.add(t);
        }
      }

      // Find boundary of polygonal hole
      for (Triangle t in badTriangles) {
        Edge ab = Edge(t.a, t.b);
        Edge bc = Edge(t.b, t.c);
        Edge ca = Edge(t.c, t.a);

        if (!_isSharedEdge(ab, badTriangles)) polygon.add(ab);
        if (!_isSharedEdge(bc, badTriangles)) polygon.add(bc);
        if (!_isSharedEdge(ca, badTriangles)) polygon.add(ca);
      }

      // Remove bad triangles
      triangleList.removeWhere((t) => badTriangles.contains(t));

      // Re-triangulate the polygonal hole
      for (Edge edge in polygon) {
        triangleList.add(Triangle(edge.a, edge.b, i));
      }
    }

    // Remove triangles with super-triangle vertices
    triangleList.removeWhere((t) =>
        t.a >= points.length || t.b >= points.length || t.c >= points.length);

    // Build triangles and halfedges arrays
    _buildArrays(triangleList);
  }

  void _buildArrays(List<Triangle> triangleList) {
    triangles = Int32List(triangleList.length * 3);
    halfedges = Int32List(triangleList.length * 3);

    // Initialize halfedges to -1
    for (int i = 0; i < halfedges.length; i++) {
      halfedges[i] = -1;
    }

    // Build triangles array
    for (int i = 0; i < triangleList.length; i++) {
      Triangle t = triangleList[i];
      triangles[i * 3] = t.a;
      triangles[i * 3 + 1] = t.b;
      triangles[i * 3 + 2] = t.c;
    }

    // Build halfedges connectivity
    Map<String, int> edgeMap = {};

    for (int t = 0; t < triangleList.length; t++) {
      for (int i = 0; i < 3; i++) {
        int s = t * 3 + i;
        int a = triangles[s];
        int b = triangles[s == t * 3 + 2 ? t * 3 : s + 1];

        String key1 = '$a,$b';
        String key2 = '$b,$a';

        if (edgeMap.containsKey(key2)) {
          int s2 = edgeMap[key2]!;
          halfedges[s] = s2;
          halfedges[s2] = s;
        } else {
          edgeMap[key1] = s;
        }
      }
    }
  }

  bool _inCircumcircle(Point2D p, Point2D a, Point2D b, Point2D c) {
    double ax = a.x - p.x;
    double ay = a.y - p.y;
    double bx = b.x - p.x;
    double by = b.y - p.y;
    double cx = c.x - p.x;
    double cy = c.y - p.y;

    double ap = ax * ax + ay * ay;
    double bp = bx * bx + by * by;
    double cp = cx * cx + cy * cy;

    return ax * (by * cp - bp * cy) -
            ay * (bx * cp - bp * cx) +
            ap * (bx * cy - by * cx) <
        0;
  }

  bool _isSharedEdge(Edge edge, List<Triangle> triangles) {
    int count = 0;
    for (Triangle t in triangles) {
      if ((t.a == edge.a && t.b == edge.b) ||
          (t.b == edge.a && t.a == edge.b) ||
          (t.b == edge.a && t.c == edge.b) ||
          (t.c == edge.a && t.b == edge.b) ||
          (t.c == edge.a && t.a == edge.b) ||
          (t.a == edge.a && t.c == edge.b)) {
        count++;
      }
    }
    return count > 1;
  }

  DelaunatorResult toDelaunatorResult() {
    return DelaunatorResult(
      triangles: triangles,
      halfedges: halfedges,
      coords: points,
    );
  }
}

class Triangle {
  final int a, b, c;
  Triangle(this.a, this.b, this.c);
}

class Edge {
  final int a, b;
  Edge(this.a, this.b);
}

// Voronoi diagram generation from Delaunay triangulation
class VoronoiDiagram {
  final TriangleMesh mesh;
  late List<List<Point2D>> regions;
  late List<Point2D> circumcenters;

  VoronoiDiagram(this.mesh) {
    _generateVoronoi();
  }

  void _generateVoronoi() {
    // Calculate circumcenters for each triangle
    circumcenters = List.generate(mesh.numTriangles, (t) {
      if (mesh.is_ghost_t(t)) {
        return mesh.pos_of_t(t);
      }

      List<int> vertices = mesh.r_around_t(t);
      Point2D a = mesh.pos_of_r(vertices[0]);
      Point2D b = mesh.pos_of_r(vertices[1]);
      Point2D c = mesh.pos_of_r(vertices[2]);

      return _circumcenter(a, b, c);
    });

    // Build Voronoi regions
    regions = List.generate(mesh.numSolidRegions, (r) {
      if (mesh.is_ghost_r(r)) return [];

      List<int> triangles = mesh.t_around_r(r);
      List<Point2D> region = [];

      for (int t in triangles) {
        if (!mesh.is_ghost_t(t)) {
          region.add(circumcenters[t]);
        }
      }

      return region;
    });
  }

  Point2D _circumcenter(Point2D a, Point2D b, Point2D c) {
    double ax = a.x, ay = a.y;
    double bx = b.x, by = b.y;
    double cx = c.x, cy = c.y;

    double d = 2 * (ax * (by - cy) + bx * (cy - ay) + cx * (ay - by));
    if (d.abs() < 1e-10) {
      // Degenerate case - return centroid
      return Point2D((ax + bx + cx) / 3, (ay + by + cy) / 3);
    }

    double ux = ((ax * ax + ay * ay) * (by - cy) +
            (bx * bx + by * by) * (cy - ay) +
            (cx * cx + cy * cy) * (ay - by)) /
        d;

    double uy = ((ax * ax + ay * ay) * (cx - bx) +
            (bx * bx + by * by) * (ax - cx) +
            (cx * cx + cy * cy) * (bx - ax)) /
        d;

    return Point2D(ux, uy);
  }
}
