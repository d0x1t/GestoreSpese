import 'package:flutter/material.dart';
import '../../services/database_helper.dart';

class AddEditExpenseScreen extends StatefulWidget {
  final Map<String, dynamic>? expense;

  const AddEditExpenseScreen({super.key, this.expense});

  @override
  _AddEditExpenseScreenState createState() => _AddEditExpenseScreenState();
}

class _AddEditExpenseScreenState extends State<AddEditExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _dateController = TextEditingController();
  final _descriptionController = TextEditingController();
  List<String> _categories = [];

  @override
  void initState() {
    super.initState();
    if (widget.expense != null) {
      _amountController.text = widget.expense?['amount']?.toString() ?? '';
      _dateController.text = widget.expense?['date']?.toString() ?? '';
      _descriptionController.text = widget.expense?['description']?.toString() ?? '';

      _categories = (widget.expense?['categories'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];
    }
  }

  @override
  void dispose() {
    // Libera le risorse dei controller quando il widget viene eliminato
    _amountController.dispose();
    _dateController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // Salva la spesa nel database
  void _saveExpense() {
    if (_formKey.currentState!.validate()) {
      final textWithDot = _amountController.text.replaceAll(',', '.');
      final newExpense = {
        'amount': double.tryParse(textWithDot),
        'date': _dateController.text,
        'categories': _categories
            .map((c) => c.trim().toLowerCase())
            .toList(),
        'description': _descriptionController.text,
      };
      if (widget.expense == null) {
        DatabaseHelper.instance.createExpense(newExpense);
      } else {
        newExpense['id'] = widget.expense!['id'];
        DatabaseHelper.instance.updateExpense(newExpense);
      }
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.expense == null ? 'Add Expense' : 'Edit Expense'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            // Campo di testo per l'importo
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Amount',
                errorBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.red, width: 2.0),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.red, width: 2.0),
                ),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter an amount';
                }
                if (!RegExp(r'^\d*\.?\,?\d*$').hasMatch(value)) {
                  return 'Please enter a valid number';
                }
                return null;
              },
            ),
            // Campo di testo per la data
            TextFormField(
              controller: _dateController,
              decoration: const InputDecoration(labelText: 'Date'),
              onTap: () async {
                FocusScope.of(context).requestFocus(FocusNode());
                DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  _dateController.text =
                      picked.toIso8601String().substring(0, 10);
                }
              },
              validator: (value) => value != null && value.isNotEmpty
                  ? null
                  : 'Please enter a date',
            ),
            // Campo di testo per le categorie
            TextFormField(
              initialValue: _categories.join(', '),
              decoration: const InputDecoration(
                  labelText: 'Categories (separated by commas)'),
              onChanged: (value) {
                setState(() {
                  _categories = value
                      .split(',')
                      .map((category) => category.trim())
                      .toList();
                });
              },
              validator: (value) => value != null && value.isNotEmpty
                  ? null
                  : 'Please enter at least one category',
            ),
            // Campo di testo per la descrizione
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
              validator: (value) => value != null && value.isNotEmpty
                  ? null
                  : 'Please enter a description',
            ),
            // Pulsante per salvare la spesa
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ElevatedButton(
                onPressed: _saveExpense,
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
