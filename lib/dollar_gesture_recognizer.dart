import 'math_utils.dart';

/// DollarRecognizer class
class DollarRecognizer {
  List<Unistroke> unistrokes;

  DollarRecognizer(List<Unistroke> unistrokes) {
    this.unistrokes = new List<Unistroke>();
    addGestures(unistrokes);
  }

  ///Recognize gesture
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

  ///Add a list of gestures to the recognizer.
  void addGestures(List<Unistroke> unistrokes) {
    this.unistrokes.addAll(unistrokes);
  }

  ///Add a gesture to the recognizer.
  int addGesture(String name, List<Point> points) {
    unistrokes.add(Unistroke(name, points)); // append new unistroke
    int num = 0;
    for (int i = 0; i < unistrokes.length; i++) {
      if (unistrokes[i].name == name) num++;
    }
    return num;
  }

  ///Delete a gesture fro, the recognizer.
  int deleteUserGesture(String name) {
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
