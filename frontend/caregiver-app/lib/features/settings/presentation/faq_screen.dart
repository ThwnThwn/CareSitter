import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/navigation_helpers.dart';
import '../../../core/mock/mock_data.dart';

class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key});

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  final _searchController = TextEditingController();
  List<MockFaqItem> _filteredItems = [];

  @override
  void initState() {
    super.initState();
    _filteredItems = List.from(MockData.faqItems);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterSearch(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredItems = List.from(MockData.faqItems);
      } else {
        _filteredItems = MockData.faqItems
            .where((item) =>
                item.question.toLowerCase().contains(query.toLowerCase()) ||
                item.answer.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Câu hỏi thường gặp'),
        leading: const AppBackButton(fallbackRoute: '/settings'),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(24),
            child: TextField(
              controller: _searchController,
              onChanged: _filterSearch,
              decoration: InputDecoration(
                hintText: 'Tìm kiếm câu hỏi...',
                prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _filterSearch('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
          ),
          // FAQ List
          Expanded(
            child: _filteredItems.isEmpty
                ? const Center(
                    child: Text(
                      'Không tìm thấy câu hỏi phù hợp',
                      style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: _filteredItems.length,
                    itemBuilder: (context, index) {
                      final item = _filteredItems[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: ExpansionTile(
                            title: Text(
                              item.question,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            iconColor: AppColors.primary,
                            collapsedIconColor: AppColors.textSecondary,
                            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            children: [
                              const Divider(height: 1),
                              const SizedBox(height: 12),
                              Text(
                                item.answer,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  color: AppColors.textSecondary,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
