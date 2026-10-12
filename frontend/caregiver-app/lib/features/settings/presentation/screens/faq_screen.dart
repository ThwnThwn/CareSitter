import 'package:caregiver_app/features/settings/presentation/widgets/faq_results.dart';
import 'package:caregiver_app/features/settings/presentation/widgets/faq_search_field.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/core/router/navigation_helpers.dart';
import 'package:caregiver_app/features/settings/data/models/faq_item.dart';

class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key});

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  final _searchController = TextEditingController();
  List<FaqItem> _filteredItems = [];

  @override
  void initState() {
    super.initState();
    _filteredItems = List.from(caregiverFaqItems);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterSearch(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredItems = List.from(caregiverFaqItems);
      } else {
        _filteredItems = caregiverFaqItems
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
          FaqSearchField(
              searchController: _searchController,
              filterSearch: _filterSearch,
              callbackAction1: () {
                _searchController.clear();
                _filterSearch('');
              }),
          // FAQ List
          FaqResults(filteredItems: _filteredItems),
        ],
      ),
    );
  }
}
