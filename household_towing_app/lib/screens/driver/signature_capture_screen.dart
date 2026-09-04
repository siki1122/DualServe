import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/task_model.dart';
import '../../services/storage_service.dart';
import '../../services/billing_service.dart';
import '../../services/task_service.dart';
import '../../utils/app_theme.dart';
import 'package:image_picker/image_picker.dart';
import 'package:household_towing_app/utils/app_theme.dart';


class SignatureCaptureScreen extends StatefulWidget {
  final Task task;
  final Map<String, dynamic>? transactionData;

  const SignatureCaptureScreen({super.key, required this.task, this.transactionData});

  @override
  State<SignatureCaptureScreen> createState() => _SignatureCaptureScreenState();
}

class _SignatureCaptureScreenState extends State<SignatureCaptureScreen> {
  final SignatureController _controller = SignatureController(
    penStrokeWidth: 5,
    penColor: AppTheme.textSlateDark,
    exportBackgroundColor: Colors.white,
  );
  
  bool _isSaving = false;
  final StorageService _storageService = StorageService();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveSignature() async {
    if (_controller.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a signature first')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final Uint8List? signatureData = await _controller.toPngBytes();
      if (signatureData != null) {
        final String? url = await _storageService.uploadSignature(widget.task.id, signatureData);
        
        if (url != null) {
          if (widget.transactionData != null) {
            final td = widget.transactionData!;
            final billingService = BillingService();
            await billingService.recordTransaction(
              taskId: td['taskId'],
              bookingId: td['bookingId'],
              customerId: td['customerId'],
              providerId: td['providerId'],
              serviceType: td['serviceType'],
              specificService: td['specificService'],
              selectedSubServices: td['selectedSubServices'],
              serviceDetails: td['serviceDetails'],
              distanceTraveled: td['distanceTraveled'],
              basePrice: td['basePrice'],
              distanceSurcharge: td['distanceSurcharge'],
              nightDifferential: td['nightDifferential'],
              finalCost: td['finalCost'],
              additionalCost: td['additionalCost'],
              providerNotes: td['providerNotes'],
            );
            
            final taskService = TaskService();
            await taskService.updateTaskCompletion(
              td['taskId'],
              bookingId: td['bookingId'],
              finalCost: td['finalCost'],
            );
          }
          
          await FirebaseFirestore.instance.collection('tasks').doc(widget.task.id).update({
            'customerSignatureUrl': url,
            'status': TaskStatus.completed.name,
          });
          
          if (mounted) {
            Navigator.pop(context, true); // Return success
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to upload signature.')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save signature: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Signature'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textSlateDark,
        elevation: 0,
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Please have the customer sign below to confirm completion of service.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400, width: 2),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Signature(
                    controller: _controller,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving ? null : () => _controller.clear(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Clear'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveSignature,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isSaving
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white))
                        : const Text('Submit', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
