import 'package:flutter/material.dart';
import '../services/report_service.dart';

class ReportSheet extends StatefulWidget {
  final String reportedUserId;
  final String reportedUsername;

  const ReportSheet({
    super.key,
    required this.reportedUserId,
    required this.reportedUsername,
  });

  @override
  State<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<ReportSheet> {
  final _reasonController = TextEditingController();
  final _proofController = TextEditingController();
  bool _submitting = false;
  String? _error;

  Future<void> _submit() async {
    final reason = _reasonController.text.trim();
    final proof = _proofController.text.trim();

    if (reason.length < 10) {
      setState(() => _error =
        'Reason must be at least 10 characters');
      return;
    }
    if (proof.length < 10) {
      setState(() => _error =
        'Proof must be at least 10 characters');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ReportService.submitReport(
        reportedId: widget.reportedUserId,
        reportedUsername: widget.reportedUsername,
        reason: reason,
        reporterProof: proof,
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Report submitted. They have 80 hours to respond.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() => _error =
        '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _proofController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 16, bottom: bottom + 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: const [
                Icon(Icons.report, color: Colors.orange),
                SizedBox(width: 8),
                Text('Report User',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  )),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'You are reporting @${widget.reportedUsername}.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
              ),
            ),

            const SizedBox(height: 20),

            // Reason
            const Text('Reason for reporting *',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
              )),
            const SizedBox(height: 6),
            TextField(
              controller: _reasonController,
              maxLength: 300,
              maxLines: 3,
              minLines: 2,
              decoration: InputDecoration(
                hintText:
                    'Explain what happened. Be specific — '
                    'e.g. "We partnered for gym but they never '
                    'showed up."',
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
              ),
            ),

            const SizedBox(height: 16),

            // Reporter proof
            const Text('Your proof *',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
              )),
            const SizedBox(height: 6),
            TextField(
              controller: _proofController,
              maxLength: 500,
              maxLines: 4,
              minLines: 3,
              decoration: InputDecoration(
                hintText:
                    'Describe your evidence. Include chat excerpts, '
                    'dates, or any facts. This protects you from '
                    'false-reporting accusations.',
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
              ),
            ),

            const SizedBox(height: 12),

            // Warning box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline,
                    color: Colors.orange, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'The reported user will have 80 hours to submit '
                      'their own proof. Both sides will be reviewed '
                      'before any action is taken.',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            if (_error != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Text(_error!,
                  style: const TextStyle(
                    color: Colors.red, fontSize: 12)),
              ),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _submitting
                        ? null
                        : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _submitting
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                      : const Text('Submit Report',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
