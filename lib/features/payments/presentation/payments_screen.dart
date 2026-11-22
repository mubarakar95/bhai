import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/colors.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/app_providers.dart';

import '../../../core/widgets/replica_header_scaffold.dart';

class PaymentsScreen extends ConsumerWidget {
  final Stay stay;

  const PaymentsScreen({Key? key, required this.stay}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ReplicaHeaderScaffold(
      title: '${stay.person?.name ?? "Guest"} Ledger',
      showBackButton: true,
      actions: [
        // Also allowed after checkout, so late-collected dues / deferred refunds can be recorded.
        IconButton(
            icon: const Icon(Icons.add_card_rounded, color: AppColors.primaryPill),
            tooltip: 'Record Payment',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AddPaymentDialog(stay: stay),
              );
            },
          ),
      ],
      body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Billing Status Card
              ref.watch(billingSummaryProvider(stay.id)).when(
                    data: (billing) {
                      if (billing == null) return const SizedBox();
                      final isPending = billing.pendingAmount > 0;
                      return Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.glassCard,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: isPending ? AppColors.alertRed : AppColors.verifiedGreen,
                            width: 1.5,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x0F000000),
                              blurRadius: 20,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'CURRENT PENDING BALANCE',
                                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                        color: isPending ? AppColors.alertRed : AppColors.verifiedGreen,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                        letterSpacing: 0.5,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '₹${billing.pendingAmount.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w800,
                                    color: isPending ? AppColors.alertRed : AppColors.verifiedGreen,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('Total Due: ₹${billing.totalAmountDue.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 2),
                                Text('Total Paid: ₹${billing.totalPaid.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, s) => Text('Error calculating billing: $e'),
                  ),
              const SizedBox(height: 20),

              // Action Bar Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'TRANSACTIONS REGISTER',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryPill,
                            letterSpacing: 0.5,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryPill,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AddPaymentDialog(stay: stay),
                        );
                      },
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('RECORD PAYMENT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Payments Table List
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.glassCard,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: PaymentsListWidget(stayId: stay.id),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

// --- PAYMENTS LIST WIDGET ---
class PaymentsListWidget extends ConsumerWidget {
  final String stayId;

  const PaymentsListWidget({Key? key, required this.stayId}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsState = ref.watch(paymentsProvider(stayId));

    return paymentsState.when(
      data: (payments) {
        if (payments.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No recorded payment transactions found for this stay.',
                style: TextStyle(fontStyle: FontStyle.italic, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: payments.length,
          separatorBuilder: (context, idx) => const Divider(height: 1, color: AppColors.glassBorder),
          itemBuilder: (context, idx) {
            final payment = payments[idx];
            final isRefund = payment.paymentType == PaymentCategory.refund;

            return ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isRefund ? AppColors.alertBg : AppColors.verifiedBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isRefund ? Icons.keyboard_return_rounded : Icons.add_rounded,
                  color: isRefund ? AppColors.alertRed : AppColors.verifiedGreen,
                  size: 20,
                ),
              ),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${payment.paymentType.toString().split('.').last.toUpperCase()} (${payment.paymentMode.toUpperCase()})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Text(
                    '${isRefund ? "-" : "+"} ₹${payment.amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: isRefund ? AppColors.alertRed : AppColors.verifiedGreen,
                    ),
                  ),
                ],
              ),
              subtitle: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      payment.notes ?? 'No notes provided',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
                  Text(
                    DateFormat('dd-MMM-yyyy hh:mm a').format(payment.paidAt),
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Error loading payments: $e')),
    );
  }
}

// --- RECORD NEW TRANSACTION DIALOG ---
class AddPaymentDialog extends ConsumerStatefulWidget {
  final Stay stay;

  const AddPaymentDialog({Key? key, required this.stay}) : super(key: key);

  @override
  ConsumerState<AddPaymentDialog> createState() => _AddPaymentDialogState();
}

class _AddPaymentDialogState extends ConsumerState<AddPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  PaymentCategory _selectedType = PaymentCategory.rent;
  String _selectedMode = 'upi';

  final List<String> _modes = ['upi', 'cash', 'bank_transfer', 'card'];

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (amount <= 0) return;

    final newPayment = Payment(
      id: '',
      stayId: widget.stay.id,
      personId: widget.stay.personId,
      ownerId: widget.stay.ownerId,
      paymentType: _selectedType,
      amount: amount,
      paymentMode: _selectedMode,
      paidAt: DateTime.now(),
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      recordedBy: widget.stay.ownerId,
      createdAt: DateTime.now(),
    );

    await ref.read(paymentsProvider(widget.stay.id).notifier).addPayment(newPayment);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction recorded successfully.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: Row(
        children: const [
          Icon(Icons.payments_rounded, color: AppColors.primaryPill),
          SizedBox(width: 10),
          Text('RECORD TRANSACTION', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<PaymentCategory>(
                value: _selectedType,
                items: PaymentCategory.values
                    .map((type) => DropdownMenuItem(
                          value: type,
                          child: Text(type.toString().split('.').last.toUpperCase()),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedType = val);
                  }
                },
                decoration: const InputDecoration(labelText: 'Transaction Type', prefixIcon: Icon(Icons.category_rounded)),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Transaction Amount (₹) *',
                  prefixIcon: Icon(Icons.currency_rupee_rounded),
                  hintText: 'e.g. 5000',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Required';
                  final amt = double.tryParse(value.trim());
                  if (amt == null || amt <= 0) return 'Must be a positive number';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedMode,
                items: _modes
                    .map((mode) => DropdownMenuItem(
                          value: mode,
                          child: Text(mode.toUpperCase().replaceAll('_', ' ')),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedMode = val);
                  }
                },
                decoration: const InputDecoration(labelText: 'Payment Mode', prefixIcon: Icon(Icons.account_balance_wallet_rounded)),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes / Description',
                  prefixIcon: Icon(Icons.note_alt_rounded),
                  hintText: 'e.g. Rent for Sept 2026',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryPill,
            shape: const StadiumBorder(),
          ),
          onPressed: _submit,
          child: const Text('SAVE RECORD'),
        ),
      ],
    );
  }
}
