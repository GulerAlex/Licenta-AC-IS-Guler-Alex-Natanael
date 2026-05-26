import 'package:flutter_test/flutter_test.dart';
import 'package:unihub/models/academic_progress.dart';
import 'package:unihub/services/academic_progress_calculator.dart';

void main() {
  group('AcademicProgressCalculator', () {
    test('fails subject when seminar is below 5 and awards 0 credits', () {
      final AcademicSubject subject = _subject(
        components: <GradeComponent>[
          _component('Examen', GradeComponentType.exam, 8, 0.5),
          _component('Laborator', GradeComponentType.laboratory, 7, 0.25),
          _component('Seminar', GradeComponentType.seminar, 4, 0.25),
        ],
      );

      final SubjectEvaluation evaluation =
          AcademicProgressCalculator.evaluateSubject(subject);

      expect(evaluation.status, SubjectStatus.failed);
      expect(evaluation.earnedCredits, 0);
      expect(
        evaluation.failingComponents.map((GradeComponent c) => c.name),
        contains('Seminar'),
      );
    });

    test('promotes subject when required components pass', () {
      final AcademicSubject subject = _subject(
        components: <GradeComponent>[
          _component('Examen', GradeComponentType.exam, 8, 0.5),
          _component('Laborator', GradeComponentType.laboratory, 7, 0.25),
          _component('Seminar', GradeComponentType.seminar, 5, 0.25),
        ],
      );

      final SubjectEvaluation evaluation =
          AcademicProgressCalculator.evaluateSubject(subject);

      expect(evaluation.finalGrade, closeTo(7, 0.001));
      expect(evaluation.status, SubjectStatus.promoted);
      expect(evaluation.earnedCredits, 5);
    });

    test('marks subject incomplete when coursework grade is missing', () {
      final AcademicSubject subject = _subject(
        components: <GradeComponent>[
          _component('Examen', GradeComponentType.exam, 9, 0.6),
          _component(
            'Activitate pe parcurs',
            GradeComponentType.coursework,
            null,
            0.4,
          ),
        ],
      );

      final SubjectEvaluation evaluation =
          AcademicProgressCalculator.evaluateSubject(subject);

      expect(evaluation.status, SubjectStatus.incomplete);
      expect(evaluation.earnedCredits, 0);
      expect(
        evaluation.missingRequiredComponents.map((GradeComponent c) => c.name),
        contains('Activitate pe parcurs'),
      );
    });

    test('failed component takes precedence over a missing component', () {
      final AcademicSubject subject = _subject(
        components: <GradeComponent>[
          _component('Examen', GradeComponentType.exam, 4, 0.6),
          _component('Laborator', GradeComponentType.laboratory, null, 0.4),
        ],
      );

      final SubjectEvaluation evaluation =
          AcademicProgressCalculator.evaluateSubject(subject);

      expect(evaluation.status, SubjectStatus.failed);
      expect(evaluation.earnedCredits, 0);
      expect(
        evaluation.failingComponents.map((GradeComponent c) => c.name),
        contains('Examen'),
      );
    });

    test('awards full credits when all components are above 5', () {
      final AcademicSubject subject = _subject(
        components: <GradeComponent>[
          _component('Examen', GradeComponentType.exam, 9, 0.5),
          _component('Laborator', GradeComponentType.laboratory, 8, 0.5),
        ],
      );

      final SubjectEvaluation evaluation =
          AcademicProgressCalculator.evaluateSubject(subject);

      expect(evaluation.status, SubjectStatus.promoted);
      expect(evaluation.earnedCredits, subject.credits);
    });

    test('official average includes only promoted subjects', () {
      final AcademicProgress progress =
          AcademicProgressCalculator.calculateAcademicProgress(
            <AcademicSubject>[
              _subject(
                id: 'promoted-a',
                credits: 5,
                components: <GradeComponent>[
                  _component('Examen', GradeComponentType.exam, 10, 1),
                ],
              ),
              _subject(
                id: 'promoted-b',
                credits: 5,
                components: <GradeComponent>[
                  _component('Examen', GradeComponentType.exam, 8, 1),
                ],
              ),
              _subject(
                id: 'failed',
                credits: 5,
                components: <GradeComponent>[
                  _component('Examen', GradeComponentType.exam, 4, 1),
                ],
              ),
            ],
          );

      expect(progress.officialAverage, closeTo(9, 0.001));
      expect(progress.totalEarnedCredits, 10);
      expect(progress.failedCredits, 5);
    });

    test('standing is integralist when all subjects are promoted', () {
      final AcademicProgress progress =
          AcademicProgressCalculator.calculateAcademicProgress(
            <AcademicSubject>[
              _subject(
                components: <GradeComponent>[
                  _component('Examen', GradeComponentType.exam, 8, 1),
                ],
              ),
            ],
          );

      expect(progress.standing, AcademicStanding.integralist);
    });

    test('standing is restantier when at least one subject failed', () {
      final AcademicProgress progress =
          AcademicProgressCalculator.calculateAcademicProgress(
            <AcademicSubject>[
              _subject(
                id: 'failed',
                components: <GradeComponent>[
                  _component('Examen', GradeComponentType.exam, 4, 1),
                ],
              ),
              _subject(
                id: 'incomplete',
                components: <GradeComponent>[
                  _component('Examen', GradeComponentType.exam, null, 1),
                ],
              ),
            ],
          );

      expect(progress.standing, AcademicStanding.restantier);
    });

    test(
      'standing is incomplet when there are incomplete subjects but no fails',
      () {
        final AcademicProgress progress =
            AcademicProgressCalculator.calculateAcademicProgress(
              <AcademicSubject>[
                _subject(
                  components: <GradeComponent>[
                    _component('Examen', GradeComponentType.exam, null, 1),
                  ],
                ),
              ],
            );

        expect(progress.standing, AcademicStanding.incomplet);
      },
    );
  });
}

AcademicSubject _subject({
  String id = 'subject',
  int credits = 5,
  List<GradeComponent> components = const <GradeComponent>[],
}) {
  return AcademicSubject(
    id: id,
    name: id,
    semester: 'Semestrul 1',
    year: 1,
    credits: credits,
    components: components,
  );
}

GradeComponent _component(
  String name,
  GradeComponentType type,
  double? grade,
  double weight,
) {
  return GradeComponent(
    id: name,
    name: name,
    type: type,
    grade: grade,
    weight: weight,
    isRequired: true,
    isEliminatory:
        type == GradeComponentType.seminar ||
        type == GradeComponentType.laboratory ||
        type == GradeComponentType.project,
  );
}
