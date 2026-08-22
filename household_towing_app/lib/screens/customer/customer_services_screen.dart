import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import '../../widgets/service_action_card.dart';
import 'booking_screen.dart';
import '../../widgets/customer_drawer.dart';

class CustomerServicesScreen extends StatelessWidget {
  const CustomerServicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      drawer: const CustomerDrawer(),
      appBar: AppBar(
        title: const Text('Book a Service'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppTheme.textSlateDark,
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
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const BookingScreen(serviceType: 'Household'),
                      ),
                    );
                  },
                ),
                ServiceActionCard(
                  title: 'Vehicle\nTowing',
                  icon: Icons.car_repair,
                  backgroundColor: AppTheme.towingOrange,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const BookingScreen(serviceType: 'Towing'),
                      ),
                    );
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
