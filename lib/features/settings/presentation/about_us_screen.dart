import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../../../core/widgets/replica_header_scaffold.dart';

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ReplicaHeaderScaffold(
      title: 'About Us',
      showBackButton: true,
      body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.glassCard,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: AppColors.glassBorder),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0F000000),
                      blurRadius: 20,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/logo.png',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: AppColors.brandBlue,
                            child: const Icon(Icons.shield_rounded, size: 28, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bhai App',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Smart Guest Worker & Rental Management',
                            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Purpose & Vision',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Our application is designed specifically for Paying Guest (PG) accommodations, hostellers, and room rental owners across India. It simplifies daily tenant management, rent billing settlements, room occupancy tracking, and official guest identity logging.',
                style: TextStyle(fontSize: 15, height: 1.5, color: AppColors.textMain),
              ),
              const SizedBox(height: 20),
              Text(
                'Security & Identity Verification',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Safety and compliance are at the heart of our platform. We provide seamless Aadhaar identity validation, platform-wide guest blacklist checks, and 1-click Official Guest Registration PDF export formatted to verified tenant and resident registry standards.',
                style: TextStyle(fontSize: 15, height: 1.5, color: AppColors.textMain),
              ),
              const SizedBox(height: 24),

              // Mubarak Tech Watermark Branding
              Center(
                child: Opacity(
                  opacity: 0.85,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.glassCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: Image.asset(
                      'assets/mubarak_tech_logo.png',
                      height: 44,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Bottom Build & Version Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.verifiedBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.verifiedGreen.withOpacity(0.3)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.verified_rounded, color: AppColors.verifiedGreen, size: 24),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Version 1.2.0 • Built by Mubarak Technologies',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.verifiedGreen,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
      ),
    );
  }
}
