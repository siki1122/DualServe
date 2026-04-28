import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MetricCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color boxColor;
  final String collection;
  final String? status;

  const MetricCard({
    super.key,
    required this.title,
    required this.icon,
    required this.boxColor,
    required this.collection,
    this.status,
  });

  @override
  Widget build(BuildContext context) {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    Query query = firestore.collection(collection);
    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }

    return StreamBuilder<int>(
      stream: query.snapshots().map((s) => s.docs.length),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.grey.withValues(alpha: 0.1), blurRadius: 8),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: boxColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Color(0xFF2563eb), size: 24),
              ),
              const SizedBox(height: 12),
              Text(
                '$count',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: const [
                  Icon(Icons.trending_up, color: Color(0xFF22c55e), size: 16),
                  SizedBox(width: 4),
                  Text(
                    '+12.5%',
                    style: TextStyle(
                      color: Color(0xFF22c55e),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
