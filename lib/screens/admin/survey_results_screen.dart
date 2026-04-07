import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/app_theme.dart';

/// アンケート結果画面
class SurveyResultsScreen extends StatelessWidget {
  final String surveyId;
  final String surveyTitle;

  const SurveyResultsScreen({
    super.key,
    required this.surveyId,
    required this.surveyTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('アンケート結果',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('surveys')
            .doc(surveyId)
            .snapshots(),
        builder: (context, surveySnap) {
          if (!surveySnap.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryColor));
          }

          final surveyData =
              surveySnap.data?.data() as Map<String, dynamic>? ?? {};
          final title = surveyData['title'] as String? ?? '';
          final description = surveyData['description'] as String? ?? '';
          final questions = (surveyData['questions'] as List<dynamic>?) ?? [];
          final responseCount = surveyData['responseCount'] as int? ?? 0;

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('surveys')
                .doc(surveyId)
                .collection('responses')
                .snapshots(),
            builder: (context, responsesSnap) {
              final responses = responsesSnap.data?.docs ?? [];

              // Aggregate results per question
              final aggregated = _aggregateResults(questions, responses);

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Survey header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary)),
                          if (description.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(description,
                                style: TextStyle(
                                    fontSize: 14,
                                    color: AppTheme.textSecondary)),
                          ],
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text('回答数: $responseCount',
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primaryColor)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Results per question
                    for (int qi = 0; qi < questions.length; qi++) ...[
                      _buildQuestionResult(
                        qi,
                        questions[qi] as Map<String, dynamic>,
                        aggregated[qi],
                        responses.length,
                      ),
                      const SizedBox(height: 16),
                    ],

                    const SizedBox(height: 40),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  List<Map<String, int>> _aggregateResults(
      List<dynamic> questions, List<QueryDocumentSnapshot> responses) {
    final result = <Map<String, int>>[];

    for (int qi = 0; qi < questions.length; qi++) {
      final q = questions[qi] as Map<String, dynamic>;
      final choices = (q['choices'] as List<dynamic>?)
              ?.map((c) => c.toString())
              .toList() ??
          [];
      final counts = <String, int>{};
      for (final c in choices) {
        counts[c] = 0;
      }

      for (final resp in responses) {
        final data = resp.data() as Map<String, dynamic>;
        final answers = (data['answers'] as Map<String, dynamic>?) ?? {};
        final answer = answers['$qi'] as String?;
        if (answer != null && counts.containsKey(answer)) {
          counts[answer] = counts[answer]! + 1;
        }
      }

      result.add(counts);
    }

    return result;
  }

  Widget _buildQuestionResult(
    int index,
    Map<String, dynamic> question,
    Map<String, int> counts,
    int totalResponses,
  ) {
    final text = question['text'] as String? ?? '';
    final choices = (question['choices'] as List<dynamic>?)
            ?.map((c) => c.toString())
            .toList() ??
        [];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text('${index + 1}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(text,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          for (final choice in choices) ...[
            _buildBarRow(choice, counts[choice] ?? 0, totalResponses),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _buildBarRow(String label, int count, int total) {
    final percentage = total > 0 ? (count / total * 100) : 0.0;
    final fraction = total > 0 ? count / total : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 14, color: AppTheme.textPrimary)),
            ),
            Text('${percentage.toStringAsFixed(1)}%  ($count)',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 8,
            backgroundColor: Colors.grey[200],
            valueColor:
                const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
          ),
        ),
      ],
    );
  }
}
