import 'package:flutter/material.dart';

class RatingDialog extends StatefulWidget {
  final Function(int rating, String? feedback) onSubmit;
  
  const RatingDialog({super.key, required this.onSubmit});

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  int _rating = 0;
  final _feedbackController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rate this Service'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'How satisfied are you with the service?',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            
            // Star Rating
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  icon: Icon(
                    index < _rating ? Icons.star : Icons.star_border,
                    size: 40,
                    color: index < _rating ? Colors.amber : Colors.grey,
                  ),
                  onPressed: () {
                    setState(() => _rating = index + 1);
                  },
                );
              }),
            ),
            
            if (_rating > 0) ...[
              const SizedBox(height: 8),
              Text(
                _getRatingText(_rating),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            
            const SizedBox(height: 20),
            
            // Feedback (Optional)
            TextField(
              controller: _feedbackController,
              decoration: const InputDecoration(
                labelText: 'Feedback (Optional)',
                hintText: 'Share your experience...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              maxLength: 200,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _rating == 0
              ? null
              : () {
                  widget.onSubmit(
                    _rating,
                    _feedbackController.text.trim().isEmpty
                        ? null
                        : _feedbackController.text.trim(),
                  );
                  Navigator.pop(context);
                },
          child: const Text('Submit Rating'),
        ),
      ],
    );
  }

  String _getRatingText(int rating) {
    switch (rating) {
      case 1: return 'Poor';
      case 2: return 'Fair';
      case 3: return 'Good';
      case 4: return 'Very Good';
      case 5: return 'Excellent';
      default: return '';
    }
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }
}
