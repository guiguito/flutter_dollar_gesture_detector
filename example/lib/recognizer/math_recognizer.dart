import 'dart:math' as math;

//
// DollarRecognizer constants
//
const NUMPOINTS = 64;
const SQUARESIZE = 250.0;
final double PHI = 0.5 * (-1.0 + math.sqrt(5.0)); // Golden Ratio
final int INFINITY = double.maxFinite.toInt();
const Point ORIGIN = const Point(0, 0);
final double DIAGONAL = math.sqrt(SQUARESIZE * SQUARESIZE + SQUARESIZE * SQUARESIZE);
final double HALFDIAGONAL = 0.5 * DIAGONAL;
final double ANGLERANGE = deg2Rad(45.0);
final double ANGLEPRECISION = deg2Rad(2.0);

class Point {
  final double x;
  final double y;

  const Point(this.x, this.y);
}

class Rectangle {
  double x;
  double y;
  double width;
  double height;

  Rectangle(this.x, this.y, this.width, this.height);
}

class Unistroke {
  String name;
  List<Point> points;
  List<double> vector;

  Unistroke(String name, points) {
    this.name = name;
    this.points = resample(points, NUMPOINTS);
    var radians = indicativeAngle(this.points);
    this.points = rotateBy(this.points, -radians);
    this.points = scaleTo(this.points, SQUARESIZE);
    this.points = translateTo(this.points, ORIGIN);
    this.vector = vectorize(this.points);
  }
}

class Result {
  String name;
  double score;
  int ms;

  Result(this.name, this.score, this.ms);
}

///Private helper functions from here on down
List<Point> resample(List<Point> points, int numPoints) {
  double I = pathLength(points) / (numPoints - 1); // interval length
  double D = 0.0;
  List<Point> newpoints = new List<Point>();
  newpoints.add(points[0]);
  for (var i = 1; i < points.length; i++) {
    var d = distance(points[i - 1], points[i]);
    if ((D + d) >= I) {
      var qx =
          points[i - 1].x + ((I - D) / d) * (points[i].x - points[i - 1].x);
      var qy =
          points[i - 1].y + ((I - D) / d) * (points[i].y - points[i - 1].y);
      var q = new Point(qx, qy);
      newpoints.add(q); // append new point 'q'
      points.insert(i,
          q); // insert 'q' at position i in points s.t. 'q' will be the next i
      D = 0.0;
    } else
      D += d;
  }
  if (newpoints.length ==
      numPoints -
          1) // somtimes we fall a rounding-error short of adding the last point, so add it if so
    newpoints.add(
        new Point(points[points.length - 1].x, points[points.length - 1].y));
  return newpoints;
}

double indicativeAngle(List<Point> points) {
  Point c = centroid(points);
  return math.atan2(c.y - points[0].y, c.x - points[0].x);
}

// rotates points around centroid
List<Point> rotateBy(List<Point> points, radians) {
  var c = centroid(points);
  var cos = math.cos(radians);
  var sin = math.sin(radians);
  var newpoints = new List<Point>();
  for (var i = 0; i < points.length; i++) {
    var qx = (points[i].x - c.x) * cos - (points[i].y - c.y) * sin + c.x;
    var qy = (points[i].x - c.x) * sin + (points[i].y - c.y) * cos + c.y;
    newpoints.add(Point(qx, qy));
  }
  return newpoints;
}

///non-uniform scale; assumes 2D gestures (i.e., no lines)
List<Point> scaleTo(List<Point> points, double size) {
  Rectangle B = boundingBox(points);
  List<Point> newpoints = List<Point>();
  for (var i = 0; i < points.length; i++) {
    var qx = points[i].x * (size / B.width);
    var qy = points[i].y * (size / B.height);
    newpoints.add(Point(qx, qy));
  }
  return newpoints;
}

///  translates points' centroid
List<Point> translateTo(List<Point> points, Point pt) {
  Point c = centroid(points);
  List<Point> newpoints = new List<Point>();
  for (var i = 0; i < points.length; i++) {
    var qx = points[i].x + pt.x - c.x;
    var qy = points[i].y + pt.y - c.y;
    newpoints.add(Point(qx, qy));
  }
  return newpoints;
}

///for Protractor
List<double> vectorize(List<Point> points) {
  double sum = 0.0;
  List<double> vector = new List<double>();
  for (int i = 0; i < points.length; i++) {
    vector.add(points[i].x.roundToDouble());
    vector.add(points[i].y.roundToDouble());
    sum += points[i].x * points[i].x + points[i].y * points[i].y;
  }
  double magnitude = math.sqrt(sum);
  for (int i = 0; i < vector.length; i++) vector[i] /= magnitude;
  return vector;
}

double optimalCosineDistance(List<double> v1, List<double> v2) {
  double a = 0.0;
  double b = 0.0;
  for (int i = 0; i < v1.length; i += 2) {
    a += v1[i] * v2[i] + v1[i + 1] * v2[i + 1];
    b += v1[i] * v2[i + 1] - v1[i + 1] * v2[i];
  }
  double angle = math.atan(b / a);
  return math.acos(a * math.cos(angle) + b * math.sin(angle));
}

double distanceAtBestAngle(
    List<Point> points, Unistroke T, double a, double b, threshold) {
  double x1 = PHI * a + (1.0 - PHI) * b;
  double f1 = distanceAtAngle(points, T, x1);
  double x2 = (1.0 - PHI) * a + PHI * b;
  double f2 = distanceAtAngle(points, T, x2);
  while ((b - a).abs() > threshold) {
    if (f1 < f2) {
      b = x2;
      x2 = x1;
      f2 = f1;
      x1 = PHI * a + (1.0 - PHI) * b;
      f1 = distanceAtAngle(points, T, x1);
    } else {
      a = x1;
      x1 = x2;
      f1 = f2;
      x2 = (1.0 - PHI) * a + PHI * b;
      f2 = distanceAtAngle(points, T, x2);
    }
  }
  return math.min(f1, f2);
}

double distanceAtAngle(List<Point> points, Unistroke T, radians) {
  var newpoints = rotateBy(points, radians);
  return pathDistance(newpoints, T.points);
}

Point centroid(List<Point> points) {
  double x = 0;
  double y = 0;
  for (int i = 0; i < points.length; i++) {
    x += points[i].x;
    y += points[i].y;
  }
  x = x / points.length;
  y = y / points.length;
  return new Point(x, y);
}

Rectangle boundingBox(List<Point> points) {
  double minX = INFINITY.toDouble();
  double maxX = -INFINITY.toDouble();
  double minY = INFINITY.toDouble();
  double maxY = -INFINITY.toDouble();
  for (var i = 0; i < points.length; i++) {
    minX = math.min(minX, points[i].x);
    minY = math.min(minY, points[i].y);
    maxX = math.max(maxX, points[i].x);
    maxY = math.max(maxY, points[i].y);
  }
  return new Rectangle(minX, minY, maxX - minX, maxY - minY);
}

double pathDistance(List<Point> pts1, List<Point> pts2) {
  double d = 0.0;
  for (var i = 0; i < pts1.length; i++) // assumes pts1.length == pts2.length
    d += distance(pts1[i], pts2[i]);
  return d / pts1.length;
}

double pathLength(List<Point> points) {
  double d = 0.0;
  for (int i = 1; i < points.length; i++)
    d += distance(points[i - 1], points[i]);
  return d;
}

double distance(Point p1, Point p2) {
  var dx = p2.x - p1.x;
  var dy = p2.y - p1.y;
  return math.sqrt(dx * dx + dy * dy);
}

double deg2Rad(d) {
  return (d * math.pi / 180.0);
}