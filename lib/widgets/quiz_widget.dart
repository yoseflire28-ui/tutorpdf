import 'package:flutter/material.dart';
import '../models/study_models.dart';

class QuizWidget extends StatefulWidget {
  final List<QuizQuestion> questions;
  const QuizWidget({super.key, required this.questions});

  @override
  State<QuizWidget> createState() => _QuizWidgetState();
}

class _QuizWidgetState extends State<QuizWidget> {
  int _currentIndex = 0;
  int? _selectedOptionIndex;
  bool _answered = false;
  int _score = 0;
  bool _quizComplete = false;

  void _selectOption(int index) {
    if (_answered) return;
    final isCorrect = widget.questions[_currentIndex].options[index].isCorrect;
    setState(() {
      _selectedOptionIndex = index;
      _answered = true;
      if (isCorrect) _score++;
    });
  }

  void _next() {
    if (_currentIndex < widget.questions.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedOptionIndex = null;
        _answered = false;
      });
    } else {
      setState(() => _quizComplete = true);
    }
  }

  void _restart() {
    setState(() {
      _currentIndex = 0;
      _selectedOptionIndex = null;
      _answered = false;
      _score = 0;
      _quizComplete = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_quizComplete) {
      return _ResultView(
        score: _score,
        total: widget.questions.length,
        onRestart: _restart,
      );
    }

    final question = widget.questions[_currentIndex];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Question ${_currentIndex + 1} of ${widget.questions.length}',
                style: const TextStyle(color: Colors.white38, fontSize: 13),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Score: $_score',
                  style: const TextStyle(
                    color: Color(0xFFA29BFE),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_currentIndex + 1) / widget.questions.length,
              backgroundColor: Colors.white.withValues(alpha: 0.06),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF6C63FF)),
              minHeight: 3,
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Question box
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1D2E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF6C63FF).withValues(alpha: 0.2)),
            ),
            child: Text(
              question.question,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Options
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: question.options.length,
            itemBuilder: (_, i) {
              final option = question.options[i];
              final isSelected = _selectedOptionIndex == i;
              final isCorrect = option.isCorrect;

              Color borderColor = Colors.white12;
              Color bgColor = const Color(0xFF1A1D2E);
              Color textColor = Colors.white70;

              if (_answered) {
                if (isCorrect) {
                  borderColor = const Color(0xFF4ECDC4);
                  bgColor = const Color(0xFF4ECDC4).withValues(alpha: 0.12);
                  textColor = Colors.white;
                } else if (isSelected && !isCorrect) {
                  borderColor = const Color(0xFFFF6B6B);
                  bgColor = const Color(0xFFFF6B6B).withValues(alpha: 0.12);
                  textColor = Colors.white;
                }
              } else if (isSelected) {
                borderColor = const Color(0xFF6C63FF);
                bgColor = const Color(0xFF6C63FF).withValues(alpha: 0.12);
                textColor = Colors.white;
              }

              return GestureDetector(
                onTap: () => _selectOption(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: borderColor.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                          border: Border.all(color: borderColor),
                        ),
                        child: Center(
                          child: _answered
                              ? Icon(
                                  isCorrect
                                      ? Icons.check_rounded
                                      : (isSelected ? Icons.close_rounded : null),
                                  color: isCorrect
                                      ? const Color(0xFF4ECDC4)
                                      : const Color(0xFFFF6B6B),
                                  size: 16,
                                )
                              : Text(
                                  String.fromCharCode(65 + i),
                                  style: TextStyle(
                                    color: textColor,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          option.text,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Next button
        if (_answered)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _next,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  _currentIndex < widget.questions.length - 1
                      ? 'Next Question'
                      : 'See Results',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ResultView extends StatelessWidget {
  final int score;
  final int total;
  final VoidCallback onRestart;

  const _ResultView({
    required this.score,
    required this.total,
    required this.onRestart,
  });

  @override
  Widget build(BuildContext context) {
    final percent = (score / total * 100).round();
    final color = percent >= 80
        ? const Color(0xFF4ECDC4)
        : percent >= 50
            ? const Color(0xFFFFE66D)
            : const Color(0xFFFF6B6B);

    final message = percent >= 80
        ? 'Excellent work!'
        : percent >= 50
            ? 'Good effort!'
            : 'Keep practicing!';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 140,
                  height: 140,
                  child: CircularProgressIndicator(
                    value: score / total,
                    strokeWidth: 10,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
                Column(
                  children: [
                    Text(
                      '$score/$total',
                      style: TextStyle(
                        color: color,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '$percent%',
                      style: const TextStyle(color: Colors.white38, fontSize: 14),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You answered $score out of $total questions correctly.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white38, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onRestart,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retake Quiz'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}