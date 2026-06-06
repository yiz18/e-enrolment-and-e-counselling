import 'package:flutter/material.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final TextEditingController cardController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController expiryController = TextEditingController();
  final TextEditingController cvvController = TextEditingController();

  bool isPaid = false;

  void processPayment() {
    setState(() {
      isPaid = true; // simulated success
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Payment"),
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: isPaid
            ? Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.check_circle, color: Colors.green, size: 80),
            SizedBox(height: 20),
            Text(
              "Payment Successful 🎉",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 10),
            Text("Your payment has been processed."),
          ],
        )
            : SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Payment Details",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 20),

              // Card Number
              const Text("Card Number"),
              const SizedBox(height: 8),
              TextField(
                controller: cardController,
                keyboardType: TextInputType.number,
                decoration: inputDecoration("Enter card number"),
              ),

              const SizedBox(height: 16),

              // Name
              const Text("Cardholder Name"),
              const SizedBox(height: 8),
              TextField(
                controller: nameController,
                decoration: inputDecoration("Enter name"),
              ),

              const SizedBox(height: 16),

              // Expiry + CVV
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: expiryController,
                      decoration: inputDecoration("MM/YY"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: cvvController,
                      obscureText: true,
                      decoration: inputDecoration("CVV"),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              // Pay Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: processPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                  ),
                  child: const Text("Pay Now"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }
}