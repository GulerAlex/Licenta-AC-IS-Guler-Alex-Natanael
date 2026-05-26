import 'package:unihub/models/academic_progress.dart';

class AcademicProgressCalculator {
  const AcademicProgressCalculator._();

  static const double defaultPassingGrade = 5;

  static SubjectStatus calculateSubjectStatus(AcademicSubject subject) {
    return evaluateSubject(subject).status;
  }

  static double? calculateFinalGrade(AcademicSubject subject) {
    return evaluateSubject(subject).finalGrade;
  }

  static int calculateEarnedCredits(AcademicSubject subject) {
    return evaluateSubject(subject).earnedCredits;
  }

  static SubjectEvaluation evaluateSubject(AcademicSubject subject) {
    final List<GradeComponent> components = subject.components;
    final List<GradeComponent> gradedComponents = components
        .where((GradeComponent component) => component.grade != null)
        .toList(growable: false);

    if (components.isEmpty || gradedComponents.isEmpty) {
      return SubjectEvaluation(
        subject: subject,
        status: SubjectStatus.notStarted,
        earnedCredits: 0,
        missingRequiredComponents: const <GradeComponent>[],
        failingComponents: const <GradeComponent>[],
        hasConfigurationWarning: components.isEmpty,
        configurationMessage: components.isEmpty
            ? 'Materia nu are componente de evaluare configurate.'
            : null,
      );
    }

    final List<GradeComponent> missingRequired = components
        .where(
          (GradeComponent component) =>
              component.isRequired && component.grade == null,
        )
        .toList(growable: false);
    final List<GradeComponent> failing = components
        .where(
          (GradeComponent component) =>
              (component.isRequired || component.isEliminatory) &&
              component.grade != null &&
              component.grade! < component.minGrade,
        )
        .toList(growable: false);

    final _WeightedGrade weightedGrade = _calculateWeightedGrade(components);

    if (failing.isNotEmpty) {
      return SubjectEvaluation(
        subject: subject,
        status: SubjectStatus.failed,
        earnedCredits: 0,
        finalGrade: weightedGrade.value,
        estimatedFinalGrade: weightedGrade.value,
        missingRequiredComponents: missingRequired,
        failingComponents: failing,
        hasConfigurationWarning: weightedGrade.hasConfigurationWarning,
        configurationMessage: weightedGrade.configurationMessage,
      );
    }

    if (missingRequired.isNotEmpty) {
      return SubjectEvaluation(
        subject: subject,
        status: SubjectStatus.incomplete,
        earnedCredits: 0,
        estimatedFinalGrade: weightedGrade.value,
        missingRequiredComponents: missingRequired,
        failingComponents: failing,
        hasConfigurationWarning: weightedGrade.hasConfigurationWarning,
        configurationMessage: weightedGrade.configurationMessage,
      );
    }

    final double? finalGrade = weightedGrade.value;
    if (finalGrade == null) {
      return SubjectEvaluation(
        subject: subject,
        status: SubjectStatus.incomplete,
        earnedCredits: 0,
        missingRequiredComponents: missingRequired,
        failingComponents: failing,
        hasConfigurationWarning: true,
        configurationMessage:
            weightedGrade.configurationMessage ??
            'Nota finala nu poate fi calculata.',
      );
    }

    final bool promoted = finalGrade >= defaultPassingGrade;
    return SubjectEvaluation(
      subject: subject,
      status: promoted ? SubjectStatus.promoted : SubjectStatus.failed,
      earnedCredits: promoted ? subject.credits : 0,
      finalGrade: finalGrade,
      estimatedFinalGrade: finalGrade,
      missingRequiredComponents: missingRequired,
      failingComponents: failing,
      hasConfigurationWarning: weightedGrade.hasConfigurationWarning,
      configurationMessage: weightedGrade.configurationMessage,
    );
  }

  static AcademicProgress calculateAcademicProgress(
    List<AcademicSubject> subjects,
  ) {
    final List<SubjectEvaluation> evaluations = subjects
        .map(evaluateSubject)
        .toList(growable: false);

    final int totalPossibleCredits = subjects.fold<int>(
      0,
      (int total, AcademicSubject subject) => total + subject.credits,
    );
    final int totalEarnedCredits = evaluations.fold<int>(
      0,
      (int total, SubjectEvaluation evaluation) =>
          total + evaluation.earnedCredits,
    );
    final int failedCredits = evaluations
        .where(
          (SubjectEvaluation evaluation) =>
              evaluation.status == SubjectStatus.failed,
        )
        .fold<int>(
          0,
          (int total, SubjectEvaluation evaluation) =>
              total + evaluation.subject.credits,
        );
    final int incompleteCredits = evaluations
        .where(
          (SubjectEvaluation evaluation) =>
              evaluation.status == SubjectStatus.incomplete ||
              evaluation.status == SubjectStatus.notStarted,
        )
        .fold<int>(
          0,
          (int total, SubjectEvaluation evaluation) =>
              total + evaluation.subject.credits,
        );

    final double? officialAverage = _creditWeightedAverage(
      evaluations.where(
        (SubjectEvaluation evaluation) =>
            evaluation.status == SubjectStatus.promoted,
      ),
      useEstimated: false,
    );
    final double? estimatedAverage = _creditWeightedAverage(
      evaluations.where(
        (SubjectEvaluation evaluation) =>
            evaluation.estimatedFinalGrade != null ||
            evaluation.finalGrade != null,
      ),
      useEstimated: true,
    );

    final AcademicStanding standing = failedCredits > 0
        ? AcademicStanding.restantier
        : incompleteCredits > 0
        ? AcademicStanding.incomplet
        : AcademicStanding.integralist;

    return AcademicProgress(
      subjects: evaluations,
      totalEarnedCredits: totalEarnedCredits,
      totalPossibleCredits: totalPossibleCredits,
      failedCredits: failedCredits,
      incompleteCredits: incompleteCredits,
      remainingCredits: totalPossibleCredits - totalEarnedCredits,
      officialAverage: officialAverage,
      estimatedAverage: estimatedAverage,
      standing: standing,
    );
  }

  static _WeightedGrade _calculateWeightedGrade(
    List<GradeComponent> components,
  ) {
    final List<GradeComponent> gradedComponents = components
        .where((GradeComponent component) => component.grade != null)
        .toList(growable: false);

    if (gradedComponents.isEmpty) {
      return const _WeightedGrade(value: null);
    }

    final double configuredWeightSum = gradedComponents.fold<double>(
      0,
      (double total, GradeComponent component) => total + component.weight,
    );

    if (configuredWeightSum > 0) {
      final double weightedSum = gradedComponents.fold<double>(
        0,
        (double total, GradeComponent component) =>
            total + (component.grade! * component.weight),
      );
      final bool normalized = (configuredWeightSum - 1).abs() > 0.0001;
      return _WeightedGrade(
        value: weightedSum / configuredWeightSum,
        hasConfigurationWarning: normalized,
        configurationMessage: normalized
            ? 'Ponderile nu insumeaza 100%; nota este normalizata.'
            : null,
      );
    }

    final double arithmeticAverage =
        gradedComponents.fold<double>(
          0,
          (double total, GradeComponent component) => total + component.grade!,
        ) /
        gradedComponents.length;
    return const _WeightedGrade(
      value: null,
      hasConfigurationWarning: true,
      configurationMessage: 'Ponderile lipsesc pentru componentele notate.',
    ).copyWith(value: arithmeticAverage);
  }

  static double? _creditWeightedAverage(
    Iterable<SubjectEvaluation> evaluations, {
    required bool useEstimated,
  }) {
    double weightedSum = 0;
    int credits = 0;

    for (final SubjectEvaluation evaluation in evaluations) {
      final double? grade = useEstimated
          ? (evaluation.estimatedFinalGrade ?? evaluation.finalGrade)
          : evaluation.finalGrade;
      if (grade == null || evaluation.subject.credits <= 0) {
        continue;
      }
      weightedSum += grade * evaluation.subject.credits;
      credits += evaluation.subject.credits;
    }

    if (credits == 0) {
      return null;
    }
    return weightedSum / credits;
  }
}

class _WeightedGrade {
  const _WeightedGrade({
    required this.value,
    this.hasConfigurationWarning = false,
    this.configurationMessage,
  });

  final double? value;
  final bool hasConfigurationWarning;
  final String? configurationMessage;

  _WeightedGrade copyWith({double? value}) {
    return _WeightedGrade(
      value: value ?? this.value,
      hasConfigurationWarning: hasConfigurationWarning,
      configurationMessage: configurationMessage,
    );
  }
}
