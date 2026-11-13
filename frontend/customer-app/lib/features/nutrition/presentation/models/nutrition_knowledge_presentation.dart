import '../../data/models/nutrition_knowledge_model.dart';

class NutritionKnowledgePresentation {
  const NutritionKnowledgePresentation(this.search);

  final NutritionKnowledgeSearchModel search;

  bool get hasAnswer =>
      search.answerSources.isNotEmpty &&
      (search.answerProvider != 'Gemini' ||
          search.groundedAnswerBlocks.isNotEmpty);

  String get answerText {
    if (search.isAiSuggestion) {
      return search.answerBlocks.map((block) => block.text).join("\n\n");
    }
    final sources = search.answerSources;
    final blocks = search.groundedAnswerBlocks;
    if (!hasAnswer) return failureMessage;
    if (blocks.isNotEmpty) {
      final numbers = {
        for (final (index, hit) in sources.indexed) hit.chunkId: index + 1
      };
      return blocks
          .map((block) =>
              '${block.text} ${block.chunkIds.toSet().map((id) => '[${numbers[id]}]').join('')}')
          .join('\n\n');
    }
    return sources.indexed
        .map((entry) =>
            '${entry.$2.excerpt}${sources.length > 1 ? ' [${entry.$1 + 1}]' : ''}')
        .join('\n\n');
  }

  String get failureMessage => switch (search.answerStatus) {
        'invalid_output' =>
          'Gemini đã phản hồi nhưng câu trả lời chưa khớp đầy đủ với nguồn tài liệu. Hãy thử lại hoặc xem các đoạn liên quan bên dưới.',
        'timeout' => 'AI phản hồi quá lâu. Hãy thử tra cứu lại.',
        'rate_limited' =>
          'Gemini đang giới hạn lượt gọi. Vui lòng thử lại sau.',
        'not_configured' =>
          'Chức năng trả lời bằng AI chưa được cấu hình trên máy chủ.',
        'unavailable' => search.answerProvider == 'Gemini'
            ? 'Chưa kết nối được Gemini. Bạn có thể xem các đoạn liên quan bên dưới hoặc tra cứu lại.'
            : 'AI local chưa phản hồi. Bạn có thể xem các đoạn liên quan bên dưới hoặc tra cứu lại.',
        _ =>
          'Chưa tìm được đoạn tài liệu trả lời trực tiếp câu hỏi này. Hãy thử nêu chủ đề cụ thể hơn.',
      };
}
