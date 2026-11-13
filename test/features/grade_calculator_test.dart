import 'package:flutter_test/flutter_test.dart';
import 'package:presensiku/features/grading/domain/grade_calculator.dart';

void main() {
  const calculator = GradeCalculator();

  test('normalizes 20, 50, and 100 point assessments equally', () {
    final result = calculator.calculate(
      assessments: const [
        AssessmentValue(id: 1, categoryId: 10, maxScore: 20),
        AssessmentValue(id: 2, categoryId: 10, maxScore: 50),
        AssessmentValue(id: 3, categoryId: 10, maxScore: 100),
      ],
      grades: const {
        1: GradeValue.graded(10),
        2: GradeValue.graded(50),
        3: GradeValue.graded(0),
      },
      weights: const {10: 100},
    );
    expect(result.categoryAverages[10], closeTo(50, 0.00001));
    expect(result.finalGrade, closeTo(50, 0.00001));
  });

  test('ungraded, zero, and EX remain distinct', () {
    final result = calculator.calculate(
      assessments: const [
        AssessmentValue(id: 1, categoryId: 1, maxScore: 100),
        AssessmentValue(id: 2, categoryId: 1, maxScore: 100),
        AssessmentValue(id: 3, categoryId: 1, maxScore: 100),
      ],
      grades: const {1: GradeValue.graded(0), 2: GradeValue.exempt()},
      weights: const {1: 100},
    );
    expect(result.categoryAverages[1], 0);
    expect(result.provisional, 0);
    expect(result.finalGrade, isNull);
    expect(result.incompleteReasons, contains(contains('wajib 3')));
  });

  test('all EX category is incomplete with an explicit reason', () {
    final result = calculator.calculate(
      assessments: const [AssessmentValue(id: 1, categoryId: 1, maxScore: 100)],
      grades: const {1: GradeValue.exempt()},
      weights: const {1: 100},
    );
    expect(result.finalGrade, isNull);
    expect(result.provisional, isNull);
    expect(result.incompleteReasons, contains(contains('EX')));
  });

  test('partial categories yield provisional, never official final', () {
    final result = calculator.calculate(
      assessments: const [
        AssessmentValue(id: 1, categoryId: 1, maxScore: 100),
        AssessmentValue(id: 2, categoryId: 2, maxScore: 100),
      ],
      grades: const {1: GradeValue.graded(80)},
      weights: const {1: 30, 2: 70},
    );
    expect(result.provisional, 80);
    expect(result.finalGrade, isNull);
  });

  test('zero-weight category is ignored and custom category contributes', () {
    final result = calculator.calculate(
      assessments: const [
        AssessmentValue(id: 1, categoryId: 10, maxScore: 100),
        AssessmentValue(id: 2, categoryId: 99, maxScore: 50),
        AssessmentValue(id: 3, categoryId: 2, maxScore: 100),
      ],
      grades: const {1: GradeValue.graded(100), 2: GradeValue.graded(25)},
      weights: const {10: 60, 99: 40, 2: 0},
    );
    expect(result.finalGrade, 80);
  });

  test('weight totals 99 and 101 are rejected; 100 accepted', () {
    expect(
      () => GradeCalculator.validateWeights({1: 99}),
      throwsFormatException,
    );
    expect(
      () => GradeCalculator.validateWeights({1: 101}),
      throwsFormatException,
    );
    expect(
      () => GradeCalculator.validateWeights({1: 100, 2: 0}),
      returnsNormally,
    );
  });

  test('corrections and weight changes recalculate without rounding', () {
    const assessments = [
      AssessmentValue(id: 1, categoryId: 1, maxScore: 20),
      AssessmentValue(id: 2, categoryId: 2, maxScore: 100),
    ];
    final first = calculator.calculate(
      assessments: assessments,
      grades: const {1: GradeValue.graded(17), 2: GradeValue.graded(90)},
      weights: const {1: 50, 2: 50},
    );
    final corrected = calculator.calculate(
      assessments: assessments,
      grades: const {1: GradeValue.graded(18), 2: GradeValue.graded(90)},
      weights: const {1: 20, 2: 80},
    );
    expect(first.finalGrade, 87.5);
    expect(corrected.finalGrade, 90);
  });

  test('invalid score and maximum are rejected', () {
    expect(
      () => calculator.calculate(
        assessments: const [AssessmentValue(id: 1, categoryId: 1, maxScore: 0)],
        grades: const {},
        weights: const {1: 100},
      ),
      throwsFormatException,
    );
    expect(
      () => calculator.calculate(
        assessments: const [
          AssessmentValue(id: 1, categoryId: 1, maxScore: 100),
        ],
        grades: const {1: GradeValue.graded(101)},
        weights: const {1: 100},
      ),
      throwsFormatException,
    );
  });
}
