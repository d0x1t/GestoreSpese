import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'add_edit_expense_screen.dart';
import 'settings_screen.dart';
import 'details_screen.dart';
import 'statistics_screen.dart';
import '../../services/database_helper.dart';

import '../services/notification_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Inizializza il servizio di notifica
NotificationService notificationService = NotificationService();

// Schermata principale della dashboard
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

// Inizializza le notifiche periodiche
void initializeNotifications(BuildContext context) async {
  await notificationService.schedulePeriodicNotification(
      title: "Gestore Spese",
      body: "Ricordati di registrare le tue spese! 💸",
      interval: RepeatInterval
          .everyMinute //da cambiare con daily, per impostare promemoria una volta al giorno.
      );
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Map<String, dynamic>> _fullExpenseList = []; // Lista completa delle spese
  List<Map<String, dynamic>> _visibleExpenseList = []; // Lista delle spese visibili
  bool _isBalanceVisible = true; // Stato della visibilità del saldo
  int _maxRows = 10; // Numero massimo di righe visibili di default
  bool isSearching = false; // Stato della ricerca
  TextEditingController searchController = TextEditingController(); // Controller per la barra di ricerca
  DateTime? startDate; // Data di inizio del filtro
  DateTime? endDate; // Data di fine del filtro
  double saldo = 0.0;

  // Inizializza lo stato iniziale
  @override
  void initState() {
    super.initState();
    _loadSettings();
    _updateExpenseList();
    searchController.addListener(() {
      _filterExpenses();
    });
  }

  // Libera le risorse del controller di ricerca quando il widget viene eliminato
  // Chiamata quando si chiude l'app
  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  // Carica le impostazioni salvate dalle SharedPreferences
  void _loadSettings() async {
    // L'oggetto sharedPreferences salva in locale le relative info. Per poi poterle recuperare se presenti.
    final prefs = await SharedPreferences.getInstance();
    // SetState notifica flutter che lo stato deve essere aggiornato quindi deve richiamare i widget
    setState(() {
      _maxRows = prefs.getInt('numOfRows') ?? 10;
      saldo = prefs.getDouble('saldo') ?? 1220.78; //default, a causa delle 4 spese pre-esistenti, settiamo il saldo a 0
    });

    _updateVisibleExpenses();
  }

  // Chiamata inizialmente per recuperare tutte le spese dal database 
  void _updateExpenseList() async {
    List<Map<String, dynamic>> expenses =
        await DatabaseHelper.instance.readAllExpensesOrderedByDate();
    setState(() {
      _fullExpenseList = expenses;
    });

    _updateVisibleExpenses();
  }

  // Recupera dalla lista completa le sole spese che devono essere visualizzate sulla schermata di dashboard
  void _updateVisibleExpenses() {
    setState(() {
      _visibleExpenseList = _fullExpenseList.take(_maxRows).toList();
    });
  }

  // Filtra le spese sia per data che per categoria in base alla scelta dell'utente
  void _filterExpenses() {
    final filterText = searchController.text.toLowerCase();
    setState(() {
      // Iteriamo su ogni oggetto della lista e preleviamo solo quelli che soddisfano le condizioni
      _visibleExpenseList = _fullExpenseList.where((expense) {
        final withinDateRange = startDate == null ||
            endDate == null ||
            (DateTime.parse(expense['date'])
                    .isAfter(startDate!.subtract(const Duration(days: 1))) &&
                DateTime.parse(expense['date'])
                    .isBefore(endDate!.add(const Duration(days: 1))));
        final matchesSearchText = (expense['categories'] as List<String>).any(
          (category) => category.toLowerCase().contains(filterText),
        );
        return withinDateRange && matchesSearchText;
      }).toList();
    });
  }

  //Chiamato quando l'utente clicca sull'icona del calendario. Mostra la finestra per selezionare la data.
  Future<void> _selectDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: startDate != null && endDate != null
          ? DateTimeRange(start: startDate!, end: endDate!)
          : null,
    );
    if (picked != null &&
        (picked.start != startDate || picked.end != endDate)) {
      setState(() {
        startDate = picked.start;
        endDate = picked.end;
        _filterExpenses();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    initializeNotifications(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: Icon(
                _isBalanceVisible ? Icons.visibility : Icons.visibility_off),
            onPressed: () =>
                setState(() => _isBalanceVisible = !_isBalanceVisible),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'settings') {
                Navigator.push(context, MaterialPageRoute(builder: (context) => SettingsScreen()),
                ).then((value) => {
                  _loadSettings()
                }).then((value) => {
                  _updateExpenseList()
                });
              } else if (value == 'credits') {
                _showCreditsDialog();
              } else if (value == 'statistics') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => StatisticsScreen()),
                );
              } else if (value == 'recharge') {
                _showRechargeDialog();
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'recharge',
                child: ListTile(
                  leading: Icon(Icons.attach_money),
                  title: Text('Ricarica'),
                ),
              ),
              const PopupMenuItem<String>(
                value: 'statistics',
                child: ListTile(
                  leading: Icon(Icons.show_chart),
                  title: Text('Statistics'),
                ),
              ),
              const PopupMenuItem<String>(
                value: 'settings',
                child: ListTile(
                  leading: Icon(Icons.settings),
                  title: Text('Settings'),
                ),
              ),
              const PopupMenuItem<String>(
                value: 'credits',
                child: ListTile(
                  leading: Icon(Icons.info),
                  title: Text('Credits'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'Saldo Disponibile: ${_isBalanceVisible ? '€${_formatAmount(saldo - _totalExpenses)}' : '***'}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => DetailsScreen()),
                  );
                },
                child: const Text(
                  'VEDI DETTAGLI CONTO >',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                if (isSearching)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: TextField(
                        controller: searchController,
                        decoration: const InputDecoration(
                          hintText: 'Search by category',
                        ),
                      ),
                    ),
                  ),
                if (!isSearching) const Spacer(),
                if (isSearching || startDate != null || endDate != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      searchController.clear();
                      isSearching = false;
                      startDate = null;
                      endDate = null;
                      _filterExpenses();
                    },
                  ),
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    setState(() {
                      isSearching = !isSearching;
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: () => _selectDateRange(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _visibleExpenseList.length,
              itemBuilder: (context, index) {
                var expense = _visibleExpenseList[index];
                return Dismissible(
                  key: UniqueKey(),
                  background: Container(
                    color: Colors.grey,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: const Icon(Icons.edit, color: Colors.white),
                  ),
                  secondaryBackground: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (direction) async {
                    if (direction == DismissDirection.endToStart) {
                      await DatabaseHelper.instance
                          .deleteExpense(expense['id']);
                      _updateExpenseList();
                    } else if (direction == DismissDirection.startToEnd) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              AddEditExpenseScreen(expense: expense),
                        ),
                      ).then((_) => _updateExpenseList());
                    }
                  },
                  child: ListTile(
                    title: Text(expense['description']),
                    subtitle: Text(
                        '${(expense['categories'] as List<String>).join(', ')} - ${expense['date']}'),
                    trailing: Text(_isBalanceVisible
                        ? '€${_formatAmount(expense['amount'])}'
                        : '***'),
                    onLongPress: () => _showOptionsDialog(expense),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: ElevatedButton.icon(
              onPressed: () async {
                await Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AddEditExpenseScreen()));
                _updateExpenseList();
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Expense', style: TextStyle(fontSize: 18)),
            ),
          ),
        ],
      ),
    );
  }

  // Mostra le opzioni per modificare o eliminare una spesa quando avviene una pressione prolungata su un item.
  void _showOptionsDialog(Map<String, dynamic> expense) {
    // ShowDialog è fornita da flutter è utile quando si vuole visualizzare una finestra di dialogo sopra l'interfaccia attuale. 
    // Per questo motivo ha bisogno del context e poi del widget da visualizzare. 
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Option'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddEditExpenseScreen(expense: expense),
                    ),
                  ).then((_) => _updateExpenseList());
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Delete'),
                onTap: () async {
                  Navigator.pop(context);
                  await DatabaseHelper.instance.deleteExpense(expense['id']);
                  _updateExpenseList();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Mostra la finestra di dialogo per ricaricare il saldo
  void _showRechargeDialog() {
    // ShowDialog è fornita da flutter è utile quando si vuole visualizzare una finestra di dialogo sopra l'interfaccia attuale. 
    // Per questo motivo ha bisogno del context e poi del widget da visualizzare. 
    showDialog(
      context: context,
      builder: (BuildContext context) {
        double selectedAmount = 10.0; // Default amount
        TextEditingController otherAmountController = TextEditingController();

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Seleziona l\'importo della ricarica'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    RadioListTile<double>(
                      title: const Text('€10'),
                      value: 10.0,
                      groupValue: selectedAmount,
                      onChanged: (value) {
                        setState(() {
                          selectedAmount = value!;
                        });
                      },
                    ),
                    RadioListTile<double>(
                      title: const Text('€25'),
                      value: 25.0,
                      groupValue: selectedAmount,
                      onChanged: (value) {
                        setState(() {
                          selectedAmount = value!;
                        });
                      },
                    ),
                    RadioListTile<double>(
                      title: const Text('€50'),
                      value: 50.0,
                      groupValue: selectedAmount,
                      onChanged: (value) {
                        setState(() {
                          selectedAmount = value!;
                        });
                      },
                    ),
                    RadioListTile<double>(
                      title: const Text('€100'),
                      value: 100.0,
                      groupValue: selectedAmount,
                      onChanged: (value) {
                        setState(() {
                          selectedAmount = value!;
                        });
                      },
                    ),
                    RadioListTile<double>(
                      title: const Text('Altro'),
                      value: 0.0,
                      groupValue: selectedAmount,
                      onChanged: (value) {
                        setState(() {
                          selectedAmount = value!;
                        });
                      },
                    ),
                    if (selectedAmount == 0.0)
                      TextField(
                        controller: otherAmountController,
                        decoration: const InputDecoration(
                          labelText: 'Importo',
                          hintText: 'Inserisci l\'importo',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Annulla'),
                ),
                TextButton(
                  onPressed: () {
                    final textWithDot =
                        otherAmountController.text.replaceAll(',', '.');
                    double finalAmount = selectedAmount == 0.0
                        ? double.tryParse(textWithDot) ?? 0.0
                        : selectedAmount;
                    _rechargeBalance(finalAmount);
                    Navigator.of(context).pop();
                  },
                  child: const Text('Ricarica'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Ricarica effettivamente il saldo
  void _rechargeBalance(double amount) async {
    final prefs = await SharedPreferences.getInstance();
    double saldoSalvato = prefs.getDouble('saldo') ?? 1220.78;
    double nuovoSaldo = saldoSalvato + amount;
    prefs.setDouble('saldo', nuovoSaldo);

    _loadSettings();
  }

  // Mostra i crediti di sviluppo.
  void _showCreditsDialog() {
    // ShowDialog è fornita da flutter è utile quando si vuole visualizzare una finestra di dialogo sopra l'interfaccia attuale. 
    // Per questo motivo ha bisogno del context e poi del widget da visualizzare. 
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Crediti'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('App sviluppata dal gruppo 9 con tanto ❤️',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text(''),
              Text('0612707115 - Daniele Santoro',
                  style: TextStyle(fontFamily: "Arial")),
              Text('0612705616 - Pierpaolo Paolino',
                  style: TextStyle(fontFamily: "Arial")),
              Text('0612708121 - Federico Maria Raggio',
                  style: TextStyle(fontFamily: "Arial")),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  // Calcola il totale delle spese
  double get _totalExpenses {
    return _fullExpenseList.fold<double>(
        0.0, (prev, element) => prev + (element['amount'] as double));
  }

  // Formatta l'importo in una stringa con due decimali
  String _formatAmount(double amount) {
    return amount.toStringAsFixed(2);
  }
}
