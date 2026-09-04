import 'package:equatable/equatable.dart';

enum Verdict { NORMAL, ALERT, STALE, NONE }

class SignalReading extends Equatable {
  final String label;
  final double? value;
  final Duration age;
  final Verdict verdict;
  final String unit;

  const SignalReading({
    required this.label,
    this.value,
    required this.age,
    required this.verdict,
    this.unit = '',
  });

  @override
  List<Object?> get props => [label, value, age, verdict, unit];
}
