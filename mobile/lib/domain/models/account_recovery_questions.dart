class AccountRecoveryQuestions {
  const AccountRecoveryQuestions({
    required this.questionOne,
    required this.questionTwo,
    required this.locked,
    this.retryAfterMinutes,
  });

  final String questionOne;
  final String questionTwo;
  final bool locked;
  final int? retryAfterMinutes;

  factory AccountRecoveryQuestions.fromJson(Map<String, dynamic> json) {
    return AccountRecoveryQuestions(
      questionOne: json['questionOne'] as String,
      questionTwo: json['questionTwo'] as String,
      locked: json['locked'] as bool? ?? false,
      retryAfterMinutes: json['retryAfterMinutes'] as int?,
    );
  }
}
