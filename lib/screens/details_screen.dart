import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/database_helper.dart';

import '../services/notification_service.dart';

NotificationService notificationService = NotificationService();

class DetailsScreen extends StatefulWidget {
  const DetailsScreen({super.key});

  @override
  _DetailsScreenState createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen> {
  List<Map<String, dynamic>> _fullExpenseList = []; // Lista completa delle spese
  double _totalExpenses = 0.0;  // Totale delle spese
  double _lastTwoDaysExpenses = 0.0;  // Spese degli ultimi due giorni
  DateTime currentDate = DateTime.now();  // Data corrente
  double saldo = 0.0; // Saldo

  @override
  void initState() {
    super.initState();
    _updateExpenseList(); // Aggiorna la lista delle spese al momento dell'inizializzazione
  }

  // Carica le impostazioni salvate dalle SharedPreferences
  void _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      saldo = prefs.getDouble('saldo') ?? 1220.78; //default, a causa delle 4 spese pre-esistenti, settiamo il saldo a 0
    });
  }

  // Aggiorna la lista delle spese leggendo dal database
  void _updateExpenseList() async {
    List<Map<String, dynamic>> expenses =
        await DatabaseHelper.instance.readAllExpensesOrderedByDate();
    setState(() {
      _fullExpenseList = expenses;
      _calculateExpenses(); // Calcola il totale delle spese e le spese degli ultimi due giorni
    });
  }

  // Calcola il totale delle spese e le spese degli ultimi due giorni
  void _calculateExpenses() {
    _totalExpenses = _fullExpenseList.fold<double>(
        0.0, (prev, element) => prev + (element['amount'] as double));
    _lastTwoDaysExpenses = _fullExpenseList.where((expense) {
      DateTime expenseDate = DateTime.parse(expense['date']);
      return expenseDate.isAfter(currentDate.subtract(const Duration(days: 2)));
    }).fold<double>(
        0.0, (prev, element) => prev + (element['amount'] as double));
  }

  // Formatta l'importo in una stringa con due decimali
  String _formatAmount(double amount) {
    return amount.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    _loadSettings(); // Carica le impostazioni

    // Calcola il saldo contabile e il saldo disponibile
    double accountingBalance = saldo - _totalExpenses + _lastTwoDaysExpenses;
    double availableBalance = saldo - _totalExpenses;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Details'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mostra il saldo disponibile
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Saldo Disponibile: €${_formatAmount(availableBalance)}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            // Mostra il saldo contabile
            Text(
              'Saldo Contabile: €${_formatAmount(accountingBalance)}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            // Mostra la data dell'ultimo aggiornamento dei saldi (impostata al giorno corrente)
            Text(
              'Saldi aggiornati al ${currentDate.day.toString().padLeft(2, '0')}/${currentDate.month.toString().padLeft(2, '0')}/${currentDate.year}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            // Mostra la lista completa delle spese
            Expanded(
              child: ListView.builder(
                itemCount: _fullExpenseList.length,
                itemBuilder: (context, index) {
                  var expense = _fullExpenseList[index];
                  return ListTile(
                    title: Text(expense['description']),
                    subtitle: Text(
                        '${(expense['categories'] as List<String>).join(', ')} - ${expense['date']}'),
                    trailing: Text('€${_formatAmount(expense['amount'])}'),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
