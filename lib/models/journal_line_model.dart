class JournalLineModel {
  final int? id;
  final int? journalEntryId;
  final int accountId;
  final double debit;
  final double credit;
  final String? description;

  // Transient
  final String? accountCode;
  final String? accountName;
  final String? accountType;

  JournalLineModel({
    this.id,
    this.journalEntryId,
    required this.accountId,
    this.debit = 0.0,
    this.credit = 0.0,
    this.description,
    this.accountCode,
    this.accountName,
    this.accountType,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'journal_entry_id': journalEntryId,
      'account_id': accountId,
      'debit': debit,
      'credit': credit,
      'description': description,
    };
  }

  factory JournalLineModel.fromMap(
    Map<String, dynamic> map, {
    String? accountCode,
    String? accountName,
    String? accountType,
  }) {
    return JournalLineModel(
      id: map['id'] as int?,
      journalEntryId: map['journal_entry_id'] as int?,
      accountId: map['account_id'] as int,
      debit: (map['debit'] as num?)?.toDouble() ?? 0.0,
      credit: (map['credit'] as num?)?.toDouble() ?? 0.0,
      description: map['description'] as String?,
      accountCode: accountCode ?? map['account_code'] as String?,
      accountName: accountName ?? map['account_name'] as String?,
      accountType: accountType ?? map['account_type'] as String?,
    );
  }

  JournalLineModel copyWith({
    int? id,
    int? journalEntryId,
    int? accountId,
    double? debit,
    double? credit,
    String? description,
    String? accountCode,
    String? accountName,
    String? accountType,
  }) {
    return JournalLineModel(
      id: id ?? this.id,
      journalEntryId: journalEntryId ?? this.journalEntryId,
      accountId: accountId ?? this.accountId,
      debit: debit ?? this.debit,
      credit: credit ?? this.credit,
      description: description ?? this.description,
      accountCode: accountCode ?? this.accountCode,
      accountName: accountName ?? this.accountName,
      accountType: accountType ?? this.accountType,
    );
  }
}
