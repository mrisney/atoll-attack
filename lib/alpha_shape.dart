import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class Point2D {
  final double x, y;
  Point2D(this.x, this.y);
  
  double distanceTo(Point2D other) {
    return sqrt(pow(x - other.x, 2) + pow(y - other.y, 2));
  }
}

class Triangle {
  final int i1, i2, i3;
  final Point2D p1, p2, p3;
  
  Triangle(this.i1, this.i2, this.i3, this.p1, this.p2, this.p3);
  
  double get circumradius {
    double a = p1.distanceTo(p2);
    double b = p2.distanceTo(p3);
    double c = p3.distanceTo(p1);
    
    double s = (a + b + c) / 2.0;
    double area = sqrt(max(s * (s - a) * (s - b) * (s - c), 0.0));
    
    if (area == 0) return double.infinity;
    return (a * b * c) / (4.0 * area);
  }
}

class AlphaShape {
  static List<List<Point2D>> compute(List<Point2D> points, double alpha) {
    if (points.length < 3) return [];
    
    // Simple Delaunay triangulation (basic implementation)
    List<Triangle> triangles = _delaunayTriangulation(points);
    
    // Filter triangles by alpha value
    Set<String> edges = {};
    for (Triangle tri in triangles) {
      if (tri.circumradius < 1.0 / alpha) {
        _addEdge(edges, tri.i1, tri.i2);
        _addEdge(edges, tri.i2, tri.i3);
        _addEdge(edges, tri.i3, tri.i1);
      }
    }
    
    // Convert edges to polygons
    return _edgesToPolygons(edges, points);
  }
  
  static void _addEdge(Set<String> edges, int i, int j) {
    String edge1 = "${min(i, j)}-${max(i, j)}";
    if (edges.contains(edge1)) {
      edges.remove(edge1); // Remove shared edges
    } else {
      edges.add(edge1);
    }
  }
  
  static List<Triangle> _delaunayTriangulation(List<Point2D> points) {
    // Simplified Delaunay - for production use package:delaunay
    List<Triangle> triangles = [];
    
    // Create bounding triangle
    double minX = points.map((p) => p.x).reduce(min) - 1;
    double maxX = points.map((p) => p.x).reduce(max) + 1;
    double minY = points.map((p) => p.y).reduce(min) - 1;
    double maxY = points.map((p) => p.y).reduce(max) + 1;
    
    // Basic triangulation (replace with proper Delaunay implementation)
    for (int i = 0; i < points.length - 2; i++) {
      for (int j = i + 1; j < points.length - 1; j++) {
        for (int k = j + 1; k < points.length; k++) {
          triangles.add(Triangle(i, j, k, points[i], points[j], points[k]));
        }
      }
    }
    
    return triangles;
  }
  
  static List<List<Point2D>> _edgesToPolygons(Set<String> edges, List<Point2D> points) {
    // Convert edge set back to polygons (simplified)
    List<List<Point2D>> polygons = [];
    
    if (edges.isNotEmpty) {
      List<Point2D> polygon = [];
      for (String edge in edges) {
        List<String> indices = edge.split('-');
        int i = int.parse(indices[0]);
        int j = int.parse(indices[1]);
        
        if (polygon.isEmpty) {
          polygon.addAll([points[i], points[j]]);
        }
      }
      if (polygon.isNotEmpty) {
        polygons.add(polygon);
      }
    }
    
    return polygons;
  }
}