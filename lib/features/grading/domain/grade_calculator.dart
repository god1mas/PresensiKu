enum GradeState { ungraded, graded, exempt }

class GradeValue {
  const GradeValue.ungraded() : state = GradeState.ungraded, score = null;
  const GradeValue.exempt() : state = GradeState.exempt, score = null;
  const GradeValue.graded(this.score) : state = GradeState.graded;

  final GradeState state;
  final double? score;
}

class AssessmentValue {
  const AssessmentValue({
    required this.id,
    required this.categoryId,
    required this.maxScore,
    this.isRequired = true,
    this.isAttitude = false,
  });

  final int id;
  final int categoryId;
  final double maxScore;
  final bool isRequired;
  final bool isAttitude;
}

class GradeResult {
  const GradeResult({
    required this.categoryAverages,
    required this.provisional,
    required this.finalGrade,
    required this.incompleteReasons,
  });

  final Map<int, double> categoryAverages;
  final double? provisional;
  final double? finalGrade;
  final List<String> incompleteReasons;

  bool get isComplete => finalGrade != null;
}

/// Pure calculation service. Inputs are one student's grades for one scope.
class GradeCalculator {
  const GradeCalculator();

  static void validateWeights(Map<int, int> weights) {
    if (weights.isEmpty ||
        weights.values.any((weight) => weight < 0 || weight > 100) ||
        weights.values.fold<int>(0, (sum, weight) => sum + weight) != 100) {
      throw const FormatException('Total bobot aktif harus tepat 100%.');
    }
  }

  GradeResult calculate({
    required List<AssessmentValue> assessments,
    required Map<int, GradeValue> grades,
    required Map<int, int> weights,
  }) {
    validateWeights(weights);
    final normalized = <int, List<double>>{};
    final reasons = <String>[];
    for (final assessment in assessments) {
      if (!assessment.maxScore.isFinite || assessment.maxScore <= 0) {
        throw const FormatException('Nilai maksimal harus lebih dari nol.');
      }
      final grade = grades[assessment.id] ?? const GradeValue.ungraded();
      if (grade.state == GradeState.graded) {
        final score = grade.score;
        if (score == null ||
            !score.isFinite ||
            score < 0 ||
            score > assessment.maxScore ||
            (assessment.isAttitude && score > 100)) {
          throw const FormatException('Nilai siswa di luar rentang.');
        }
        normalized
            .putIfAbsent(assessment.categoryId, () => [])
            .add(score / assessment.maxScore * 100);
      } else if (grade.state == GradeState.ungraded &&
          assessment.isRequired &&
          (weights[assessment.categoryId] ?? 0) > 0) {
        reasons.add('Penilaian wajib ${assessment.id} belum dinilai.');
      }
    }

    final averages = <int, double>{};
    for (final entry in normalized.entries) {
      averages[entry.key] =
          entry.value.reduce((a, b) => a + b) / entry.value.length;
    }

    var weightedSum = 0.0;
    var availableWeight = 0;
    for (final entry in weights.entries) {
      if (entry.value == 0) continue;
      final average = averages[entry.key];
      if (average == null) {
        final categoryAssessments = assessments.where(
          (assessment) => assessment.categoryId == entry.key,
        );
        final allEx =
            categoryAssessments.isNotEmpty &&
            categoryAssessments.every(
              (assessment) => grades[assessment.id]?.state == GradeState.exempt,
            );
        reasons.add(
          allEx
              ? 'Semua nilai kategori ${entry.key} dikecualikan (EX).'
              : 'Kategori ${entry.key} belum memiliki nilai.',
        );
        continue;
      }
      weightedSum += average * entry.value;
      availableWeight += entry.value;
    }
    final provisional = availableWeight == 0
        ? null
        : weightedSum / availableWeight;
    final finalGrade = reasons.isEmpty ? weightedSum / 100 : null;
    return GradeResult(
      categoryAverages: averages,
      provisional: provisional,
      finalGrade: finalGrade,
      incompleteReasons: List.unmodifiable(reasons),
    );
  }
}
