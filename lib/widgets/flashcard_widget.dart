import 'package:flutter/material.dart';
import '../models/study_models.dart';

class FlashcardWidget extends StatefulWidget {
  final List<StudyCard> cards;
  const FlashcardWidget({super.key, required this.cards});

  @override
  State<FlashcardWidget> createState() => _FlashcardWidgetState();
}

class _FlashcardWidgetState extends State<FlashcardWidget> {
  int _currentIndex = 0;
  bool _isFront = true;

  void _next() {
    if (_currentIndex < widget.cards.length - 1) {
      setState(() {
        _currentIndex++;
        _isFront = true;
      });
    }
  }

  void _previous() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _isFront = true;
      });
    }
  }

  void _flip() {
    setState(() => _isFront = !_isFront);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cards.isEmpty) {
      return const Center(
        child: Text(
          'No flashcards available',
          style: TextStyle(color: Colors.white38),
        ),
      );
    }

    final card = widget.cards[_currentIndex];
    final text = _isFront ? card.front : card.back;
    final hint = _isFront ? 'Tap to reveal answer' : 'Tap to see question';

    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _flip,
            child: Center(
              child: Container(
                width: double.infinity,
                height: 280,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _isFront
                        ? [const Color(0xFF1E1B4B), const Color(0xFF312E81)]
                        : [const Color(0xFF064E3B), const Color(0xFF065F46)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isFront
                        ? const Color(0xFF6C63FF).withValues(alpha: 0.4)
                        : const Color(0xFF4ECDC4).withValues(alpha: 0.4),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (_isFront ? const Color(0xFF6C63FF) : const Color(0xFF4ECDC4))
                          .withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isFront ? Icons.help_outline_rounded : Icons.lightbulb_rounded,
                        color: (_isFront ? const Color(0xFFA29BFE) : const Color(0xFF4ECDC4))
                            .withValues(alpha: 0.6),
                        size: 32,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        text,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          height: 1.5,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        hint,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _NavButton(
                icon: Icons.arrow_back_rounded,
                label: 'Previous',
                onTap: _currentIndex > 0 ? _previous : null,
              ),
              _NavButton(
                icon: Icons.refresh_rounded,
                label: 'Flip',
                onTap: _flip,
              ),
              _NavButton(
                icon: Icons.arrow_forward_rounded,
                label: 'Next',
                onTap: _currentIndex < widget.cards.length - 1 ? _next : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _NavButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: enabled ? const Color(0xFF1A1D2E) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: enabled ? Colors.white.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.04),
              ),
            ),
            child: Icon(
              icon,
              color: enabled ? Colors.white.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.12),
              size: 22,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: enabled ? Colors.white.withValues(alpha: 0.38) : Colors.white.withValues(alpha: 0.12),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}