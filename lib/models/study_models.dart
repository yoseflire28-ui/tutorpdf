// lib/models/study_models.dart
//
// TutorPDF — Study Content Models
// ─────────────────────────────────────────────────────────────────────────────
// Defines the data structures for flashcards and quiz questions used by
// the StudyScreen, FlashcardWidget, and QuizWidget.

/// A single flashcard with a [front] (question/term) and [back] (answer).
class StudyCard {
  final String front;
  final String back;

  const StudyCard({required this.front, required this.back});

  factory StudyCard.fromMap(Map<String, dynamic> map) {
    return StudyCard(
      front: map['front']?.toString() ?? '',
      back: map['back']?.toString() ?? '',
    );
  }
}

/// A single option inside a [QuizQuestion].
class QuizOption {
  final String text;
  final bool isCorrect;

  const QuizOption({required this.text, required this.isCorrect});
}

/// A multiple-choice quiz question with a list of [QuizOption]s.
class QuizQuestion {
  final String question;
  final List<QuizOption> options;

  const QuizQuestion({required this.question, required this.options});

  factory QuizQuestion.fromMap(Map<String, dynamic> map) {
    final rawOptions = (map['options'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final correctIndex = map['correctIndex'] as int? ?? 0;

    final options = rawOptions.asMap().entries.map((entry) {
      return QuizOption(
        text: entry.value,
        isCorrect: entry.key == correctIndex,
      );
    }).toList();

    return QuizQuestion(
      question: map['question']?.toString() ?? '',
      options: options,
    );
  }
}
