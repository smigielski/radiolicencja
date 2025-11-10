import 'package:shared_preferences/shared_preferences.dart';

class LearningProgressService {
  LearningProgressService._(this._prefs);

  final SharedPreferences _prefs;

  static const _keyPrefix = 'learning_progress_';
  static const _statsKeyPrefix = 'learning_stats_';

  static Future<LearningProgressService> load() async {
    final prefs = await SharedPreferences.getInstance();
    return LearningProgressService._(prefs);
  }

  Set<int> getMastered(String topicSlug) {
    final entries = _prefs.getStringList(_key(topicSlug)) ?? const [];
    return entries.map(int.parse).toSet();
  }

  Future<void> markMastered(String topicSlug, int questionId) async {
    final mastered = getMastered(topicSlug)..add(questionId);
    await _prefs.setStringList(
      _key(topicSlug),
      mastered.map((id) => id.toString()).toList(),
    );
  }

  Future<void> reset(String topicSlug) async {
    await _prefs.remove(_key(topicSlug));
    await _prefs.remove(_statsKey(topicSlug));
  }

  String _key(String slug) => '$_keyPrefix$slug';

  Map<int, QuestionStats> getQuestionStats(String topicSlug) {
    final raw = _prefs.getStringList(_statsKey(topicSlug));
    if (raw == null) return <int, QuestionStats>{};
    final stats = <int, QuestionStats>{};
    for (final entry in raw) {
      final parts = entry.split(':');
      if (parts.length < 3) continue;
      final questionId = int.tryParse(parts[0]);
      if (questionId == null) continue;
      final correct = int.tryParse(parts[1]) ?? 0;
      final incorrect = int.tryParse(parts[2]) ?? 0;
      DateTime? lastSeen;
      if (parts.length >= 4) {
        final timestamp = int.tryParse(parts[3]) ?? -1;
        if (timestamp > 0) {
          lastSeen = DateTime.fromMillisecondsSinceEpoch(timestamp);
        }
      }
      stats[questionId] = QuestionStats(
        correct: correct,
        incorrect: incorrect,
        lastSeen: lastSeen,
      );
    }
    return stats;
  }

  bool hasStats(String topicSlug) {
    return _prefs.containsKey(_statsKey(topicSlug));
  }

  Future<void> recordAnswerResult(
    String topicSlug,
    int questionId, {
    required bool isCorrect,
  }) async {
    final stats = getQuestionStats(topicSlug);
    final current = stats[questionId] ?? const QuestionStats();
    final now = DateTime.now();
    stats[questionId] = isCorrect
        ? current.incrementCorrect(now)
        : current.incrementIncorrect(now);
    final serialized = stats.entries
        .map(
          (entry) =>
              '${entry.key}:${entry.value.correct}:${entry.value.incorrect}:${entry.value.lastSeen?.millisecondsSinceEpoch ?? -1}',
        )
        .toList();
    await _prefs.setStringList(_statsKey(topicSlug), serialized);
  }

  String _statsKey(String slug) => '$_statsKeyPrefix$slug';
}

class QuestionStats {
  const QuestionStats({
    this.correct = 0,
    this.incorrect = 0,
    this.lastSeen,
  });

  final int correct;
  final int incorrect;
  final DateTime? lastSeen;

  QuestionStats incrementCorrect(DateTime seenAt) {
    return QuestionStats(
      correct: correct + 1,
      incorrect: incorrect,
      lastSeen: seenAt,
    );
  }

  QuestionStats incrementIncorrect(DateTime seenAt) {
    return QuestionStats(
      correct: correct,
      incorrect: incorrect + 1,
      lastSeen: seenAt,
    );
  }
}
