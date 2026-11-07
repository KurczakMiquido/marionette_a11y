import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:marionette_a11y/marionette_a11y.dart';
import 'package:marionette_flutter/marionette_flutter.dart';

import 'home_screen.dart';

void main() {
  if (kDebugMode) {
    MarionetteBinding.ensureInitialized();
    registerA11yExtensions();
  } else {
    WidgetsFlutterBinding.ensureInitialized();
  }
  runApp(const MaterialApp(home: HomeScreen()));
}
