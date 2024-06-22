import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/database_helper.dart';
import 'package:intl/intl.dart';

// La schermata che mostra le statistiche delle spese
class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  _StatisticsScreenState createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  List<Map<String, dynamic>> _expenseList = [];
  final int _topK = 5;
  final Map<String, Color> _categoryColors = {};

  String _selectedExpenseChartType = 'Linea';
  String _selectedCategoryChartType = 'Barre';
  String _selectedTopExpenseType = 'Massime';

  int touchedIndex = -1;

  @override
  void initState() {
    super.initState();
    _updateExpenseList();
  }

  // Aggiorna la lista delle spese leggendo dal database
  void _updateExpenseList() async {
    try {
      List<Map<String, dynamic>> expenses =
          await DatabaseHelper.instance.readAllExpensesOrderedByDate();
      setState(() {
        _expenseList = expenses;
        _assignCategoryColors();
      });
    } catch (e) {
      //print('Error loading expenses: $e');
    }
  }

  // Assegna un colore a ciascuna categoria
  void _assignCategoryColors() {
    final categories =
        _expenseList.expand((e) => e['categories']).toSet().toList();
    categories.asMap().forEach((index, category) {
      _categoryColors[category] = Colors.primaries[index % Colors.primaries.length];
    });
  }

  // Ritorna le top K spese ordinate per importo
  List<Map<String, dynamic>> _getTopKExpenses({bool ascending = false}) {
    List<Map<String, dynamic>> sortedList = List.from(_expenseList);
    sortedList.sort((a, b) =>
        (ascending ? 1 : -1) *
        (a['amount'] as double).compareTo(b['amount'] as double));
    return sortedList.take(_topK).toList();
  }

  // Ritorna la mappa che ha come chiave la categoria e come valore il totale e la media
  // NOTA: una spesa che appartiene a due categorie viene sommata due volte.
  Map<String, dynamic> _getExpensesByCategory() {
    Map<String, List<double>> categoryAmounts = {};
    for (var expense in _expenseList) {
      List<String> categories = List<String>.from(expense[
          'categories']); // Perche ogni spesa può appartenere ad una o piu categorie
      double amount = expense['amount']; // Recupero l'amount della spesa

      // Aggiungo la spesa alla/e categoria/e corrispondente/i
      for (String category in categories) {
        if (categoryAmounts.containsKey(category)) {
          categoryAmounts[category]!.add(amount);
        } else {
          categoryAmounts[category] = [amount];
        }
      }
    }
    // Quindi in categoryAmounts ho la categorie e la relativa lista di spesa per ognuna di essse

    // Creo una mappa categoryTotals che riporta per ogni categoria il totale e la media
    Map<String, dynamic> categoryTotals = {};
    categoryAmounts.forEach((category, amounts) {
      double total = amounts.reduce((a, b) => a + b);
      double average = total / amounts.length;
      categoryTotals[category] = {
        'total': total,
        'average': average,
      };
    });

    return categoryTotals;
  }

  @override
  Widget build(BuildContext context) {
    int currentYear = DateTime.now().year;

    // Filtra le spese per l'anno corrente e raggruppa per data
    Map<DateTime, double> groupedExpenses = {};
    for (var expense in _expenseList) {
      DateTime date = DateFormat('yyyy-MM-dd').parse(expense['date']);
      if (date.year == currentYear) {
        double amount = double.parse(
            expense['amount'].toString().replaceAll(',', '').trim());
        if (groupedExpenses.containsKey(date)) {
          groupedExpenses[date] = groupedExpenses[date]! + amount;
        } else {
          groupedExpenses[date] = amount;
        }
      }
    }

    // Ordina le date
    List<MapEntry<DateTime, double>> sortedEntries = groupedExpenses.entries
        .toList()..sort((a, b) => a.key.compareTo(b.key));

    List<DateTime> dates = sortedEntries.map((e) => e.key).toList();
    List<double> amounts = sortedEntries.map((e) => e.value).toList();
    List<Map<String, dynamic>> topExpenses = _getTopKExpenses();
    List<Map<String, dynamic>> bottomExpenses =
        _getTopKExpenses(ascending: true);
    bool hasData = _expenseList.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistiche'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dropdown per la selezione del tipo di grafico delle spese
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Andamento delle spese',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  DropdownButton<String>(
                    value: _selectedExpenseChartType,
                    items: ['Linea', 'Torta']
                        .map((type) => DropdownMenuItem<String>(
                              value: type,
                              child: Text(type),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedExpenseChartType = value!;
                      });
                    },
                  ),
                ],
              ),
              if (_selectedExpenseChartType == 'Torta')
                const Row(children: [
                  Text(
                    'Suddivisione in percentuale della spesa totale per ogni categoria',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  )
                ]),
              Container(
                height: 300,
                child: hasData
                    ? _selectedExpenseChartType == 'Linea'
                        ? LineChart(
                            LineChartData(
                              lineBarsData: [
                                LineChartBarData(
                                  spots: List.generate(
                                    dates.length,
                                    (index) => FlSpot(
                                        index.toDouble(), amounts[index]),
                                  ),
                                  isCurved: false,
                                  color:
                                      const Color.fromARGB(255, 243, 205, 33),
                                  barWidth: 4,
                                  isStrokeCapRound: true,
                                  belowBarData: BarAreaData(show: false),
                                ),
                              ],
                              titlesData: FlTitlesData(
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 22,
                                    getTitlesWidget: (value, meta) {
                                      if (value % 1 == 0 &&
                                          value.toInt() >= 0 &&
                                          value.toInt() < dates.length) {
                                        return Text(
                                            DateFormat('MMM dd')
                                                .format(dates[value.toInt()]),
                                            style: const TextStyle(
                                              color: Color(0xff68737d),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 9,
                                            ));
                                      }
                                      return Container();
                                    },
                                  ),
                                ),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 40,
                                    interval: 150,
                                    getTitlesWidget: (value, meta) {
                                      return Text(
                                        value.toString(),
                                        style: const TextStyle(
                                          color: Color(0xff68737d),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 9,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                              ),
                              borderData: FlBorderData(show: true),
                              minX: 0,
                              maxX: (dates.length - 1).toDouble(),
                              minY: 0,
                            ),
                          )
                        // Primo grafico a torta
                        : PieChart(
                            PieChartData(
                              sections: _getExpensePieChartSections(),
                              sectionsSpace: 0,
                              centerSpaceRadius: 40,
                              pieTouchData: PieTouchData(touchCallback:
                                  (flTouchEvent, pieTouchResponse) {
                                setState(() {
                                  if (pieTouchResponse == null ||
                                      pieTouchResponse.touchedSection == null) {
                                    touchedIndex = -1;
                                    return;
                                  }
                                  touchedIndex = pieTouchResponse
                                      .touchedSection!.touchedSectionIndex;
                                });
                              }),
                            ),
                          )
                    : const Center(child: Text('Nessun dato disponibile')),
              ),
              if (_selectedExpenseChartType == 'Torta')
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10.0),
                  child: Wrap(
                    spacing: 10.0,
                    runSpacing: 5.0,
                    children: _getPieChartLegend(),
                  ),
                ),
              const SizedBox(height: 20),
              // Dropdown per la selezione del tipo di grafico delle categorie
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Importo medio e totale delle spese',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),

                  DropdownButton<String>(
                    value: _selectedCategoryChartType,
                    items: ['Barre', 'Torta']
                        .map((type) => DropdownMenuItem<String>(
                              value: type,
                              child: Text(type),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCategoryChartType = value!;
                      });
                    },
                  ),
                ],
              ),
              if (_selectedCategoryChartType == 'Torta')
                const Row(children: [
                  Text(
                    'Suddivisione in percentuali delle medie di spesa per ogni categoria',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  )
                ]),
              Container(
                height: 300,
                child: hasData
                    ? _selectedCategoryChartType == 'Barre'
                    ?  BarChart(
                            BarChartData(
                              barGroups: _createBarChartGroups(),
                              titlesData: FlTitlesData(
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (value, meta) {
                                      return Text(
                                        value.toStringAsFixed(2),
                                        style: const TextStyle(fontSize: 8),
                                      );
                                    },
                                    interval: _getLeftTitlesInterval(),
                                    reservedSize: 40,
                                  ),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (value, meta) {
                                      return SideTitleWidget(
                                        axisSide: meta.axisSide,
                                        space: 10,
                                        child: Text(
                                          _getExpensesByCategory()
                                              .keys
                                              .toList()[value.toInt()],
                                          style: const TextStyle(fontSize: 8),
                                        ),
                                      );
                                    },
                                    interval: 1.0,
                                    reservedSize: 32,
                                  ),
                                ),
                                rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                              ),
                              borderData: FlBorderData(
                                  show: true,
                                  border: Border.all(color: Colors.grey)),
                            ),
                          )
                      : PieChart(
                            PieChartData(
                              sections: _getAverageCategoryPieChartSections(),
                              sectionsSpace: 0,
                              centerSpaceRadius: 40,
                              pieTouchData: PieTouchData(touchCallback:
                                  (flTouchEvent, pieTouchResponse) {
                                setState(() {
                                  if (pieTouchResponse == null ||
                                      pieTouchResponse.touchedSection == null) {
                                    touchedIndex = -1;
                                    return;
                                  }
                                  touchedIndex = pieTouchResponse
                                      .touchedSection!.touchedSectionIndex;
                                });
                              }),
                            ),
                          )
                    : const Center(child: Text('Nessun dato disponibile')),
              ),
              if (_selectedCategoryChartType == 'Torta')
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10.0),
                  child: Wrap(
                    spacing: 10.0,
                    runSpacing: 5.0,
                    children: _getPieChartLegend()
                  ),
                ),
              const SizedBox(height: 20),
              // Dropdown per la selezione delle top spese
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Top $_topK uscite',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  DropdownButton<String>(
                    value: _selectedTopExpenseType,
                    items: ['Massime', 'Minime']
                        .map((type) => DropdownMenuItem<String>(
                              value: type,
                              child: Text(type),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedTopExpenseType = value!;
                      });
                    },
                  ),
                ],
              ),
              ...(_selectedTopExpenseType == 'Massime'
                      ? topExpenses
                      : bottomExpenses)
                  .map((expense) => ListTile(
                        title: Text(expense['description']),
                        subtitle: Text(
                            '${(expense['categories'] as List<String>).join(', ')} - ${expense['date']}'),
                        trailing: Text('€${expense['amount']}'),
                      )),
            ],
          ),
        ),
      ),
    );
  }

  // Ritorna i gruppi per il grafico a barre 
  List<BarChartGroupData> _createBarChartGroups() {
    try {
      final expensesByCategory = _getExpensesByCategory(); 
      return expensesByCategory.keys.toList().asMap().entries.map((entry) {
        int index = entry.key;
        String category = entry.value;
        double total = expensesByCategory[category]['total'];
        double average = expensesByCategory[category]['average'];
        return BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: total,
              color: _categoryColors[category],
              width: 10,
            ),
            BarChartRodData(
              toY: average,
              color: _categoryColors[category]!.withOpacity(0.5),
              width: 10,
            ),
          ],
        );
      }).toList();
    } catch (e) {
      //print('Error creating bar chart groups: $e');
      return [];
    }
  }

  // Calcola l'intervallo per le etichette dell'asse sinistro
  double _getLeftTitlesInterval() {
    if (_expenseList.isEmpty) return 1.0;
    double maxAmount = _expenseList
        .map((e) => e['amount'] as double)
        .reduce((a, b) => a > b ? a : b);
    return maxAmount / 5;
  }

  // Primo grafico a torta: suddivisione delle spese per categoria
  List<PieChartSectionData> _getExpensePieChartSections() {
    Map<String, double> categorySums = {};
    double totalAmount = 0.0;

    for (var expense in _expenseList) {
      double amount = expense['amount'];
      List<String> categories = List<String>.from(expense[
          'categories']); // Perche ogni spesa puo appartenere a una o piu categorie
      double splitAmount = amount /
          categories.length; // Se una spesa appartiene a due o piu categorie si distribuisce l'importa di tale per ognuna di esse.
      totalAmount += amount; // Somma di tutte le spese

      // Aggiungi le spese per ogni categoria
      for (var category in categories) {
        if (categorySums.containsKey(category)) {
          categorySums[category] = categorySums[category]! + splitAmount;
        } else {
          categorySums[category] = splitAmount;
        }
      }
    }
// a questo punto ho in totalAmount  tutte le spese
// in categorySums la categoria e la spesa totale per la medesima.

    return categorySums.entries.map((entry) {
      String category = entry.key;
      double categoryTotal = entry.value;
      double percentage = (categoryTotal / totalAmount) * 100;
      return PieChartSectionData(
        color: _categoryColors[category],
        value: categoryTotal,
        title: '${percentage.toStringAsFixed(1)}%',
        radius: 50.0,
        titleStyle: const TextStyle(
          fontSize: 16.0,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      );
    }).toList();
  }

  // Costruisce la legenda del primo grafico a torta
  List<Widget> _getPieChartLegend() {
    final expensesByCategory = _getExpensesByCategory();
    return expensesByCategory.entries.map((entry) {
      String category = entry.key;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 16,
            color: _categoryColors[category],
          ),
          const SizedBox(width: 8),
          Text(category),
        ],
      );
    }).toList();
  }

  // Secondo grafico a torta: media di spesa per categoria
  List<PieChartSectionData> _getAverageCategoryPieChartSections() {
    final expensesByCategory = _getExpensesByCategory();
    double totalAverage =
        expensesByCategory.values.fold(0, (sum, item) => sum + item['average']);
    return expensesByCategory.entries.map((entry) {
      String category = entry.key;
      double categoryAverage = entry.value['average'];
      double percentage = (categoryAverage / totalAverage) * 100;
      return PieChartSectionData(
        color: _categoryColors[category],
        value: categoryAverage,
        title: '${percentage.toStringAsFixed(1)}%',
        radius: 50.0,
        titleStyle: const TextStyle(
          fontSize: 16.0,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      );
    }).toList();
  }

}
