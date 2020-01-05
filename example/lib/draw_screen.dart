import 'dart:io';
import 'dart:ui';

import 'package:dollar_gesture_recognizer/dollar_gesture_recognizer.dart';
import 'package:dollar_gesture_recognizer/gestures_examples.dart';
import 'package:dollar_gesture_recognizer/math_utils.dart';
import 'package:flutter/material.dart';

import 'dialogs.dart';

var recognizer = new DollarRecognizer(getTestGestures());
List<Point> pointsToRecognize;

class Draw extends StatefulWidget {
  @override
  _DrawState createState() => _DrawState();
}

class _DrawState extends State<Draw> {
  Color selectedColor = Colors.black;
  double strokeWidth = 3.0;
  List<DrawingPoints> points = List();
  double opacity = 1.0;
  StrokeCap strokeCap = (Platform.isAndroid) ? StrokeCap.butt : StrokeCap.round;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Container(
            padding: const EdgeInsets.only(left: 8.0, right: 8.0),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(50.0),
                color: Colors.greenAccent),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      IconButton(
                          icon: Icon(Icons.save),
                          onPressed: () async {
                            final result = await Dialogs.inputDialog(
                                context, "".toString());
                            recognizer.addGesture(result, pointsToRecognize);
                          }),
                      IconButton(
                          icon: Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              points.clear();
                            });
                          }),
                    ],
                  ),
                ],
              ),
            )),
      ),
      body: Builder(
        builder: (context) => GestureDetector(
          onPanStart: (details) {
            setState(() {
              RenderBox renderBox = context.findRenderObject();
              pointsToRecognize = new List<Point>();
              pointsToRecognize.add(Point(
                  renderBox.globalToLocal(details.globalPosition).dx,
                  renderBox.globalToLocal(details.globalPosition).dy));
              points.clear();
              points.add(DrawingPoints(
                  points: renderBox.globalToLocal(details.globalPosition),
                  paint: Paint()
                    ..strokeCap = strokeCap
                    ..isAntiAlias = true
                    ..color = selectedColor
                    ..strokeWidth = strokeWidth));
            });
          },
          onPanUpdate: (details) {
            setState(() {
              RenderBox renderBox = context.findRenderObject();
              pointsToRecognize.add(Point(
                  renderBox.globalToLocal(details.globalPosition).dx,
                  renderBox.globalToLocal(details.globalPosition).dy));
              points.add(DrawingPoints(
                  points: renderBox.globalToLocal(details.globalPosition),
                  paint: Paint()
                    ..strokeCap = strokeCap
                    ..isAntiAlias = true
                    ..color = selectedColor
                    ..strokeWidth = strokeWidth));
            });
          },
          onPanEnd: (details) async {
            setState(() {
              points.add(null);
            });
            Result result =
                await recognizer.recognize(pointsToRecognize, false);
            final snackBar = SnackBar(
                content: Text(
                    "Result : name : ${result.name}, score : ${result.score}, ms : ${result.ms}"));
            Scaffold.of(context).showSnackBar(snackBar);
          },
          child: CustomPaint(
            size: Size.infinite,
            painter: DrawingPainter(
              pointsList: points,
            ),
          ),
        ),
      ),
    );
  }
}

class DrawingPainter extends CustomPainter {
  DrawingPainter({this.pointsList});

  List<DrawingPoints> pointsList;
  List<Offset> offsetPoints = List();

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < pointsList.length - 1; i++) {
      if (pointsList[i] != null && pointsList[i + 1] != null) {
        canvas.drawLine(pointsList[i].points, pointsList[i + 1].points,
            pointsList[i].paint);
      } else if (pointsList[i] != null && pointsList[i + 1] == null) {
        offsetPoints.clear();
        offsetPoints.add(pointsList[i].points);
        offsetPoints.add(Offset(
            pointsList[i].points.dx + 0.1, pointsList[i].points.dy + 0.1));
        canvas.drawPoints(PointMode.points, offsetPoints, pointsList[i].paint);
      }
    }
  }

  @override
  bool shouldRepaint(DrawingPainter oldDelegate) => true;
}

class DrawingPoints {
  Paint paint;
  Offset points;

  DrawingPoints({this.points, this.paint});
}
