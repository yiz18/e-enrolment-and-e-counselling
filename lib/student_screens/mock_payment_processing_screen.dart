import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../models/payment.dart';

/// Simulated payment processing UI shown after the student selects a method.
///
/// Returns `true` when the user confirms the mock payment, `false` on cancel.
class MockPaymentProcessingScreen extends StatelessWidget {
  const MockPaymentProcessingScreen({
    super.key,
    required this.method,
    required this.amount,
    required this.courseName,
    required this.studentReference,
    required this.billReference,
  });

  final PaymentMethod method;
  final double amount;
  final String courseName;
  final String studentReference;
  final String billReference;

  static String formatAmount(double amount) =>
      'RM ${amount.toStringAsFixed(2)}';

  void _confirm(BuildContext context) {
    Navigator.pop(context, true);
  }

  void _cancel(BuildContext context) {
    Navigator.pop(context, false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(_appBarTitle),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: switch (method) {
          PaymentMethod.fpx => _FpxMockBody(
              amount: amount,
              courseName: courseName,
              studentReference: studentReference,
              billReference: billReference,
              onConfirm: () => _confirm(context),
              onCancel: () => _cancel(context),
            ),
          PaymentMethod.creditCard => _CreditCardMockBody(
              amount: amount,
              courseName: courseName,
              onConfirm: () => _confirm(context),
              onCancel: () => _cancel(context),
            ),
          PaymentMethod.duitNow => _DuitNowMockBody(
              amount: amount,
              courseName: courseName,
              onConfirm: () => _confirm(context),
              onCancel: () => _cancel(context),
            ),
        },
      ),
    );
  }

  String get _appBarTitle {
    return switch (method) {
      PaymentMethod.fpx => 'FPX Online Banking',
      PaymentMethod.creditCard => 'Credit Card Payment',
      PaymentMethod.duitNow => 'DuitNow QR Payment',
    };
  }
}

class _AmountSummaryCard extends StatelessWidget {
  const _AmountSummaryCard({
    required this.amount,
    required this.courseName,
    this.studentReference,
    this.billReference,
  });

  final double amount;
  final String courseName;
  final String? studentReference;
  final String? billReference;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              courseName,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 10),
            Text(
              MockPaymentProcessingScreen.formatAmount(amount),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.blueAccent,
              ),
            ),
            if (studentReference != null) ...[
              const SizedBox(height: 8),
              Text(
                'Student Ref: $studentReference',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
            if (billReference != null) ...[
              const SizedBox(height: 4),
              Text(
                'Bill Ref: $billReference',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FpxBankInfo {
  const _FpxBankInfo({
    required this.name,
    required this.initials,
    required this.brandColor,
  });

  final String name;
  final String initials;
  final Color brandColor;

  static const List<_FpxBankInfo> all = [
    _FpxBankInfo(
      name: 'Maybank',
      initials: 'MB',
      brandColor: Color(0xFFFFCC00),
    ),
    _FpxBankInfo(
      name: 'CIMB Bank',
      initials: 'CB',
      brandColor: Color(0xFFEC1C24),
    ),
    _FpxBankInfo(
      name: 'Public Bank',
      initials: 'PB',
      brandColor: Color(0xFF0054A6),
    ),
    _FpxBankInfo(
      name: 'RHB Bank',
      initials: 'RH',
      brandColor: Color(0xFF0066B3),
    ),
    _FpxBankInfo(
      name: 'Hong Leong Bank',
      initials: 'HL',
      brandColor: Color(0xFF0072CE),
    ),
  ];

  static _FpxBankInfo forName(String name) {
    return all.firstWhere(
      (bank) => bank.name == name,
      orElse: () => all.first,
    );
  }
}

class _FpxMockBody extends StatefulWidget {
  const _FpxMockBody({
    required this.amount,
    required this.courseName,
    required this.studentReference,
    required this.billReference,
    required this.onConfirm,
    required this.onCancel,
  });

  final double amount;
  final String courseName;
  final String studentReference;
  final String billReference;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  State<_FpxMockBody> createState() => _FpxMockBodyState();
}

class _FpxMockBodyState extends State<_FpxMockBody> {
  String _selectedBank = AppConfig.paymentBankName;

  Future<void> _proceedToInternetBanking() async {
    final bank = _FpxBankInfo.forName(_selectedBank);

    final confirmed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => _FpxInternetBankingLoginScreen(
          bank: bank,
          amount: widget.amount,
          studentReference: widget.studentReference,
          billReference: widget.billReference,
        ),
      ),
    );

    if (confirmed == true && mounted) {
      widget.onConfirm();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.yellow.shade700,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Icon(Icons.account_balance, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'FPX Secure Payment (Simulation)',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _AmountSummaryCard(
          amount: widget.amount,
          courseName: widget.courseName,
          studentReference: widget.studentReference,
          billReference: widget.billReference,
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select Your Bank',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedBank,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  items: _FpxBankInfo.all
                      .map(
                        (bank) => DropdownMenuItem(
                          value: bank.name,
                          child: Row(
                            children: [
                              _FpxBankLogo(bank: bank, size: 28),
                              const SizedBox(width: 10),
                              Text(bank.name),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _selectedBank = value);
                  },
                ),
                const SizedBox(height: 16),
                _MockField(label: 'Merchant', value: AppConfig.paymentAccountName),
                _MockField(
                  label: 'Account',
                  value: AppConfig.paymentAccountNumber,
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'You will be redirected to $_selectedBank internet banking '
                    'to authorise this simulated payment.',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _proceedToInternetBanking,
          child: const Text('Proceed to Internet Banking'),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: widget.onCancel,
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _FpxBankLogo extends StatelessWidget {
  const _FpxBankLogo({required this.bank, this.size = 48});

  final _FpxBankInfo bank;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bank.brandColor,
        borderRadius: BorderRadius.circular(size * 0.2),
      ),
      alignment: Alignment.center,
      child: Text(
        bank.initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: size * 0.32,
        ),
      ),
    );
  }
}

class _FpxInternetBankingLoginScreen extends StatefulWidget {
  const _FpxInternetBankingLoginScreen({
    required this.bank,
    required this.amount,
    required this.studentReference,
    required this.billReference,
  });

  final _FpxBankInfo bank;
  final double amount;
  final String studentReference;
  final String billReference;

  @override
  State<_FpxInternetBankingLoginScreen> createState() =>
      _FpxInternetBankingLoginScreenState();
}

class _FpxInternetBankingLoginScreenState
    extends State<_FpxInternetBankingLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_formKey.currentState?.validate() != true) return;

    final confirmed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => _FpxTransactionSummaryScreen(
          bank: widget.bank,
          amount: widget.amount,
          studentReference: widget.studentReference,
          billReference: widget.billReference,
        ),
      ),
    );

    if (confirmed == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text('${widget.bank.name} Internet Banking'),
        backgroundColor: widget.bank.brandColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    _FpxBankLogo(bank: widget.bank, size: 64),
                    const SizedBox(height: 12),
                    Text(
                      widget.bank.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Simulated Internet Banking',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _usernameController,
                        decoration: _inputDecoration('Username'),
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Username is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: _inputDecoration('Password'),
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _login(),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Password is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Simulation only — no real authentication.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.bank.brandColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Login'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}

class _FpxTransactionSummaryScreen extends StatelessWidget {
  const _FpxTransactionSummaryScreen({
    required this.bank,
    required this.amount,
    required this.studentReference,
    required this.billReference,
  });

  final _FpxBankInfo bank;
  final double amount;
  final String studentReference;
  final String billReference;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text('${bank.name} — Confirm Transfer'),
        backgroundColor: bank.brandColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _FpxBankLogo(bank: bank, size: 40),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Transaction Summary',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 28),
                    _MockField(
                      label: 'Merchant',
                      value: AppConfig.paymentAccountName,
                    ),
                    _MockField(
                      label: 'Amount',
                      value: MockPaymentProcessingScreen.formatAmount(amount),
                    ),
                    _MockField(label: 'Student Ref', value: studentReference),
                    _MockField(label: 'Bill Ref', value: billReference),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Please review the details above before confirming '
                        'this simulated transfer.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: bank.brandColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Confirm Transfer'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreditCardMockBody extends StatefulWidget {
  const _CreditCardMockBody({
    required this.amount,
    required this.courseName,
    required this.onConfirm,
    required this.onCancel,
  });

  final double amount;
  final String courseName;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  State<_CreditCardMockBody> createState() => _CreditCardMockBodyState();
}

class _CreditCardMockBodyState extends State<_CreditCardMockBody> {
  final _formKey = GlobalKey<FormState>();
  final _cardController = TextEditingController(text: '4111 1111 1111 1111');
  final _nameController = TextEditingController(text: 'JOHN DOE');
  final _expiryController = TextEditingController(text: '12/28');
  final _cvvController = TextEditingController(text: '123');

  @override
  void dispose() {
    _cardController.dispose();
    _nameController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  void _submitPayment() {
    if (_formKey.currentState?.validate() != true) return;
    widget.onConfirm();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AmountSummaryCard(
            amount: widget.amount,
            courseName: widget.courseName,
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Card Details',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _cardController,
                    keyboardType: TextInputType.number,
                    decoration: _inputDecoration('Card Number'),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Card number is required';
                      }
                      final digits = value.replaceAll(RegExp(r'\D'), '');
                      if (digits.length != 16) {
                        return 'Card number must be 16 digits';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nameController,
                    decoration: _inputDecoration('Cardholder Name'),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Cardholder name is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _expiryController,
                          decoration: _inputDecoration('Expiry (MM/YY)'),
                          validator: (value) {
                            final trimmed = value?.trim() ?? '';
                            if (trimmed.isEmpty) {
                              return 'Expiry is required';
                            }
                            if (!RegExp(r'^\d{2}/\d{2}$').hasMatch(trimmed)) {
                              return 'Use MM/YY format';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _cvvController,
                          obscureText: true,
                          keyboardType: TextInputType.number,
                          decoration: _inputDecoration('CVV'),
                          validator: (value) {
                            final trimmed = value?.trim() ?? '';
                            if (trimmed.isEmpty) {
                              return 'CVV is required';
                            }
                            if (!RegExp(r'^\d{3,4}$').hasMatch(trimmed)) {
                              return 'CVV must be 3 or 4 digits';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.lock_outline,
                          size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 6),
                      Text(
                        'Secured by simulated payment gateway',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _submitPayment,
            child: Text('Pay ${MockPaymentProcessingScreen.formatAmount(widget.amount)}'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: widget.onCancel,
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}

class _DuitNowMockBody extends StatelessWidget {
  const _DuitNowMockBody({
    required this.amount,
    required this.courseName,
    required this.onConfirm,
    required this.onCancel,
  });

  final double amount;
  final String courseName;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AmountSummaryCard(amount: amount, courseName: courseName),
        const SizedBox(height: 16),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.pink.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'DuitNow QR',
                    style: TextStyle(
                      color: Colors.pink.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade300, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const _MockQrPattern(),
                ),
                const SizedBox(height: 16),
                Text(
                  MockPaymentProcessingScreen.formatAmount(amount),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Scan this QR code with your banking app to complete payment.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 12),
                Text(
                  'Simulation only — no real transfer will occur.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: onConfirm,
          child: const Text('I Have Completed Payment'),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: onCancel,
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _MockQrPattern extends StatelessWidget {
  const _MockQrPattern();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 11,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
        ),
        itemCount: 121,
        itemBuilder: (context, index) {
          final row = index ~/ 11;
          final col = index % 11;
          final filled = (row + col + index) % 3 != 0;
          return DecoratedBox(
            decoration: BoxDecoration(
              color: filled ? Colors.black : Colors.white,
            ),
          );
        },
      ),
    );
  }
}

class _MockField extends StatelessWidget {
  const _MockField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
