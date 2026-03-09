import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/meditation_session.dart';
import '../models/question_models.dart';
import '../models/user_profile.dart';
import '../services/daily_progress_store.dart';
import '../services/meditation_session_store.dart';
import '../services/meditation_sync_service.dart';
import 'thank_you_page.dart';

class QuestionnairePage extends StatefulWidget {
  const QuestionnairePage({
    super.key,
    required this.deviceId,
    required this.profile,
    required this.musicStartTime,
    this.isPractice = false,
  });

  final String deviceId;
  final UserProfile profile;
  final DateTime musicStartTime;
  final bool isPractice;

  @override
  State<QuestionnairePage> createState() => _QuestionnairePageState();
}

class _QuestionnairePageState extends State<QuestionnairePage> {
  final _controller = PageController();

  final List<QuestionItem> _questions = const [
    QuestionItem(
      title:
          'During practice, I attempted to return to my present-moment experience, whether unpleasant, pleasant, or neutral.',
      info:
          'I kept bringing my attention back to what I was experiencing right now.',
    ),
    QuestionItem(
      title:
          'During practice, I attempted to return to each experience, no matter how unpleasant, with a sense that "It\'s OK to experience this".',
      info:
          '⁠I tried to allow whatever was happening, and remind myself it\'s okay.',
    ),
    QuestionItem(
      title:
          'During practice, I attempted to feel each experience as bare sensations in the body (tension in throat, movement in belly, etc).',
      info:
          '⁠I noticed the feelings in my body (like tightness, warmth, or movement) without overthinking them.',
    ),
    QuestionItem(
      title:
          'During practice, I was struggling against having certain experiences (e.g., unpleasant thoughts, emotions, and/or bodily sensations).',
      info: 'I was resisting or fighting against certain experiences.',
    ),
    QuestionItem(
      title:
          'During practice, I was actively avoiding or "pushing away" certain experiences.',
      info:
          'I tried to push away or avoid certain thoughts, feelings, or sensations.',
    ),
    QuestionItem(
      title:
          'During practice I was actively trying to fix or change certain experiences, in order to get to a "better place".',
      info:
          '⁠I was trying to change how I felt to feel better, instead of just noticing it.',
    ),
  ];

  final List<QuestionAnswer> _answers = List.generate(
    6,
    (_) => const QuestionAnswer(),
  );

  int _pageIndex = 0;
  bool _submitting = false;

  bool _canContinue(int page) {
    final start = page * 3;
    final end = start + 3;
    for (var i = start; i < end; i++) {
      if (!_answers[i].changed) {
        return false;
      }
    }
    return true;
  }

  bool _allAnswersComplete() {
    // Check that all answers have been marked as changed.
    return _answers.every((answer) => answer.changed);
  }

  void _updateAnswer(int index, double value) {
    print('DEBUG_SLIDER: index=$index, value=$value');
    setState(() {
      _answers[index] = QuestionAnswer(value: value, changed: true);
    });
  }

  void _showInfo(String info) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('More info'),
        content: Text(info),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _finish() async {
    if (!_canContinue(1)) {
      return;
    }

    if (_submitting) {
      return;
    }

    // Validate that all 6 answers have been adjusted.
    if (!_allAnswersComplete()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please answer all questions')),
        );
      }
      return;
    }

    final answers = _answers.map((answer) => (answer.value ?? 0)).toList();

    print('=== QUESTIONNAIRE SUBMISSION ===');
    print('Total questions: ${_answers.length}');
    print('All answers captured: ${answers.length == 6 && _allAnswersComplete()}');
    for (int i = 0; i < answers.length; i++) {
      print('q${i + 1}: ${answers[i]} (changed: ${_answers[i].changed})');
    }
    print('=======================\n');

    if (!mounted) return;

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Review Your Answers'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (int i = 0; i < 6; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('q${i + 1}:'),
                          Text('${answers[i].toInt()}'),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Edit'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Submit'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) {
      return;
    }

    setState(() {
      _submitting = true;
    });

    if (widget.isPractice) {
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      return;
    }

    final session = MeditationSession(
      id: const Uuid().v4(),
      deviceId: widget.deviceId,
      userName: widget.profile.name,
      startDate: widget.profile.startDate,
      musicStartTime: widget.musicStartTime.toIso8601String(),
      answers: answers,
      synced: false,
    );

    await MeditationSessionStore.add(session);
    await DailyProgressStore.setLastCompletedTimestamp(DateTime.now());

    if (!mounted) {
      return;
    }

    Navigator.of(context)
        .pushReplacement(MaterialPageRoute(builder: (_) => const ThankYouPage()));

    // Try to sync in background (fire and forget).
    unawaited(
      MeditationSyncService.syncPending(
        deviceId: widget.deviceId,
        profile: widget.profile,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  if (_pageIndex == 1)
                    IconButton(
                      onPressed: () {
                        _controller.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        );
                      },
                      icon: const Icon(Icons.arrow_back),
                    )
                  else
                    const SizedBox(width: 48),
                  const Expanded(
                    child: Text(
                      'Questionnaire',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) {
                  setState(() {
                    _pageIndex = index;
                  });
                },
                itemCount: 2,
                itemBuilder: (context, page) {
                  final start = page * 3;
                  final pageItems = _questions.sublist(start, start + 3);
                  return ListView.separated(
                    key: ValueKey('page_$page'),
                    padding: const EdgeInsets.all(16),
                    itemBuilder: (context, index) {
                      final questionIndex = start + index;
                      final question = pageItems[index];
                      final answer = _answers[questionIndex];
                      final value = answer.value ?? 0;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  question.title,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () => _showInfo(question.info),
                                icon: const Icon(Icons.info_outline),
                              ),
                            ],
                          ),
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 2,
                              tickMarkShape: const RoundSliderTickMarkShape(),
                              activeTickMarkColor: Colors.black,
                              inactiveTickMarkColor: Colors.black26,
                              overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 18,
                              ),
                            ),
                            child: Slider(
                              key: ValueKey('slider_$questionIndex'),
                              value: value,
                              min: 0,
                              max: 100,
                              divisions: 10,
                              label: value.round().toString(),
                              onChanged: (newValue) =>
                                  _updateAnswer(questionIndex, newValue),
                            ),
                          ),
                          Text(
                            'Value: ${value.round()}${answer.changed ? '' : ' (adjust to continue)'}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(height: 24),
                    itemCount: pageItems.length,
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (_pageIndex == 0)
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _canContinue(0)
                            ? () {
                                _controller.nextPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOut,
                                );
                              }
                            : null,
                        child: const Text('Next'),
                      ),
                    )
                  else
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _canContinue(1) && !_submitting
                            ? _finish
                            : null,
                        child: Text(_submitting ? 'Submitting...' : 'Submit'),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
