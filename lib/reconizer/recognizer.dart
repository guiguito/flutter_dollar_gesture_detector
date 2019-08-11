import 'dart:math' as math;

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

//
// DollarRecognizer constants
//
const NUMPOINTS = 64;
const SQUARESIZE = 250.0;
const Point ORIGIN = const Point(0, 0);
final double DIAGONAL =
    math.sqrt(SQUARESIZE * SQUARESIZE + SQUARESIZE * SQUARESIZE);
final double HALFDIAGONAL = 0.5 * DIAGONAL;
final double ANGLERANGE = deg2Rad(45.0);
final double ANGLEPRECISION = deg2Rad(2.0);
final double PHI = 0.5 * (-1.0 + math.sqrt(5.0)); // Golden Ratio
final int INFINITY = double.maxFinite.toInt();

/// DollarRecognizer class
class DollarRecognizer // constructor
{
  List<Unistroke> unistrokes;

  DollarRecognizer() {
    // one built-in unistroke per gesture type
    unistrokes = new List<Unistroke>();
    addGestures(getTestGestures());
  }

  /// The $1 Gesture Recognizer API begins here -- 3 methods: Recognize(), AddGesture(), and DeleteUserGestures()
  Future<Result> recognize(points, bool useProtractor) async {
    int t0 = new DateTime.now().millisecondsSinceEpoch;
    Unistroke candidate = new Unistroke("", points);

    int u = -1;
    double b = INFINITY.toDouble();
    for (int i = 0; i < unistrokes.length; i++) // for each unistroke template
    {
      double d;
      if (useProtractor)
        d = optimalCosineDistance(
            unistrokes[i].vector, candidate.vector); // Protractor
      else
        d = distanceAtBestAngle(candidate.points, unistrokes[i], -ANGLERANGE,
            ANGLERANGE, ANGLEPRECISION); // Golden Section Search (original $1)
      if (d < b) {
        b = d; // best (least) distance
        u = i; // unistroke index
      }
    }
    int t1 = new DateTime.now().millisecondsSinceEpoch;
    return (u == -1)
        ? new Result("No match.", 0.0, t1 - t0)
        : new Result(unistrokes[u].name,
            useProtractor ? (1.0 - b) : (1.0 - b / HALFDIAGONAL), t1 - t0);
  }

  void addGestures(List<Unistroke> unistrokes) {
    this.unistrokes.addAll(unistrokes);
  }

  int addGesture(String name, List<Point> points) {
    unistrokes.add(Unistroke(name, points)); // append new unistroke
    int num = 0;
    for (int i = 0; i < unistrokes.length; i++) {
      if (unistrokes[i].name == name) num++;
    }
    return num;
  }

  int deleteUserGestures(String name) {
    int index = -1;
    for (int i = 0; i < unistrokes.length; i++) {
      if (unistrokes[i].name == name) {
        index = i;
        break;
      }
    }
    if (index != -1) {
      unistrokes.removeAt(index); // clear any beyond the original set
    }
    return index;
  }
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

List<Unistroke> getTestGestures() {
  List<Unistroke> unistrokes = new List<Unistroke>();
  unistrokes.add(Unistroke("triangle", [
    new Point(137, 139),
    new Point(135, 141),
    new Point(133, 144),
    new Point(132, 146),
    new Point(130, 149),
    new Point(128, 151),
    new Point(126, 155),
    new Point(123, 160),
    new Point(120, 166),
    new Point(116, 171),
    new Point(112, 177),
    new Point(107, 183),
    new Point(102, 188),
    new Point(100, 191),
    new Point(95, 195),
    new Point(90, 199),
    new Point(86, 203),
    new Point(82, 206),
    new Point(80, 209),
    new Point(75, 213),
    new Point(73, 213),
    new Point(70, 216),
    new Point(67, 219),
    new Point(64, 221),
    new Point(61, 223),
    new Point(60, 225),
    new Point(62, 226),
    new Point(65, 225),
    new Point(67, 226),
    new Point(74, 226),
    new Point(77, 227),
    new Point(85, 229),
    new Point(91, 230),
    new Point(99, 231),
    new Point(108, 232),
    new Point(116, 233),
    new Point(125, 233),
    new Point(134, 234),
    new Point(145, 233),
    new Point(153, 232),
    new Point(160, 233),
    new Point(170, 234),
    new Point(177, 235),
    new Point(179, 236),
    new Point(186, 237),
    new Point(193, 238),
    new Point(198, 239),
    new Point(200, 237),
    new Point(202, 239),
    new Point(204, 238),
    new Point(206, 234),
    new Point(205, 230),
    new Point(202, 222),
    new Point(197, 216),
    new Point(192, 207),
    new Point(186, 198),
    new Point(179, 189),
    new Point(174, 183),
    new Point(170, 178),
    new Point(164, 171),
    new Point(161, 168),
    new Point(154, 160),
    new Point(148, 155),
    new Point(143, 150),
    new Point(138, 148),
    new Point(136, 148)
  ]));
  unistrokes.add(Unistroke("x", [
    new Point(87, 142),
    new Point(89, 145),
    new Point(91, 148),
    new Point(93, 151),
    new Point(96, 155),
    new Point(98, 157),
    new Point(100, 160),
    new Point(102, 162),
    new Point(106, 167),
    new Point(108, 169),
    new Point(110, 171),
    new Point(115, 177),
    new Point(119, 183),
    new Point(123, 189),
    new Point(127, 193),
    new Point(129, 196),
    new Point(133, 200),
    new Point(137, 206),
    new Point(140, 209),
    new Point(143, 212),
    new Point(146, 215),
    new Point(151, 220),
    new Point(153, 222),
    new Point(155, 223),
    new Point(157, 225),
    new Point(158, 223),
    new Point(157, 218),
    new Point(155, 211),
    new Point(154, 208),
    new Point(152, 200),
    new Point(150, 189),
    new Point(148, 179),
    new Point(147, 170),
    new Point(147, 158),
    new Point(147, 148),
    new Point(147, 141),
    new Point(147, 136),
    new Point(144, 135),
    new Point(142, 137),
    new Point(140, 139),
    new Point(135, 145),
    new Point(131, 152),
    new Point(124, 163),
    new Point(116, 177),
    new Point(108, 191),
    new Point(100, 206),
    new Point(94, 217),
    new Point(91, 222),
    new Point(89, 225),
    new Point(87, 226),
    new Point(87, 224)
  ]));
  unistrokes.add(new Unistroke("rectangle", [
    new Point(78, 149),
    new Point(78, 153),
    new Point(78, 157),
    new Point(78, 160),
    new Point(79, 162),
    new Point(79, 164),
    new Point(79, 167),
    new Point(79, 169),
    new Point(79, 173),
    new Point(79, 178),
    new Point(79, 183),
    new Point(80, 189),
    new Point(80, 193),
    new Point(80, 198),
    new Point(80, 202),
    new Point(81, 208),
    new Point(81, 210),
    new Point(81, 216),
    new Point(82, 222),
    new Point(82, 224),
    new Point(82, 227),
    new Point(83, 229),
    new Point(83, 231),
    new Point(85, 230),
    new Point(88, 232),
    new Point(90, 233),
    new Point(92, 232),
    new Point(94, 233),
    new Point(99, 232),
    new Point(102, 233),
    new Point(106, 233),
    new Point(109, 234),
    new Point(117, 235),
    new Point(123, 236),
    new Point(126, 236),
    new Point(135, 237),
    new Point(142, 238),
    new Point(145, 238),
    new Point(152, 238),
    new Point(154, 239),
    new Point(165, 238),
    new Point(174, 237),
    new Point(179, 236),
    new Point(186, 235),
    new Point(191, 235),
    new Point(195, 233),
    new Point(197, 233),
    new Point(200, 233),
    new Point(201, 235),
    new Point(201, 233),
    new Point(199, 231),
    new Point(198, 226),
    new Point(198, 220),
    new Point(196, 207),
    new Point(195, 195),
    new Point(195, 181),
    new Point(195, 173),
    new Point(195, 163),
    new Point(194, 155),
    new Point(192, 145),
    new Point(192, 143),
    new Point(192, 138),
    new Point(191, 135),
    new Point(191, 133),
    new Point(191, 130),
    new Point(190, 128),
    new Point(188, 129),
    new Point(186, 129),
    new Point(181, 132),
    new Point(173, 131),
    new Point(162, 131),
    new Point(151, 132),
    new Point(149, 132),
    new Point(138, 132),
    new Point(136, 132),
    new Point(122, 131),
    new Point(120, 131),
    new Point(109, 130),
    new Point(107, 130),
    new Point(90, 132),
    new Point(81, 133),
    new Point(76, 133)
  ]));
  unistrokes.add(new Unistroke("circle", [
    new Point(127, 141),
    new Point(124, 140),
    new Point(120, 139),
    new Point(118, 139),
    new Point(116, 139),
    new Point(111, 140),
    new Point(109, 141),
    new Point(104, 144),
    new Point(100, 147),
    new Point(96, 152),
    new Point(93, 157),
    new Point(90, 163),
    new Point(87, 169),
    new Point(85, 175),
    new Point(83, 181),
    new Point(82, 190),
    new Point(82, 195),
    new Point(83, 200),
    new Point(84, 205),
    new Point(88, 213),
    new Point(91, 216),
    new Point(96, 219),
    new Point(103, 222),
    new Point(108, 224),
    new Point(111, 224),
    new Point(120, 224),
    new Point(133, 223),
    new Point(142, 222),
    new Point(152, 218),
    new Point(160, 214),
    new Point(167, 210),
    new Point(173, 204),
    new Point(178, 198),
    new Point(179, 196),
    new Point(182, 188),
    new Point(182, 177),
    new Point(178, 167),
    new Point(170, 150),
    new Point(163, 138),
    new Point(152, 130),
    new Point(143, 129),
    new Point(140, 131),
    new Point(129, 136),
    new Point(126, 139)
  ]));
  unistrokes.add(Unistroke("check", [
    new Point(91, 185),
    new Point(93, 185),
    new Point(95, 185),
    new Point(97, 185),
    new Point(100, 188),
    new Point(102, 189),
    new Point(104, 190),
    new Point(106, 193),
    new Point(108, 195),
    new Point(110, 198),
    new Point(112, 201),
    new Point(114, 204),
    new Point(115, 207),
    new Point(117, 210),
    new Point(118, 212),
    new Point(120, 214),
    new Point(121, 217),
    new Point(122, 219),
    new Point(123, 222),
    new Point(124, 224),
    new Point(126, 226),
    new Point(127, 229),
    new Point(129, 231),
    new Point(130, 233),
    new Point(129, 231),
    new Point(129, 228),
    new Point(129, 226),
    new Point(129, 224),
    new Point(129, 221),
    new Point(129, 218),
    new Point(129, 212),
    new Point(129, 208),
    new Point(130, 198),
    new Point(132, 189),
    new Point(134, 182),
    new Point(137, 173),
    new Point(143, 164),
    new Point(147, 157),
    new Point(151, 151),
    new Point(155, 144),
    new Point(161, 137),
    new Point(165, 131),
    new Point(171, 122),
    new Point(174, 118),
    new Point(176, 114),
    new Point(177, 112),
    new Point(177, 114),
    new Point(175, 116),
    new Point(173, 118)
  ]));
  unistrokes.add(Unistroke("caret", [
    new Point(79, 245),
    new Point(79, 242),
    new Point(79, 239),
    new Point(80, 237),
    new Point(80, 234),
    new Point(81, 232),
    new Point(82, 230),
    new Point(84, 224),
    new Point(86, 220),
    new Point(86, 218),
    new Point(87, 216),
    new Point(88, 213),
    new Point(90, 207),
    new Point(91, 202),
    new Point(92, 200),
    new Point(93, 194),
    new Point(94, 192),
    new Point(96, 189),
    new Point(97, 186),
    new Point(100, 179),
    new Point(102, 173),
    new Point(105, 165),
    new Point(107, 160),
    new Point(109, 158),
    new Point(112, 151),
    new Point(115, 144),
    new Point(117, 139),
    new Point(119, 136),
    new Point(119, 134),
    new Point(120, 132),
    new Point(121, 129),
    new Point(122, 127),
    new Point(124, 125),
    new Point(126, 124),
    new Point(129, 125),
    new Point(131, 127),
    new Point(132, 130),
    new Point(136, 139),
    new Point(141, 154),
    new Point(145, 166),
    new Point(151, 182),
    new Point(156, 193),
    new Point(157, 196),
    new Point(161, 209),
    new Point(162, 211),
    new Point(167, 223),
    new Point(169, 229),
    new Point(170, 231),
    new Point(173, 237),
    new Point(176, 242),
    new Point(177, 244),
    new Point(179, 250),
    new Point(181, 255),
    new Point(182, 257)
  ]));
  unistrokes.add(Unistroke("zig-zag", [
    new Point(307, 216),
    new Point(333, 186),
    new Point(356, 215),
    new Point(375, 186),
    new Point(399, 216),
    new Point(418, 186)
  ]));
  unistrokes.add(Unistroke("arrow", [
    new Point(68, 222),
    new Point(70, 220),
    new Point(73, 218),
    new Point(75, 217),
    new Point(77, 215),
    new Point(80, 213),
    new Point(82, 212),
    new Point(84, 210),
    new Point(87, 209),
    new Point(89, 208),
    new Point(92, 206),
    new Point(95, 204),
    new Point(101, 201),
    new Point(106, 198),
    new Point(112, 194),
    new Point(118, 191),
    new Point(124, 187),
    new Point(127, 186),
    new Point(132, 183),
    new Point(138, 181),
    new Point(141, 180),
    new Point(146, 178),
    new Point(154, 173),
    new Point(159, 171),
    new Point(161, 170),
    new Point(166, 167),
    new Point(168, 167),
    new Point(171, 166),
    new Point(174, 164),
    new Point(177, 162),
    new Point(180, 160),
    new Point(182, 158),
    new Point(183, 156),
    new Point(181, 154),
    new Point(178, 153),
    new Point(171, 153),
    new Point(164, 153),
    new Point(160, 153),
    new Point(150, 154),
    new Point(147, 155),
    new Point(141, 157),
    new Point(137, 158),
    new Point(135, 158),
    new Point(137, 158),
    new Point(140, 157),
    new Point(143, 156),
    new Point(151, 154),
    new Point(160, 152),
    new Point(170, 149),
    new Point(179, 147),
    new Point(185, 145),
    new Point(192, 144),
    new Point(196, 144),
    new Point(198, 144),
    new Point(200, 144),
    new Point(201, 147),
    new Point(199, 149),
    new Point(194, 157),
    new Point(191, 160),
    new Point(186, 167),
    new Point(180, 176),
    new Point(177, 179),
    new Point(171, 187),
    new Point(169, 189),
    new Point(165, 194),
    new Point(164, 196)
  ]));
  unistrokes.add(Unistroke("left square bracket", [
    new Point(140, 124),
    new Point(138, 123),
    new Point(135, 122),
    new Point(133, 123),
    new Point(130, 123),
    new Point(128, 124),
    new Point(125, 125),
    new Point(122, 124),
    new Point(120, 124),
    new Point(118, 124),
    new Point(116, 125),
    new Point(113, 125),
    new Point(111, 125),
    new Point(108, 124),
    new Point(106, 125),
    new Point(104, 125),
    new Point(102, 124),
    new Point(100, 123),
    new Point(98, 123),
    new Point(95, 124),
    new Point(93, 123),
    new Point(90, 124),
    new Point(88, 124),
    new Point(85, 125),
    new Point(83, 126),
    new Point(81, 127),
    new Point(81, 129),
    new Point(82, 131),
    new Point(82, 134),
    new Point(83, 138),
    new Point(84, 141),
    new Point(84, 144),
    new Point(85, 148),
    new Point(85, 151),
    new Point(86, 156),
    new Point(86, 160),
    new Point(86, 164),
    new Point(86, 168),
    new Point(87, 171),
    new Point(87, 175),
    new Point(87, 179),
    new Point(87, 182),
    new Point(87, 186),
    new Point(88, 188),
    new Point(88, 195),
    new Point(88, 198),
    new Point(88, 201),
    new Point(88, 207),
    new Point(89, 211),
    new Point(89, 213),
    new Point(89, 217),
    new Point(89, 222),
    new Point(88, 225),
    new Point(88, 229),
    new Point(88, 231),
    new Point(88, 233),
    new Point(88, 235),
    new Point(89, 237),
    new Point(89, 240),
    new Point(89, 242),
    new Point(91, 241),
    new Point(94, 241),
    new Point(96, 240),
    new Point(98, 239),
    new Point(105, 240),
    new Point(109, 240),
    new Point(113, 239),
    new Point(116, 240),
    new Point(121, 239),
    new Point(130, 240),
    new Point(136, 237),
    new Point(139, 237),
    new Point(144, 238),
    new Point(151, 237),
    new Point(157, 236),
    new Point(159, 237)
  ]));
  unistrokes.add(Unistroke("right square bracket", [
    new Point(112, 138),
    new Point(112, 136),
    new Point(115, 136),
    new Point(118, 137),
    new Point(120, 136),
    new Point(123, 136),
    new Point(125, 136),
    new Point(128, 136),
    new Point(131, 136),
    new Point(134, 135),
    new Point(137, 135),
    new Point(140, 134),
    new Point(143, 133),
    new Point(145, 132),
    new Point(147, 132),
    new Point(149, 132),
    new Point(152, 132),
    new Point(153, 134),
    new Point(154, 137),
    new Point(155, 141),
    new Point(156, 144),
    new Point(157, 152),
    new Point(158, 161),
    new Point(160, 170),
    new Point(162, 182),
    new Point(164, 192),
    new Point(166, 200),
    new Point(167, 209),
    new Point(168, 214),
    new Point(168, 216),
    new Point(169, 221),
    new Point(169, 223),
    new Point(169, 228),
    new Point(169, 231),
    new Point(166, 233),
    new Point(164, 234),
    new Point(161, 235),
    new Point(155, 236),
    new Point(147, 235),
    new Point(140, 233),
    new Point(131, 233),
    new Point(124, 233),
    new Point(117, 235),
    new Point(114, 238),
    new Point(112, 238)
  ]));
  unistrokes.add(Unistroke("v", [
    new Point(89, 164),
    new Point(90, 162),
    new Point(92, 162),
    new Point(94, 164),
    new Point(95, 166),
    new Point(96, 169),
    new Point(97, 171),
    new Point(99, 175),
    new Point(101, 178),
    new Point(103, 182),
    new Point(106, 189),
    new Point(108, 194),
    new Point(111, 199),
    new Point(114, 204),
    new Point(117, 209),
    new Point(119, 214),
    new Point(122, 218),
    new Point(124, 222),
    new Point(126, 225),
    new Point(128, 228),
    new Point(130, 229),
    new Point(133, 233),
    new Point(134, 236),
    new Point(136, 239),
    new Point(138, 240),
    new Point(139, 242),
    new Point(140, 244),
    new Point(142, 242),
    new Point(142, 240),
    new Point(142, 237),
    new Point(143, 235),
    new Point(143, 233),
    new Point(145, 229),
    new Point(146, 226),
    new Point(148, 217),
    new Point(149, 208),
    new Point(149, 205),
    new Point(151, 196),
    new Point(151, 193),
    new Point(153, 182),
    new Point(155, 172),
    new Point(157, 165),
    new Point(159, 160),
    new Point(162, 155),
    new Point(164, 150),
    new Point(165, 148),
    new Point(166, 146)
  ]));
  unistrokes.add(Unistroke("delete", [
    new Point(123, 129),
    new Point(123, 131),
    new Point(124, 133),
    new Point(125, 136),
    new Point(127, 140),
    new Point(129, 142),
    new Point(133, 148),
    new Point(137, 154),
    new Point(143, 158),
    new Point(145, 161),
    new Point(148, 164),
    new Point(153, 170),
    new Point(158, 176),
    new Point(160, 178),
    new Point(164, 183),
    new Point(168, 188),
    new Point(171, 191),
    new Point(175, 196),
    new Point(178, 200),
    new Point(180, 202),
    new Point(181, 205),
    new Point(184, 208),
    new Point(186, 210),
    new Point(187, 213),
    new Point(188, 215),
    new Point(186, 212),
    new Point(183, 211),
    new Point(177, 208),
    new Point(169, 206),
    new Point(162, 205),
    new Point(154, 207),
    new Point(145, 209),
    new Point(137, 210),
    new Point(129, 214),
    new Point(122, 217),
    new Point(118, 218),
    new Point(111, 221),
    new Point(109, 222),
    new Point(110, 219),
    new Point(112, 217),
    new Point(118, 209),
    new Point(120, 207),
    new Point(128, 196),
    new Point(135, 187),
    new Point(138, 183),
    new Point(148, 167),
    new Point(157, 153),
    new Point(163, 145),
    new Point(165, 142),
    new Point(172, 133),
    new Point(177, 127),
    new Point(179, 127),
    new Point(180, 125)
  ]));
  unistrokes.add(Unistroke("left curly brace", [
    new Point(150, 116),
    new Point(147, 117),
    new Point(145, 116),
    new Point(142, 116),
    new Point(139, 117),
    new Point(136, 117),
    new Point(133, 118),
    new Point(129, 121),
    new Point(126, 122),
    new Point(123, 123),
    new Point(120, 125),
    new Point(118, 127),
    new Point(115, 128),
    new Point(113, 129),
    new Point(112, 131),
    new Point(113, 134),
    new Point(115, 134),
    new Point(117, 135),
    new Point(120, 135),
    new Point(123, 137),
    new Point(126, 138),
    new Point(129, 140),
    new Point(135, 143),
    new Point(137, 144),
    new Point(139, 147),
    new Point(141, 149),
    new Point(140, 152),
    new Point(139, 155),
    new Point(134, 159),
    new Point(131, 161),
    new Point(124, 166),
    new Point(121, 166),
    new Point(117, 166),
    new Point(114, 167),
    new Point(112, 166),
    new Point(114, 164),
    new Point(116, 163),
    new Point(118, 163),
    new Point(120, 162),
    new Point(122, 163),
    new Point(125, 164),
    new Point(127, 165),
    new Point(129, 166),
    new Point(130, 168),
    new Point(129, 171),
    new Point(127, 175),
    new Point(125, 179),
    new Point(123, 184),
    new Point(121, 190),
    new Point(120, 194),
    new Point(119, 199),
    new Point(120, 202),
    new Point(123, 207),
    new Point(127, 211),
    new Point(133, 215),
    new Point(142, 219),
    new Point(148, 220),
    new Point(151, 221)
  ]));
  unistrokes.add(Unistroke("right curly brace", [
    new Point(117, 132),
    new Point(115, 132),
    new Point(115, 129),
    new Point(117, 129),
    new Point(119, 128),
    new Point(122, 127),
    new Point(125, 127),
    new Point(127, 127),
    new Point(130, 127),
    new Point(133, 129),
    new Point(136, 129),
    new Point(138, 130),
    new Point(140, 131),
    new Point(143, 134),
    new Point(144, 136),
    new Point(145, 139),
    new Point(145, 142),
    new Point(145, 145),
    new Point(145, 147),
    new Point(145, 149),
    new Point(144, 152),
    new Point(142, 157),
    new Point(141, 160),
    new Point(139, 163),
    new Point(137, 166),
    new Point(135, 167),
    new Point(133, 169),
    new Point(131, 172),
    new Point(128, 173),
    new Point(126, 176),
    new Point(125, 178),
    new Point(125, 180),
    new Point(125, 182),
    new Point(126, 184),
    new Point(128, 187),
    new Point(130, 187),
    new Point(132, 188),
    new Point(135, 189),
    new Point(140, 189),
    new Point(145, 189),
    new Point(150, 187),
    new Point(155, 186),
    new Point(157, 185),
    new Point(159, 184),
    new Point(156, 185),
    new Point(154, 185),
    new Point(149, 185),
    new Point(145, 187),
    new Point(141, 188),
    new Point(136, 191),
    new Point(134, 191),
    new Point(131, 192),
    new Point(129, 193),
    new Point(129, 195),
    new Point(129, 197),
    new Point(131, 200),
    new Point(133, 202),
    new Point(136, 206),
    new Point(139, 211),
    new Point(142, 215),
    new Point(145, 220),
    new Point(147, 225),
    new Point(148, 231),
    new Point(147, 239),
    new Point(144, 244),
    new Point(139, 248),
    new Point(134, 250),
    new Point(126, 253),
    new Point(119, 253),
    new Point(115, 253)
  ]));
  unistrokes.add(Unistroke("star", [
    new Point(75, 250),
    new Point(75, 247),
    new Point(77, 244),
    new Point(78, 242),
    new Point(79, 239),
    new Point(80, 237),
    new Point(82, 234),
    new Point(82, 232),
    new Point(84, 229),
    new Point(85, 225),
    new Point(87, 222),
    new Point(88, 219),
    new Point(89, 216),
    new Point(91, 212),
    new Point(92, 208),
    new Point(94, 204),
    new Point(95, 201),
    new Point(96, 196),
    new Point(97, 194),
    new Point(98, 191),
    new Point(100, 185),
    new Point(102, 178),
    new Point(104, 173),
    new Point(104, 171),
    new Point(105, 164),
    new Point(106, 158),
    new Point(107, 156),
    new Point(107, 152),
    new Point(108, 145),
    new Point(109, 141),
    new Point(110, 139),
    new Point(112, 133),
    new Point(113, 131),
    new Point(116, 127),
    new Point(117, 125),
    new Point(119, 122),
    new Point(121, 121),
    new Point(123, 120),
    new Point(125, 122),
    new Point(125, 125),
    new Point(127, 130),
    new Point(128, 133),
    new Point(131, 143),
    new Point(136, 153),
    new Point(140, 163),
    new Point(144, 172),
    new Point(145, 175),
    new Point(151, 189),
    new Point(156, 201),
    new Point(161, 213),
    new Point(166, 225),
    new Point(169, 233),
    new Point(171, 236),
    new Point(174, 243),
    new Point(177, 247),
    new Point(178, 249),
    new Point(179, 251),
    new Point(180, 253),
    new Point(180, 255),
    new Point(179, 257),
    new Point(177, 257),
    new Point(174, 255),
    new Point(169, 250),
    new Point(164, 247),
    new Point(160, 245),
    new Point(149, 238),
    new Point(138, 230),
    new Point(127, 221),
    new Point(124, 220),
    new Point(112, 212),
    new Point(110, 210),
    new Point(96, 201),
    new Point(84, 195),
    new Point(74, 190),
    new Point(64, 182),
    new Point(55, 175),
    new Point(51, 172),
    new Point(49, 170),
    new Point(51, 169),
    new Point(56, 169),
    new Point(66, 169),
    new Point(78, 168),
    new Point(92, 166),
    new Point(107, 164),
    new Point(123, 161),
    new Point(140, 162),
    new Point(156, 162),
    new Point(171, 160),
    new Point(173, 160),
    new Point(186, 160),
    new Point(195, 160),
    new Point(198, 161),
    new Point(203, 163),
    new Point(208, 163),
    new Point(206, 164),
    new Point(200, 167),
    new Point(187, 172),
    new Point(174, 179),
    new Point(172, 181),
    new Point(153, 192),
    new Point(137, 201),
    new Point(123, 211),
    new Point(112, 220),
    new Point(99, 229),
    new Point(90, 237),
    new Point(80, 244),
    new Point(73, 250),
    new Point(69, 254),
    new Point(69, 252)
  ]));
  unistrokes.add(Unistroke("pigtail", [
    new Point(81, 219),
    new Point(84, 218),
    new Point(86, 220),
    new Point(88, 220),
    new Point(90, 220),
    new Point(92, 219),
    new Point(95, 220),
    new Point(97, 219),
    new Point(99, 220),
    new Point(102, 218),
    new Point(105, 217),
    new Point(107, 216),
    new Point(110, 216),
    new Point(113, 214),
    new Point(116, 212),
    new Point(118, 210),
    new Point(121, 208),
    new Point(124, 205),
    new Point(126, 202),
    new Point(129, 199),
    new Point(132, 196),
    new Point(136, 191),
    new Point(139, 187),
    new Point(142, 182),
    new Point(144, 179),
    new Point(146, 174),
    new Point(148, 170),
    new Point(149, 168),
    new Point(151, 162),
    new Point(152, 160),
    new Point(152, 157),
    new Point(152, 155),
    new Point(152, 151),
    new Point(152, 149),
    new Point(152, 146),
    new Point(149, 142),
    new Point(148, 139),
    new Point(145, 137),
    new Point(141, 135),
    new Point(139, 135),
    new Point(134, 136),
    new Point(130, 140),
    new Point(128, 142),
    new Point(126, 145),
    new Point(122, 150),
    new Point(119, 158),
    new Point(117, 163),
    new Point(115, 170),
    new Point(114, 175),
    new Point(117, 184),
    new Point(120, 190),
    new Point(125, 199),
    new Point(129, 203),
    new Point(133, 208),
    new Point(138, 213),
    new Point(145, 215),
    new Point(155, 218),
    new Point(164, 219),
    new Point(166, 219),
    new Point(177, 219),
    new Point(182, 218),
    new Point(192, 216),
    new Point(196, 213),
    new Point(199, 212),
    new Point(201, 211)
  ]));
  return unistrokes;
}