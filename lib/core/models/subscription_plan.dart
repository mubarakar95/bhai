import 'models.dart';

class SubscriptionPlanConfig {
  final String id;
  final String name;
  final int price;
  final String billingPeriod;
  final int durationYears;
  final int maxProperties; // -1 indicates unlimited
  final int maxRooms;      // -1 indicates unlimited
  final int maxGuests;     // -1 indicates unlimited
  final String tagline;
  final String description;
  final String savingsText;
  final List<String> features;
  final bool isPopular;
  final bool isBestValue;

  const SubscriptionPlanConfig({
    required this.id,
    required this.name,
    required this.price,
    this.billingPeriod = 'year',
    this.durationYears = 1,
    required this.maxProperties,
    required this.maxRooms,
    required this.maxGuests,
    required this.tagline,
    required this.description,
    this.savingsText = '',
    required this.features,
    this.isPopular = false,
    this.isBestValue = false,
  });

  bool get isUnlimitedProperties => maxProperties == -1;
  bool get isUnlimitedRooms => maxRooms == -1;
  bool get isUnlimitedGuests => maxGuests == -1;

  String get displayName => name;
  String get priceDisplay => price == 0 ? 'Free Forever' : '₹$price for $billingPeriod';

  String get propertiesDisplay => isUnlimitedProperties ? 'Unlimited' : '$maxProperties Property';
  String get maxPropertiesDisplay => isUnlimitedProperties ? 'Unlimited' : '$maxProperties';

  String get roomsDisplay => isUnlimitedRooms ? 'Unlimited' : '$maxRooms Rooms';
  String get maxRoomsDisplay => isUnlimitedRooms ? 'Unlimited' : '$maxRooms';

  String get guestsDisplay => isUnlimitedGuests ? 'Unlimited' : '$maxGuests People';
  String get maxGuestsDisplay => isUnlimitedGuests ? 'Unlimited' : '$maxGuests';

  static const SubscriptionPlanConfig freePlan = SubscriptionPlanConfig(
    id: 'free',
    name: 'Free Tier',
    price: 0,
    billingPeriod: 'forever',
    durationYears: 0,
    maxProperties: -1,
    maxRooms: -1,
    maxGuests: -1,
    tagline: 'Unlimited offline properties, rooms & guests',
    description: 'Unlimited entries on your local device. Cloud sync requires Pro.',
    savingsText: 'Free Forever',
    features: [
      'Unlimited Properties',
      'Unlimited Rooms & Beds',
      'Unlimited Guests Entry',
      'Offline-First Local Storage',
      'Manual Offline Export & Import Backup',
      'PDF Reports with Bhai App Watermark',
    ],
  );

  static const SubscriptionPlanConfig pro1YearPlan = SubscriptionPlanConfig(
    id: 'plan_699',
    name: 'Pro Plan (1 Year)',
    price: 699,
    billingPeriod: '1 Year',
    durationYears: 1,
    maxProperties: -1,
    maxRooms: -1,
    maxGuests: -1,
    tagline: 'Full unlocked access for 1 year',
    description: 'Unlimited properties, unlimited rooms, and unlimited guests.',
    savingsText: 'Standard Annual Plan (₹699/yr)',
    features: [
      'Unlimited Properties',
      'Unlimited Rooms & Beds',
      'Unlimited Guests Capacity',
      'Official Guest Registration Record (PDF)',
      'Real-time Blacklist & Screening',
      'Multi-Device Offline Cloud Sync',
      'Priority Phone & Chat Support',
    ],
  );

  static const SubscriptionPlanConfig pro2YearPlan = SubscriptionPlanConfig(
    id: 'plan_1299',
    name: 'Pro Plan (2 Years)',
    price: 1299,
    billingPeriod: '2 Years',
    durationYears: 2,
    isPopular: true,
    maxProperties: -1,
    maxRooms: -1,
    maxGuests: -1,
    tagline: 'Best value for 2 full years',
    description: 'Unlimited properties, unlimited rooms, and unlimited guests.',
    savingsText: 'Save ₹99 (Only ₹649/yr)',
    features: [
      'Unlimited Properties',
      'Unlimited Rooms & Beds',
      'Unlimited Guests Capacity',
      'Official Guest Registration Record (PDF)',
      'Real-time Blacklist & Screening',
      'Multi-Device Offline Cloud Sync',
      'Priority Phone & Chat Support',
    ],
  );

  static const SubscriptionPlanConfig pro3YearPlan = SubscriptionPlanConfig(
    id: 'plan_1899',
    name: 'Pro Plan (3 Years)',
    price: 1899,
    billingPeriod: '3 Years',
    durationYears: 3,
    isBestValue: true,
    maxProperties: -1,
    maxRooms: -1,
    maxGuests: -1,
    tagline: 'Maximum savings for 3 full years',
    description: 'Unlimited properties, unlimited rooms, and unlimited guests.',
    savingsText: 'Save ₹198 • Best Long-Term Value (₹633/yr)',
    features: [
      'Unlimited Properties',
      'Unlimited Rooms & Beds',
      'Unlimited Guests Capacity',
      'Official Guest Registration Record (PDF)',
      'Real-Time Criminal Screening & Global Blacklist',
      'Multi-Device Offline Cloud Sync',
      'VIP Dedicated Support',
    ],
  );

  static const SubscriptionPlanConfig trialPlan = SubscriptionPlanConfig(
    id: 'trial_60',
    name: 'Pro (60-Day Trial)',
    price: 0,
    billingPeriod: '60 Days Free Trial',
    durationYears: 0,
    maxProperties: -1,
    maxRooms: -1,
    maxGuests: -1,
    tagline: '60 Days Full Premium Access',
    description: 'Enjoy unlimited properties, rooms, and guests for 60 full days.',
    savingsText: 'Free 60-Day Pro Trial Active',
    features: [
      'Unlimited Properties',
      'Unlimited Rooms & Beds',
      'Unlimited Guests Capacity',
      'Official Guest Registration Record (PDF)',
      'Real-time Blacklist & Screening',
      'Multi-Device Offline Cloud Sync',
      'Priority Phone & Chat Support',
    ],
  );

  static const List<SubscriptionPlanConfig> paidPlans = [
    pro1YearPlan,
    pro2YearPlan,
    pro3YearPlan,
  ];

  static const List<SubscriptionPlanConfig> allPlans = [
    freePlan,
    pro1YearPlan,
    pro2YearPlan,
    pro3YearPlan,
  ];

  static const int trialDurationDays = 60;

  static bool isPaidPlan(String? planId) {
    if (planId == null || planId.trim().isEmpty) return false;
    final normalized = planId.toLowerCase().trim();
    return normalized == 'plan_699' ||
        normalized == 'starter' ||
        normalized == '699' ||
        normalized == 'pro_1yr' ||
        normalized == 'plan_1299' ||
        normalized == '1299' ||
        normalized == 'pro_2yr' ||
        normalized == 'plan_1899' ||
        normalized == 'enterprise' ||
        normalized == '1899' ||
        normalized == 'premium' ||
        normalized == 'pro_3yr' ||
        normalized == 'pro';
  }

  static int getTrialDaysRemaining(Owner? owner) {
    if (owner == null) return 0;
    final diff = DateTime.now().difference(owner.createdAt).inDays;
    final remaining = trialDurationDays - diff;
    return remaining > 0 ? remaining : 0;
  }

  static bool isTrialActive(Owner? owner) {
    if (owner == null) return false;
    if (isPaidPlan(owner.subscriptionPlan)) return false;
    return getTrialDaysRemaining(owner) > 0;
  }

  static SubscriptionPlanConfig getEffectivePlan(Owner? owner) {
    if (owner == null) return freePlan;
    if (isPaidPlan(owner.subscriptionPlan)) {
      return getPlan(owner.subscriptionPlan);
    }
    if (isTrialActive(owner)) {
      return trialPlan;
    }
    // 60-day trial ended: automatically converts to Basic / Free tier
    return freePlan;
  }

  static SubscriptionPlanConfig getPlan(String? planId) {
    if (planId == null || planId.trim().isEmpty) return freePlan;
    final normalized = planId.toLowerCase().trim();

    if (normalized == 'trial' || normalized == 'trial_60') {
      return trialPlan;
    }
    if (normalized == 'plan_699' || normalized == 'starter' || normalized == '699' || normalized == 'pro_1yr') {
      return pro1YearPlan;
    }
    if (normalized == 'plan_1299' || normalized == '1299' || normalized == 'pro_2yr') {
      return pro2YearPlan;
    }
    if (normalized == 'plan_1899' || normalized == 'enterprise' || normalized == '1899' || normalized == 'premium' || normalized == 'pro_3yr') {
      return pro3YearPlan;
    }
    if (normalized == 'pro') {
      return pro2YearPlan; // default to popular
    }
    return freePlan;
  }

  // --- Limits Validation Helpers ---

  static ({bool canAdd, String? reason}) checkCanAddProperty({
    required Owner? owner,
    required int currentPropertyCount,
  }) {
    final plan = getEffectivePlan(owner);
    if (plan.isUnlimitedProperties) {
      return (canAdd: true, reason: null);
    }
    if (currentPropertyCount >= plan.maxProperties) {
      final wasTrial = !isPaidPlan(owner?.subscriptionPlan);
      final reason = wasTrial
          ? 'Your 60-Day Premium Trial has ended. The basic plan allows up to ${plan.maxProperties} property. Please purchase a Pro plan to continue enjoying unlimited properties.'
          : '${plan.name} allows a maximum of ${plan.maxProperties} property. You have currently registered $currentPropertyCount property. Please upgrade to Pro Plan for Unlimited Properties.';
      return (canAdd: false, reason: reason);
    }
    return (canAdd: true, reason: null);
  }

  static ({bool canAdd, String? reason}) checkCanAddRoom({
    required Owner? owner,
    required int currentRoomCount,
  }) {
    final plan = getEffectivePlan(owner);
    if (plan.isUnlimitedRooms) {
      return (canAdd: true, reason: null);
    }
    if (currentRoomCount >= plan.maxRooms) {
      final wasTrial = !isPaidPlan(owner?.subscriptionPlan);
      final reason = wasTrial
          ? 'Your 60-Day Premium Trial has ended. The basic plan allows up to ${plan.maxRooms} rooms. Please purchase a Pro plan to continue enjoying unlimited rooms & beds.'
          : '${plan.name} allows a maximum of ${plan.maxRooms} rooms. You currently have $currentRoomCount rooms. Please upgrade to Pro Plan for Unlimited Rooms & Beds.';
      return (canAdd: false, reason: reason);
    }
    return (canAdd: true, reason: null);
  }

  static ({bool canAdd, String? reason}) checkCanAddGuest({
    required Owner? owner,
    required int currentActiveGuestsCount,
  }) {
    final plan = getEffectivePlan(owner);
    if (plan.isUnlimitedGuests) {
      return (canAdd: true, reason: null);
    }
    if (currentActiveGuestsCount >= plan.maxGuests) {
      final wasTrial = !isPaidPlan(owner?.subscriptionPlan);
      final reason = wasTrial
          ? 'Your 60-Day Premium Trial has ended. The basic plan allows up to ${plan.maxGuests} active guests. Please purchase a Pro plan to continue enjoying unlimited guests.'
          : '${plan.name} allows up to ${plan.maxGuests} active guests (20 on Free Tier). You currently have $currentActiveGuestsCount active guests. Please upgrade to Pro Plan for Unlimited Guests.';
      return (canAdd: false, reason: reason);
    }
    return (canAdd: true, reason: null);
  }
}
