# Flutter example of the dollar_gesture_recognizer_dart library

This project demonstrates how to use the one dollar gesture recognizer library in Flutter.

This example is initialized with a set of test gestures to detect.
 ```
 var recognizer = new DollarRecognizer.withGestures(getTestGestures());
 ```

Here is the list of test gestures available :
![Test gestures](http://depts.washington.edu/acelab/proj/dollar/unistrokes.gif)

When you launch it, you just need to draw on the white screen the gesture.

A snackbar will display the gesture detected.
 
You can clear the drawing screen click on the cross.

You can draw a gesture and add it to the recognizer clicking on the floppy disk and providing a name to the gesture.

Your gesture can then be detected with the others.



