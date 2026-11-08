import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/colors.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/widgets/replica_header_scaffold.dart';

class ContactUsScreen extends ConsumerStatefulWidget {
  const ContactUsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ContactUsScreen> createState() => _ContactUsScreenState();
}

class _ContactUsScreenState extends ConsumerState<ContactUsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _contactController = TextEditingController();
  final _messageController = TextEditingController();

  String _selectedCategory = 'General Inquiry';
  bool _isSending = false;

  final List<String> _categories = [
    'General Inquiry',
    'Technical Support',
    'Feature Request',
    'Billing & Subscription',
    'Security or Identity Verification Issue',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final owner = ref.read(authProvider).value;
      if (owner != null) {
        if (_nameController.text.isEmpty) {
          _nameController.text = owner.fullName;
        }
        if (_contactController.text.isEmpty) {
          _contactController.text = owner.mobileNo.isNotEmpty ? owner.mobileNo : owner.email;
        }
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _launchWebsite(BuildContext context) async {
    final Uri url = Uri.parse('https://mubaraktech.com');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open website https://mubaraktech.com')),
        );
      }
    }
  }

  Future<void> _sendMessage() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSending = true);

    try {
      final dbService = ref.read(dbServiceProvider);
      await dbService.sendContactMessage(
        name: _nameController.text.trim(),
        contact: _contactController.text.trim(),
        subject: _selectedCategory,
        message: _messageController.text.trim(),
      );

      if (mounted) {
        _messageController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message sent successfully! Our team will get back to you shortly.'),
            backgroundColor: AppColors.verifiedGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: AppColors.alertRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ReplicaHeaderScaffold(
      title: 'Contact Us',
      showBackButton: true,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Developer Info Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DEVELOPED BY',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.textSecondary,
                          letterSpacing: 1,
                          fontSize: 11,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Mubarak Technologies',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 6),
                  const Row(
                    children: [
                      Icon(Icons.location_on_rounded, size: 18, color: AppColors.alertRed),
                      SizedBox(width: 6),
                      Text(
                        'Kollam, Kerala, India',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textMain),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Website Tappable Glass Card
            InkWell(
              onTap: () => _launchWebsite(context),
              borderRadius: BorderRadius.circular(24),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.glassCard,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: AppColors.primaryPill,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.language_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Official Website',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12, color: AppColors.textSecondary),
                          ),
                          const Text(
                            'mubaraktech.com',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.brandBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.open_in_new_rounded, color: AppColors.brandBlue, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Interactive Message Form Card
            Container(
              padding: const EdgeInsets.all(22),
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
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SEND US A MESSAGE',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: AppColors.primaryPill,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Have a question, feedback, or need support? Send us a direct message.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 18),

                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Your Name *',
                        prefixIcon: Icon(Icons.person_rounded),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _contactController,
                      decoration: const InputDecoration(
                        labelText: 'Mobile Number or Email *',
                        prefixIcon: Icon(Icons.contact_phone_rounded),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: _selectedCategory,
                      items: _categories
                          .map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedCategory = val);
                      },
                      decoration: const InputDecoration(
                        labelText: 'Category / Subject *',
                        prefixIcon: Icon(Icons.topic_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _messageController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Your Message / Inquiry *',
                        alignLabelWithHint: true,
                        prefixIcon: Padding(
                          padding: EdgeInsets.only(bottom: 50),
                          child: Icon(Icons.message_rounded),
                        ),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryPill,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: _isSending ? null : _sendMessage,
                        icon: _isSending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.send_rounded, size: 18),
                        label: Text(
                          _isSending ? 'SENDING...' : 'SUBMIT MESSAGE',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
