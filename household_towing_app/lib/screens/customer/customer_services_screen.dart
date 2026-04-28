import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import '../../widgets/service_action_card.dart';
import 'booking_screen.dart';

class CustomerServicesScreen extends StatelessWidget {
  const CustomerServicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Book a Service'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppTheme.textSlateDark,
        automaticallyImplyLeading: false, // Since it's a bottom nav tab
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select a category below to view and book available providers in your area.',
              style: TextStyle(color: AppTheme.textSlateMedium, fontSize: 16),
            ),
            const SizedBox(height: 24),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                ServiceActionCard(
                  title: 'Household\nCleaning',
                  icon: Icons.cleaning_services,
                  backgroundColor: AppTheme.householdBlue,
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const BookingScreen(serviceType: 'Cleaning')));
                  },
                ),
                ServiceActionCard(
                  title: 'Vehicle\nTowing',
                  icon: Icons.car_repair,
                  backgroundColor: AppTheme.towingOrange,
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const BookingScreen(serviceType: 'Towing')));
                  },
                ),
                // Placeholders for future services
                ServiceActionCard(
                  title: 'Plumbing',
                  icon: Icons.plumbing,
                  backgroundColor: const Color(0xFF0EA5E9), // Sky Blue
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Plumbing services coming soon!')));
                  },
                ),
                ServiceActionCard(
                  title: 'Electrical',
                  icon: Icons.electrical_services,
                  backgroundColor: const Color(0xFFEAB308), // Yellow
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Electrical services coming soon!')));
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
