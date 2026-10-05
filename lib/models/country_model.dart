import 'package:flutter/foundation.dart';

@immutable
class Country {
  final String name;
  final String code; // ISO 3166-1 alpha-2
  final String dialCode; // e.g. "+91"
  final String flag; // emoji flag e.g. "🇮🇳"
  final int minLength;
  final int maxLength;
  final String sampleNumber;
  final String? regexPattern;

  const Country({
    required this.name,
    required this.code,
    required this.dialCode,
    required this.flag,
    required this.minLength,
    required this.maxLength,
    required this.sampleNumber,
    this.regexPattern,
  });

  /// Validates national subscriber number (digits only).
  bool isValid(String rawNumber) {
    var cleaned = rawNumber.replaceAll(RegExp(r'\D'), '');
    if (cleaned.isEmpty) return false;

    // Normalize national trunk prefix (leading 0) if user typed e.g. 07xxx in UK
    if (cleaned.startsWith('0') && cleaned.length == maxLength + 1) {
      cleaned = cleaned.substring(1);
    }

    if (cleaned.length < minLength || cleaned.length > maxLength) {
      return false;
    }

    if (regexPattern != null) {
      return RegExp(regexPattern!).hasMatch(cleaned);
    }

    return true;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Country &&
          runtimeType == other.runtimeType &&
          code == other.code &&
          dialCode == other.dialCode;

  @override
  int get hashCode => code.hashCode ^ dialCode.hashCode;
}

class Countries {
  static const Country india = Country(
    name: 'India',
    code: 'IN',
    dialCode: '+91',
    flag: '🇮🇳',
    minLength: 10,
    maxLength: 10,
    sampleNumber: '9876543210',
    regexPattern: r'^[6-9]\d{9}$',
  );

  static const Country unitedStates = Country(
    name: 'United States',
    code: 'US',
    dialCode: '+1',
    flag: '🇺🇸',
    minLength: 10,
    maxLength: 10,
    sampleNumber: '2025550123',
    regexPattern: r'^[2-9]\d{9}$',
  );

  static const Country unitedKingdom = Country(
    name: 'United Kingdom',
    code: 'GB',
    dialCode: '+44',
    flag: '🇬🇧',
    minLength: 10,
    maxLength: 10,
    sampleNumber: '7911123456',
    regexPattern: r'^[1-9]\d{9}$',
  );

  static const Country uae = Country(
    name: 'United Arab Emirates',
    code: 'AE',
    dialCode: '+971',
    flag: '🇦🇪',
    minLength: 9,
    maxLength: 9,
    sampleNumber: '501234567',
    regexPattern: r'^5\d{8}$',
  );

  static const Country saudiArabia = Country(
    name: 'Saudi Arabia',
    code: 'SA',
    dialCode: '+966',
    flag: '🇸🇦',
    minLength: 9,
    maxLength: 9,
    sampleNumber: '501234567',
    regexPattern: r'^5\d{8}$',
  );

  static const Country qatar = Country(
    name: 'Qatar',
    code: 'QA',
    dialCode: '+974',
    flag: '🇶🇦',
    minLength: 8,
    maxLength: 8,
    sampleNumber: '55123456',
    regexPattern: r'^[3567]\d{7}$',
  );

  static const Country oman = Country(
    name: 'Oman',
    code: 'OM',
    dialCode: '+968',
    flag: '🇴🇲',
    minLength: 8,
    maxLength: 8,
    sampleNumber: '91234567',
    regexPattern: r'^[79]\d{7}$',
  );

  static const Country kuwait = Country(
    name: 'Kuwait',
    code: 'KW',
    dialCode: '+965',
    flag: '🇰🇼',
    minLength: 8,
    maxLength: 8,
    sampleNumber: '51234567',
    regexPattern: r'^[569]\d{7}$',
  );

  static const Country defaultCountry = india;

  static const List<Country> all = [
    india,
    unitedStates,
    unitedKingdom,
    uae,
    saudiArabia,
    qatar,
    oman,
    kuwait,
    Country(
      name: 'Bahrain',
      code: 'BH',
      dialCode: '+973',
      flag: '🇧🇭',
      minLength: 8,
      maxLength: 8,
      sampleNumber: '36123456',
      regexPattern: r'^[36]\d{7}$',
    ),
    Country(
      name: 'Canada',
      code: 'CA',
      dialCode: '+1',
      flag: '🇨🇦',
      minLength: 10,
      maxLength: 10,
      sampleNumber: '4165550123',
      regexPattern: r'^[2-9]\d{9}$',
    ),
    Country(
      name: 'Australia',
      code: 'AU',
      dialCode: '+61',
      flag: '🇦🇺',
      minLength: 9,
      maxLength: 9,
      sampleNumber: '412345678',
      regexPattern: r'^4\d{8}$',
    ),
    Country(
      name: 'Germany',
      code: 'DE',
      dialCode: '+49',
      flag: '🇩🇪',
      minLength: 10,
      maxLength: 11,
      sampleNumber: '15123456789',
      regexPattern: r'^\d{10,11}$',
    ),
    Country(
      name: 'France',
      code: 'FR',
      dialCode: '+33',
      flag: '🇫🇷',
      minLength: 9,
      maxLength: 9,
      sampleNumber: '612345678',
      regexPattern: r'^[67]\d{8}$',
    ),
    Country(
      name: 'Singapore',
      code: 'SG',
      dialCode: '+65',
      flag: '🇸🇬',
      minLength: 8,
      maxLength: 8,
      sampleNumber: '81234567',
      regexPattern: r'^[89]\d{7}$',
    ),
    Country(
      name: 'Malaysia',
      code: 'MY',
      dialCode: '+60',
      flag: '🇲🇾',
      minLength: 9,
      maxLength: 10,
      sampleNumber: '123456789',
      regexPattern: r'^1\d{8,9}$',
    ),
    Country(
      name: 'Indonesia',
      code: 'ID',
      dialCode: '+62',
      flag: '🇮🇩',
      minLength: 9,
      maxLength: 12,
      sampleNumber: '81234567890',
      regexPattern: r'^8\d{8,11}$',
    ),
    Country(
      name: 'Philippines',
      code: 'PH',
      dialCode: '+63',
      flag: '🇵🇭',
      minLength: 10,
      maxLength: 10,
      sampleNumber: '9171234567',
      regexPattern: r'^9\d{9}$',
    ),
    Country(
      name: 'Pakistan',
      code: 'PK',
      dialCode: '+92',
      flag: '🇵🇰',
      minLength: 10,
      maxLength: 10,
      sampleNumber: '3001234567',
      regexPattern: r'^3\d{9}$',
    ),
    Country(
      name: 'Bangladesh',
      code: 'BD',
      dialCode: '+880',
      flag: '🇧🇩',
      minLength: 10,
      maxLength: 10,
      sampleNumber: '1712345678',
      regexPattern: r'^1\d{9}$',
    ),
    Country(
      name: 'Sri Lanka',
      code: 'LK',
      dialCode: '+94',
      flag: '🇱🇰',
      minLength: 9,
      maxLength: 9,
      sampleNumber: '712345678',
      regexPattern: r'^7\d{8}$',
    ),
    Country(
      name: 'Nepal',
      code: 'NP',
      dialCode: '+977',
      flag: '🇳🇵',
      minLength: 10,
      maxLength: 10,
      sampleNumber: '9841234567',
      regexPattern: r'^9\d{9}$',
    ),
    Country(
      name: 'China',
      code: 'CN',
      dialCode: '+86',
      flag: '🇨🇳',
      minLength: 11,
      maxLength: 11,
      sampleNumber: '13812345678',
      regexPattern: r'^1\d{10}$',
    ),
    Country(
      name: 'Japan',
      code: 'JP',
      dialCode: '+81',
      flag: '🇯🇵',
      minLength: 10,
      maxLength: 10,
      sampleNumber: '9012345678',
      regexPattern: r'^[789]0\d{8}$',
    ),
    Country(
      name: 'South Korea',
      code: 'KR',
      dialCode: '+82',
      flag: '🇰🇷',
      minLength: 9,
      maxLength: 10,
      sampleNumber: '1012345678',
      regexPattern: r'^10\d{7,8}$',
    ),
    Country(
      name: 'New Zealand',
      code: 'NZ',
      dialCode: '+64',
      flag: '🇳🇿',
      minLength: 8,
      maxLength: 10,
      sampleNumber: '211234567',
      regexPattern: r'^[2]\d{7,9}$',
    ),
    Country(
      name: 'South Africa',
      code: 'ZA',
      dialCode: '+27',
      flag: '🇿🇦',
      minLength: 9,
      maxLength: 9,
      sampleNumber: '821234567',
      regexPattern: r'^[6-8]\d{8}$',
    ),
    Country(
      name: 'Egypt',
      code: 'EG',
      dialCode: '+20',
      flag: '🇪🇬',
      minLength: 10,
      maxLength: 10,
      sampleNumber: '1012345678',
      regexPattern: r'^1[0125]\d{8}$',
    ),
    Country(
      name: 'Nigeria',
      code: 'NG',
      dialCode: '+234',
      flag: '🇳🇬',
      minLength: 10,
      maxLength: 10,
      sampleNumber: '8031234567',
      regexPattern: r'^[789]\d{9}$',
    ),
    Country(
      name: 'Kenya',
      code: 'KE',
      dialCode: '+254',
      flag: '🇰🇪',
      minLength: 9,
      maxLength: 9,
      sampleNumber: '712345678',
      regexPattern: r'^[17]\d{8}$',
    ),
    Country(
      name: 'Brazil',
      code: 'BR',
      dialCode: '+55',
      flag: '🇧🇷',
      minLength: 10,
      maxLength: 11,
      sampleNumber: '11987654321',
      regexPattern: r'^[1-9]{2}9?\d{8}$',
    ),
    Country(
      name: 'Mexico',
      code: 'MX',
      dialCode: '+52',
      flag: '🇲🇽',
      minLength: 10,
      maxLength: 10,
      sampleNumber: '5512345678',
      regexPattern: r'^[1-9]\d{9}$',
    ),
    Country(
      name: 'Argentina',
      code: 'AR',
      dialCode: '+54',
      flag: '🇦🇷',
      minLength: 10,
      maxLength: 10,
      sampleNumber: '1123456789',
      regexPattern: r'^[1-9]\d{9}$',
    ),
    Country(
      name: 'Italy',
      code: 'IT',
      dialCode: '+39',
      flag: '🇮🇹',
      minLength: 9,
      maxLength: 10,
      sampleNumber: '3123456789',
      regexPattern: r'^3\d{8,9}$',
    ),
    Country(
      name: 'Spain',
      code: 'ES',
      dialCode: '+34',
      flag: '🇪🇸',
      minLength: 9,
      maxLength: 9,
      sampleNumber: '612345678',
      regexPattern: r'^[67]\d{8}$',
    ),
    Country(
      name: 'Netherlands',
      code: 'NL',
      dialCode: '+31',
      flag: '🇳🇱',
      minLength: 9,
      maxLength: 9,
      sampleNumber: '612345678',
      regexPattern: r'^6\d{8}$',
    ),
    Country(
      name: 'Switzerland',
      code: 'CH',
      dialCode: '+41',
      flag: '🇨🇭',
      minLength: 9,
      maxLength: 9,
      sampleNumber: '781234567',
      regexPattern: r'^7\d{8}$',
    ),
    Country(
      name: 'Sweden',
      code: 'SE',
      dialCode: '+46',
      flag: '🇸🇪',
      minLength: 9,
      maxLength: 9,
      sampleNumber: '701234567',
      regexPattern: r'^7\d{8}$',
    ),
    Country(
      name: 'Norway',
      code: 'NO',
      dialCode: '+47',
      flag: '🇳🇴',
      minLength: 8,
      maxLength: 8,
      sampleNumber: '41234567',
      regexPattern: r'^[49]\d{7}$',
    ),
    Country(
      name: 'Ireland',
      code: 'IE',
      dialCode: '+353',
      flag: '🇮🇪',
      minLength: 9,
      maxLength: 9,
      sampleNumber: '851234567',
      regexPattern: r'^8\d{8}$',
    ),
    Country(
      name: 'Turkey',
      code: 'TR',
      dialCode: '+90',
      flag: '🇹🇷',
      minLength: 10,
      maxLength: 10,
      sampleNumber: '5012345678',
      regexPattern: r'^5\d{9}$',
    ),
    Country(
      name: 'Belgium',
      code: 'BE',
      dialCode: '+32',
      flag: '🇧🇪',
      minLength: 9,
      maxLength: 9,
      sampleNumber: '470123456',
      regexPattern: r'^4\d{8}$',
    ),
    Country(
      name: 'Austria',
      code: 'AT',
      dialCode: '+43',
      flag: '🇦🇹',
      minLength: 10,
      maxLength: 11,
      sampleNumber: '6641234567',
      regexPattern: r'^6\d{9,10}$',
    ),
    Country(
      name: 'Portugal',
      code: 'PT',
      dialCode: '+351',
      flag: '🇵🇹',
      minLength: 9,
      maxLength: 9,
      sampleNumber: '912345678',
      regexPattern: r'^9\d{8}$',
    ),
    Country(
      name: 'Greece',
      code: 'GR',
      dialCode: '+30',
      flag: '🇬🇷',
      minLength: 10,
      maxLength: 10,
      sampleNumber: '6912345678',
      regexPattern: r'^69\d{8}$',
    ),
    Country(
      name: 'Poland',
      code: 'PL',
      dialCode: '+48',
      flag: '🇵🇱',
      minLength: 9,
      maxLength: 9,
      sampleNumber: '501234567',
      regexPattern: r'^[4-8]\d{8}$',
    ),
    Country(
      name: 'Denmark',
      code: 'DK',
      dialCode: '+45',
      flag: '🇩🇰',
      minLength: 8,
      maxLength: 8,
      sampleNumber: '20123456',
      regexPattern: r'^[2-9]\d{7}$',
    ),
    Country(
      name: 'Finland',
      code: 'FI',
      dialCode: '+358',
      flag: '🇫🇮',
      minLength: 9,
      maxLength: 10,
      sampleNumber: '401234567',
      regexPattern: r'^[45]\d{8,9}$',
    ),
    Country(
      name: 'Russia',
      code: 'RU',
      dialCode: '+7',
      flag: '🇷🇺',
      minLength: 10,
      maxLength: 10,
      sampleNumber: '9123456789',
      regexPattern: r'^9\d{9}$',
    ),
    Country(
      name: 'Jordan',
      code: 'JO',
      dialCode: '+962',
      flag: '🇯🇴',
      minLength: 9,
      maxLength: 9,
      sampleNumber: '791234567',
      regexPattern: r'^7\d{8}$',
    ),
    Country(
      name: 'Lebanon',
      code: 'LB',
      dialCode: '+961',
      flag: '🇱🇧',
      minLength: 7,
      maxLength: 8,
      sampleNumber: '70123456',
      regexPattern: r'^[37]\d{6,7}$',
    ),
  ];

  /// Safely normalizes dialCode + localNumber into standard E.164 international format (+XXXXXXXXXXX).
  /// Guarantees that neither "++", duplicate dial codes (e.g. "+91+91"), nor trailing codes occur.
  static String formatFullPhoneNumber(String localNumber, String dialCode) {
    final cleanDialDigits = dialCode.replaceAll(RegExp(r'\D'), '');
    var cleanNumber = localNumber.replaceAll(RegExp(r'\D'), '');

    // Strip leading zero if typed as national trunk prefix
    if (cleanNumber.startsWith('0') && cleanNumber.length > 7) {
      cleanNumber = cleanNumber.substring(1);
    }

    // Strip duplicated dial code if the user pasted full number including dialing prefix
    if (cleanNumber.startsWith(cleanDialDigits) &&
        cleanNumber.length > cleanDialDigits.length + 6) {
      cleanNumber = cleanNumber.substring(cleanDialDigits.length);
    }

    return '+$cleanDialDigits$cleanNumber';
  }

  /// Finds a country by exact code, dial code, or name match, or falls back to India.
  static Country findByCodeOrDialCode(String query) {
    final q = query.trim().toLowerCase();
    for (final c in all) {
      if (c.code.toLowerCase() == q ||
          c.dialCode.toLowerCase() == q ||
          c.dialCode.replaceAll('+', '') == q ||
          c.name.toLowerCase() == q) {
        return c;
      }
    }
    return defaultCountry;
  }
}
