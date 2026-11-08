import 'package:intl/intl.dart';

enum RentalBillingType { hourly, daily, monthly }
enum RoomStatus { available, full, maintenance }
enum PaymentCategory { deposit, advance, rent, refund }
enum ReportCategory { blacklist, police_complaint, flag_for_review }

class Owner {
  final String id;
  final String fullName;
  final String? businessName;
  final String? businessAddress;
  final String mobileNo;
  final String email;
  final String subscriptionPlan;
  final String? avatarUrl;
  final DateTime createdAt;

  Owner({
    required this.id,
    required this.fullName,
    this.businessName,
    this.businessAddress,
    required this.mobileNo,
    required this.email,
    required this.subscriptionPlan,
    this.avatarUrl,
    required this.createdAt,
  });

  factory Owner.fromJson(Map<String, dynamic> json) {
    return Owner(
      id: json['id'].toString(),
      fullName: json['full_name'] as String? ?? '',
      businessName: json['business_name'] as String?,
      businessAddress: json['business_address'] as String? ?? json['address'] as String?,
      mobileNo: json['mobile_no'] as String? ?? '',
      email: json['email'] as String? ?? '',
      subscriptionPlan: json['subscription_plan'] as String? ?? 'free',
      avatarUrl: json['avatar_url'] as String?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'full_name': fullName,
        'business_name': businessName,
        'business_address': businessAddress,
        'mobile_no': mobileNo,
        'email': email,
        'subscription_plan': subscriptionPlan,
        'avatar_url': avatarUrl,
      };

  Owner copyWith({
    String? id,
    String? fullName,
    String? businessName,
    String? businessAddress,
    String? mobileNo,
    String? email,
    String? subscriptionPlan,
    String? avatarUrl,
    DateTime? createdAt,
  }) {
    return Owner(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      businessName: businessName ?? this.businessName,
      businessAddress: businessAddress ?? this.businessAddress,
      mobileNo: mobileNo ?? this.mobileNo,
      email: email ?? this.email,
      subscriptionPlan: subscriptionPlan ?? this.subscriptionPlan,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class Property {
  final String id;
  final String ownerId;
  final String name;
  final String address;
  final String city;
  final String state;
  final String pincode;
  final double? geoLatitude;
  final double? geoLongitude;
  final String propertyType;
  final String contactNo;
  final List<String> photos;
  final DateTime createdAt;

  Property({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.address,
    required this.city,
    required this.state,
    required this.pincode,
    this.geoLatitude,
    this.geoLongitude,
    required this.propertyType,
    required this.contactNo,
    required this.photos,
    required this.createdAt,
  });

  factory Property.fromJson(Map<String, dynamic> json) {
    return Property(
      id: json['id'].toString(),
      ownerId: json['owner_id'].toString(),
      name: json['name'] as String,
      address: json['address'] as String,
      city: json['city'] as String,
      state: json['state'] as String,
      pincode: json['pincode'] as String,
      geoLatitude: json['geo_latitude'] != null
          ? (json['geo_latitude'] as num).toDouble()
          : null,
      geoLongitude: json['geo_longitude'] != null
          ? (json['geo_longitude'] as num).toDouble()
          : null,
      propertyType: json['property_type'] as String? ?? 'PG',
      contactNo: json['contact_no'] as String? ?? '',
      photos: List<String>.from(json['photos'] ?? []),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'owner_id': ownerId,
        'name': name,
        'address': address,
        'city': city,
        'state': state,
        'pincode': pincode,
        'geo_latitude': geoLatitude,
        'geo_longitude': geoLongitude,
        'property_type': propertyType,
        'contact_no': contactNo,
        'photos': photos,
      };
}

class Room {
  final String id;
  final String propertyId;
  final String roomNumber;
  final int capacity;
  final int currentOccupancy;
  final String rentalType; // 'daily', 'monthly', 'both'
  final double dailyRate;
  final double monthlyRate;
  final double hourlyRate;
  final int minimumDays;
  final double minimumCharge;
  final RoomStatus status;
  final List<String> photos;
  final DateTime createdAt;

  Room({
    required this.id,
    required this.propertyId,
    required this.roomNumber,
    required this.capacity,
    required this.currentOccupancy,
    required this.rentalType,
    required this.dailyRate,
    required this.monthlyRate,
    required this.hourlyRate,
    this.minimumDays = 0,
    this.minimumCharge = 0.0,
    required this.status,
    required this.photos,
    required this.createdAt,
  });

  factory Room.fromJson(Map<String, dynamic> json) {
    RoomStatus roomStatus = RoomStatus.available;
    if (json['status'] == 'full') roomStatus = RoomStatus.full;
    if (json['status'] == 'maintenance') roomStatus = RoomStatus.maintenance;

    return Room(
      id: json['id'].toString(),
      propertyId: json['property_id'].toString(),
      roomNumber: json['room_number'] as String? ?? '',
      capacity: (json['capacity'] as num?)?.toInt() ?? 1,
      currentOccupancy: (json['current_occupancy'] as num?)?.toInt() ?? 0,
      rentalType: json['rental_type'] as String? ?? 'monthly',
      dailyRate: (json['daily_rate'] as num?)?.toDouble() ?? 0.0,
      monthlyRate: (json['monthly_rate'] as num?)?.toDouble() ?? 0.0,
      hourlyRate: (json['hourly_rate'] as num?)?.toDouble() ?? 0.0,
      minimumDays: (json['minimum_days'] as num?)?.toInt() ?? 0,
      minimumCharge: (json['minimum_charge'] as num?)?.toDouble() ?? 0.0,
      status: roomStatus,
      photos: List<String>.from(json['photos'] ?? []),
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'property_id': propertyId,
        'room_number': roomNumber,
        'capacity': capacity,
        'current_occupancy': currentOccupancy,
        'rental_type': rentalType,
        'daily_rate': dailyRate,
        'monthly_rate': monthlyRate,
        'hourly_rate': hourlyRate,
        'minimum_days': minimumDays,
        'minimum_charge': minimumCharge,
        'status': status.toString().split('.').last,
        'photos': photos,
      };
}

class Person {
  final String id;
  final String name;
  final String mobileNo;
  final String aadhaarNo;
  final String fatherName;
  final String? motherName;
  final String? wifeName;
  final String? wifeMobileNo;
  final String policeStationCircle;
  final String? aadhaarCardPhoto;
  final String personPhoto;
  final String address;
  final String city;
  final String state;
  final String pincode;
  final DateTime dob;
  final bool isBlacklisted;
  final String? blacklistReason;
  final String? blacklistedBy;
  final DateTime? blacklistedAt;
  final String createdByOwnerId;
  final DateTime createdAt;

  Person({
    required this.id,
    required this.name,
    required this.mobileNo,
    required this.aadhaarNo,
    required this.fatherName,
    this.motherName,
    this.wifeName,
    this.wifeMobileNo,
    required this.policeStationCircle,
    this.aadhaarCardPhoto,
    required this.personPhoto,
    required this.address,
    required this.city,
    required this.state,
    required this.pincode,
    required this.dob,
    required this.isBlacklisted,
    this.blacklistReason,
    this.blacklistedBy,
    this.blacklistedAt,
    required this.createdByOwnerId,
    required this.createdAt,
  });

  factory Person.fromJson(Map<String, dynamic> json) {
    return Person(
      id: json['id'].toString(),
      name: json['name'] as String? ?? '',
      mobileNo: json['mobile_no'] as String? ?? '',
      aadhaarNo: json['aadhaar_no'] as String? ?? '',
      fatherName: json['father_name'] as String? ?? '',
      motherName: json['mother_name'] as String?,
      wifeName: json['wife_name'] as String?,
      wifeMobileNo: json['wife_mobile_no'] as String?,
      policeStationCircle: json['police_station_circle'] as String? ?? '',
      aadhaarCardPhoto: json['aadhaar_card_photo'] as String?,
      personPhoto: json['person_photo'] as String? ?? '',
      address: json['address'] as String? ?? '',
      city: json['city'] as String? ?? '',
      state: json['state'] as String? ?? '',
      pincode: json['pincode'] as String? ?? '',
      dob: json['dob'] != null ? DateTime.parse(json['dob'] as String) : DateTime.now(),
      isBlacklisted: json['is_blacklisted'] as bool? ?? false,
      blacklistReason: json['blacklist_reason'] as String?,
      blacklistedBy: json['blacklisted_by'] as String?,
      blacklistedAt: json['blacklisted_at'] != null
          ? DateTime.parse(json['blacklisted_at'] as String)
          : null,
      createdByOwnerId: json['created_by_owner_id']?.toString() ?? '',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'mobile_no': mobileNo,
        'aadhaar_no': aadhaarNo,
        'father_name': fatherName,
        'mother_name': motherName,
        'wife_name': wifeName,
        'wife_mobile_no': wifeMobileNo,
        'police_station_circle': policeStationCircle,
        'aadhaar_card_photo': aadhaarCardPhoto,
        'person_photo': personPhoto,
        'address': address,
        'city': city,
        'state': state,
        'pincode': pincode,
        'dob': DateFormat('yyyy-MM-dd').format(dob),
        'is_blacklisted': isBlacklisted,
        'blacklist_reason': blacklistReason,
        'blacklisted_by': blacklistedBy,
        'blacklisted_at': blacklistedAt?.toIso8601String(),
        'created_by_owner_id': createdByOwnerId,
      };
}

class Stay {
  final String id;
  final String personId;
  final String roomId;
  final String propertyId;
  final String ownerId;
  final DateTime checkInDate;
  final DateTime? checkOutDate;
  final RentalBillingType rentalTypeUsed;
  final double agreedRate;
  final String status; // 'active', 'checked_out', 'cancelled'
  final DateTime createdAt;
  final Person? person; // Joined person record
  final Room? room; // Joined room record

  Stay({
    required this.id,
    required this.personId,
    required this.roomId,
    required this.propertyId,
    required this.ownerId,
    required this.checkInDate,
    this.checkOutDate,
    required this.rentalTypeUsed,
    required this.agreedRate,
    required this.status,
    required this.createdAt,
    this.person,
    this.room,
  });

  factory Stay.fromJson(Map<String, dynamic> json) {
    RentalBillingType billingType = RentalBillingType.daily;
    if (json['rental_type_used'] == 'hourly') billingType = RentalBillingType.hourly;
    if (json['rental_type_used'] == 'monthly') billingType = RentalBillingType.monthly;

    Person? parsedPerson;
    final rawPerson = json['persons'] ?? json['person'];
    if (rawPerson != null) {
      if (rawPerson is Map<String, dynamic>) {
        parsedPerson = Person.fromJson(rawPerson);
      } else if (rawPerson is Map) {
        parsedPerson = Person.fromJson(Map<String, dynamic>.from(rawPerson));
      } else if (rawPerson is List && rawPerson.isNotEmpty && rawPerson.first is Map) {
        parsedPerson = Person.fromJson(Map<String, dynamic>.from(rawPerson.first as Map));
      }
    }

    Room? parsedRoom;
    final rawRoom = json['rooms'] ?? json['room'];
    if (rawRoom != null) {
      if (rawRoom is Map<String, dynamic>) {
        parsedRoom = Room.fromJson(rawRoom);
      } else if (rawRoom is Map) {
        parsedRoom = Room.fromJson(Map<String, dynamic>.from(rawRoom));
      } else if (rawRoom is List && rawRoom.isNotEmpty && rawRoom.first is Map) {
        parsedRoom = Room.fromJson(Map<String, dynamic>.from(rawRoom.first as Map));
      }
    }

    return Stay(
      id: json['id'].toString(),
      personId: json['person_id'].toString(),
      roomId: json['room_id'].toString(),
      propertyId: json['property_id'].toString(),
      ownerId: json['owner_id'].toString(),
      checkInDate: json['check_in_date'] != null ? DateTime.parse(json['check_in_date'] as String).toLocal() : DateTime.now(),
      checkOutDate: json['check_out_date'] != null
          ? DateTime.parse(json['check_out_date'] as String).toLocal()
          : null,
      rentalTypeUsed: billingType,
      agreedRate: (json['agreed_rate'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'active',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String).toLocal() : DateTime.now(),
      person: parsedPerson,
      room: parsedRoom,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'person_id': personId,
        'room_id': roomId,
        'property_id': propertyId,
        'owner_id': ownerId,
        'check_in_date': checkInDate.toIso8601String(),
        'check_out_date': checkOutDate?.toIso8601String(),
        'rental_type_used': rentalTypeUsed.toString().split('.').last,
        'agreed_rate': agreedRate,
        'status': status,
        if (person != null) 'persons': person!.toJson(),
        if (room != null) 'rooms': room!.toJson(),
      };

  Map<String, dynamic> toDatabaseJson() => {
        'id': id,
        'person_id': personId,
        'room_id': roomId,
        'property_id': propertyId,
        'owner_id': ownerId,
        'check_in_date': checkInDate.toIso8601String(),
        if (checkOutDate != null) 'check_out_date': checkOutDate?.toIso8601String(),
        'rental_type_used': rentalTypeUsed.toString().split('.').last,
        'agreed_rate': agreedRate,
        'status': status,
      };
}

class Payment {
  final String id;
  final String stayId;
  final String personId;
  final String ownerId;
  final PaymentCategory paymentType;
  final double amount;
  final String paymentMode; // cash, upi, bank_transfer, card
  final DateTime paidAt;
  final String? notes;
  final String recordedBy;
  final DateTime createdAt;

  Payment({
    required this.id,
    required this.stayId,
    required this.personId,
    required this.ownerId,
    required this.paymentType,
    required this.amount,
    required this.paymentMode,
    required this.paidAt,
    this.notes,
    required this.recordedBy,
    required this.createdAt,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    PaymentCategory category = PaymentCategory.rent;
    if (json['payment_type'] == 'deposit') category = PaymentCategory.deposit;
    if (json['payment_type'] == 'advance') category = PaymentCategory.advance;
    if (json['payment_type'] == 'refund') category = PaymentCategory.refund;

    return Payment(
      id: json['id'].toString(),
      stayId: json['stay_id'].toString(),
      personId: json['person_id'].toString(),
      ownerId: json['owner_id'].toString(),
      paymentType: category,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      paymentMode: json['payment_mode'] as String? ?? 'cash',
      paidAt: json['paid_at'] != null ? DateTime.parse(json['paid_at'] as String) : DateTime.now(),
      notes: json['notes'] as String?,
      recordedBy: json['recorded_by']?.toString() ?? '',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'stay_id': stayId,
        'person_id': personId,
        'owner_id': ownerId,
        'payment_type': paymentType.toString().split('.').last,
        'amount': amount,
        'payment_mode': paymentMode,
        'paid_at': paidAt.toIso8601String(),
        'notes': notes,
        'recorded_by': recordedBy,
      };
}

class BillingSummary {
  final String stayId;
  final double totalAmountDue;
  final double totalPaid;
  final double pendingAmount;
  final DateTime lastCalculatedAt;

  BillingSummary({
    required this.stayId,
    required this.totalAmountDue,
    required this.totalPaid,
    required this.pendingAmount,
    required this.lastCalculatedAt,
  });

  factory BillingSummary.fromJson(Map<String, dynamic> json) {
    return BillingSummary(
      stayId: json['stay_id'] as String,
      totalAmountDue: (json['total_amount_due'] as num).toDouble(),
      totalPaid: (json['total_paid'] as num).toDouble(),
      pendingAmount: (json['pending_amount'] as num).toDouble(),
      lastCalculatedAt: DateTime.parse(json['last_calculated_at'] as String),
    );
  }
}

class GuestStayHistory {
  final String stayId;
  final String personId;
  final DateTime checkInDate;
  final DateTime? checkOutDate;
  final String status;
  final String propertyType;
  final String propertyName;
  final String propertyCity;
  final String roomNumber;

  GuestStayHistory({
    required this.stayId,
    required this.personId,
    required this.checkInDate,
    this.checkOutDate,
    required this.status,
    required this.propertyType,
    required this.propertyName,
    required this.propertyCity,
    required this.roomNumber,
  });

  factory GuestStayHistory.fromJson(Map<String, dynamic> json) {
    return GuestStayHistory(
      stayId: json['stay_id'] as String,
      personId: json['person_id'] as String,
      checkInDate: DateTime.parse(json['check_in_date'] as String),
      checkOutDate: json['check_out_date'] != null
          ? DateTime.parse(json['check_out_date'] as String)
          : null,
      status: json['status'] as String,
      propertyType: json['property_type'] as String,
      propertyName: json['property_name'] as String,
      propertyCity: json['property_city'] as String,
      roomNumber: json['room_number'] as String,
    );
  }
}
