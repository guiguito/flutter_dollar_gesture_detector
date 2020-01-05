# dollar_gesture_recognizer

A one dollar gesture recognizer in dart.
It can be very easily used in flutter.

## Origin

This project is a direct translation of the one dollar gesture recognizer that you can find here :
http://depts.washington.edu/acelab/proj/dollar/index.html.

## Things to know

This recognizer : 
- detects gestures that are done with a single uninterrupted gesture,
- needs to be given a set of gestures he can detect to work,
- will always give an answer and returns the gesture detected to be the most similar to the gesture you analyze.
The gesture detected is provided with a score indicating how similar it is.  
- can be given your own gestures to detect.

## Example

You can find a full example of use in [this example project.](https://github.com/guiguito/flutter_dollar_gesture_detector/tree/master/example).
This example is initialized with a set of test gestures to detect. 
You can clear the drawing screen, draw a gesture and add it to the recognizer.

## How to use it? 

To use it you need to : 

Import the recognizer class.
```
import 'package:dollar_gesture_recognizer/dollar_gesture_recognizer.dart';
```

Import the math utils class to be able to use the Point class.
```
import 'package:dollar_gesture_recognizer/math_utils.dart';
```

If needed, import some test gestures.
```
import 'package:dollar_gesture_recognizer/gestures_examples.dart';
```

Init a recognizer.
```
var recognizer = new DollarRecognizer();
```

Init a recognizer with test data.
```
var recognizer = new DollarRecognizer.withGestures(getTestGestures());
```

To try recognize a gesture, provide a list of Point to the recognize methods.
```
List<Point> pointsToRecognize = new List<Point>();
//fill the list with points

//Launch recognition
Result result = await recognizer.recognize(pointsToRecognize, false);
```

Add a gesture to the recognizer.
```
List<Point> newGesture = new List<Point>();
//fill the list with points

recognizer.addGesture("my_gesture", newGesture);
```

Remove a gesture from the recognizer.
```
recognizer.deleteUserGesture("my_gesture");
```