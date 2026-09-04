import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:household_towing_app/services/storage_service.dart';
import 'package:household_towing_app/services/provider_service.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import 'package:household_towing_app/utils/app_theme.dart';


class ProviderVerificationScreen extends StatefulWidget {
  final String providerId;

  const ProviderVerificationScreen({super.key, required this.providerId});

  @override
  State<ProviderVerificationScreen> createState() => _ProviderVerificationScreenState();
}

class _ProviderVerificationScreenState extends State<ProviderVerificationScreen> {
  final StorageService _storageService = StorageService();
  final ProviderService _providerService = ProviderService();

  XFile? _businessPermit;
  XFile? _governmentId;
  bool _isUploading = false;

  Future<void> _pickImage(bool isBusinessPermit) async {
    final XFile? image = await _storageService.pickImage(ImageSource.gallery);
    if (image != null) {
      setState(() {
        if (isBusinessPermit) {
          _businessPermit = image;
        } else {
          _governmentId = image;
        }
      });
    }
  }

  Future<void> _submitVerification() async {
    if (_businessPermit == null || _governmentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload both documents')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      // 1. Upload Business Permit
      final permitUrl = await _storageService.uploadVerificationDocument(
        widget.providerId,
        _businessPermit!,
        'business_permit',
      );

      // 2. Upload Government ID
      final idUrl = await _storageService.uploadVerificationDocument(
        widget.providerId,
        _governmentId!,
        'government_id',
      );

      if (permitUrl != null && idUrl != null) {
        // 3. Update Provider Document
        await _providerService.submitVerificationDocuments(
          widget.providerId,
          permitUrl,
          idUrl,
        );

        if (mounted) {
          await Provider.of<UserProvider>(context, listen: false).loadCurrentUserData();
          _showSuccessDialog();
        }
      } else {
        throw Exception('Failed to upload documents');
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = 'Submission failed. Please check your internet or Firebase Storage CORS settings.';
        if (e.toString().contains('TimeoutException')) {
          errorMsg = 'Upload timed out. This is usually caused by Firebase Storage CORS issues on Web.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: Colors.red, duration: const Duration(seconds: 10)),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Documents Saved'),
        content: const Text(
          'Your documents have been uploaded successfully. Customers can now view them on your profile.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Go back to settings
            },
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(
        title: Text(
          'Business Documents',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppTheme.textSlateDark),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textSlateDark),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Upload Documents for Customers',
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blue[900],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'To ensure the safety of our customers, we require all providers to submit valid business and identification documents.',
              style: GoogleFonts.outfit(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),
            
            // Business Permit Card
            _buildUploadCard(
              title: 'Business Permit',
              subtitle: 'Upload a clear photo of your Mayor\'s Permit or DTI Registration',
              image: _businessPermit,
              onTap: () => _pickImage(true),
            ),
            
            const SizedBox(height: 20),
            
            // Government ID Card
            _buildUploadCard(
              title: 'Government Issued ID',
              subtitle: 'Upload your Driver\'s License, Passport, or National ID',
              image: _governmentId,
              onTap: () => _pickImage(false),
            ),
            
            const SizedBox(height: 40),
            
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isUploading ? null : _submitVerification,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: _isUploading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        'Submit for Review',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                'Data is encrypted and stored securely.',
                style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textSlateMedium),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadCard({
    required String title,
    required String subtitle,
    required XFile? image,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: image != null ? AppTheme.primaryBlue : AppTheme.textSlateLight,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.textSlateDark.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            if (image == null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.cloud_upload_outlined, color: AppTheme.primaryBlue, size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textSlateDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey[600]),
              ),
            ] else ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    kIsWeb
                        ? Image.network(
                          image.path,
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        )
                        : Image.file(
                          File(image.path),
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppTheme.primaryBlue,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Change Document',
                style: GoogleFonts.outfit(
                  color: AppTheme.primaryBlue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
