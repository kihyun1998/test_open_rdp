import 'package:flutter/material.dart';

class StatusMessage extends StatelessWidget {
  final String message;

  const StatusMessage({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final isError = message.contains('failed') || message.contains('Error');

    return Card(
      color: isError ? Colors.red.shade50 : Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(
              isError ? Icons.error : Icons.info,
              color: isError ? Colors.red : Colors.green,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: isError ? Colors.red.shade800 : Colors.green.shade800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}