import 'package:flutter/material.dart';

// La classe ThemeNotifier gestisce il tema dell'applicazione e notifica i listener quando il tema cambia
class ThemeNotifier with ChangeNotifier {
  ThemeData _themeData;

  ThemeNotifier(this._themeData);

  ThemeData get themeData => _themeData; // getter

  // setter per impostare un nuovo tema e notificare i listener se il tema cambia
  set themeData(ThemeData themeData) {
    if (_themeData != themeData) {
      _themeData = themeData;
      notifyListeners();
    }
  }
}
