import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/theme_notifier.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late int _numOfRows = 10; // Numero di righe nella dashboard
  late bool _darkMode = true; // Modalità scura abilitata o meno
  late double saldo = 1220.78; //default, a causa delle 4 spese pre-esistenti, settiamo il saldo a 0
  late SharedPreferences _prefs; // Istanza delle SharedPreferences

  @override
  void initState() {
    super.initState();
    _loadSettings(); // Carica le impostazioni al momento dell'inizializzazione
  }

  // Carica le impostazioni salvate dalle SharedPreferences
  void _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _numOfRows = _prefs.getInt('numOfRows') ?? 10;
      _darkMode = _prefs.getBool('_darkMode') ?? true;
      saldo = _prefs.getDouble('saldo') ?? 1220.78; //default, a causa delle 4 spese pre-esistenti, settiamo il saldo a 0
    });
  }

  // Aggiorna una specifica impostazione nelle SharedPreferences
  void _updateSetting(String key, dynamic value) {
    if (value is int) {
      _prefs.setInt(key, value);
    } else if (value is bool) {
      _prefs.setBool(key, value);
    } else if (value is double) {
      _prefs.setDouble(key, value);
    }

    setState(() {
      if (key == 'numOfRows') {
        _numOfRows = value;
      } else if (key == '_darkMode') {
        _darkMode = value;
      } else if (key == 'saldo') {
        saldo = value;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: <Widget>[
          // Impostazione per il numero di righe nella dashboard
          ListTile(
            title: const Text('Number of Rows in Dashboard'),
            subtitle: Text('Current: $_numOfRows'),
            trailing: DropdownButton<int>(
              value: _numOfRows,
              onChanged: (newValue) {
                if (newValue != null) {
                  _updateSetting('numOfRows', newValue);
                  Navigator.pop(
                      context, true); // Indicate that a change has been made
                }
              },
              items:
                  <int>[5, 10, 15, 20].map<DropdownMenuItem<int>>((int value) {
                return DropdownMenuItem<int>(
                  value: value,
                  child: Text(value.toString()),
                );
              }).toList(),
            ),
          ),
          // Impostazione per abilitare/disabilitare la modalità scura
          ListTile(
            title: const Text("Dark Mode"),
            trailing: Switch(
              value: _darkMode,
              onChanged: (bool val) {
                _updateSetting('_darkMode', val);
                themeNotifier.themeData =
                    val ? ThemeData.dark() : ThemeData.light();
                _prefs.setBool('darkModeEnabled', val);
              },
            ),
          ),
        ],
      ),
    );
  }
}
