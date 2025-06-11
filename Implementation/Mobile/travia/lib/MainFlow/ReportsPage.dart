import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travia/Helpers/PopUp.dart';
import 'package:travia/main.dart';

import '../Helpers/AppColors.dart';
import '../database/DatabaseMethods.dart';

// State classes
class ReportState {
  final String? selectedReason;
  final String description;
  final bool isSubmitting;

  const ReportState({
    this.selectedReason,
    this.description = '',
    this.isSubmitting = false,
  });

  ReportState copyWith({
    String? selectedReason,
    String? description,
    bool? isSubmitting,
  }) {
    return ReportState(
      selectedReason: selectedReason ?? this.selectedReason,
      description: description ?? this.description,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}

// Providers
final reportStateProvider = StateNotifierProvider<ReportStateNotifier, ReportState>((ref) {
  return ReportStateNotifier();
});

final reportDescriptionControllerProvider = Provider<TextEditingController>((ref) {
  final controller = TextEditingController();
  ref.onDispose(() => controller.dispose());
  return controller;
});

final reportReasonsProvider = Provider<Map<String, String>>((ref) {
  return {
    'spam': 'Spam',
    'harassment': 'Harassment or Bullying',
    'hate_speech': 'Hate Speech',
    'violence': 'Violence or Threats',
    'nudity': 'Nudity or Sexual Content',
    'copyright': 'Copyright Violation',
    'misinformation': 'False Information',
    'inappropriate_content': 'Inappropriate Content',
    'other': 'Other',
  };
});

final reportReasonIconsProvider = Provider<Map<String, IconData>>((ref) {
  return {
    'spam': Icons.block,
    'harassment': Icons.person_off,
    'hate_speech': Icons.report_problem,
    'violence': Icons.warning,
    'nudity': Icons.visibility_off,
    'copyright': Icons.copyright,
    'misinformation': Icons.fact_check,
    'inappropriate_content': Icons.flag,
    'other': Icons.more_horiz,
  };
});

// State Notifier
class ReportStateNotifier extends StateNotifier<ReportState> {
  ReportStateNotifier() : super(const ReportState());

  void selectReason(String reason) {
    state = state.copyWith(selectedReason: reason);
  }

  void updateDescription(String description) {
    state = state.copyWith(description: description);
  }

  void setSubmitting(bool isSubmitting) {
    state = state.copyWith(isSubmitting: isSubmitting);
  }

  Future<void> _sendAccountReportNotification(String reporterId, String targetUserId) async {
    try {
      // Get the reporter's username
      final reporterResponse = await supabase.from('users').select('username').eq('id', reporterId).single();

      final reporterUsername = reporterResponse['username'] ?? 'Someone';

      await sendNotification(
        type: "report",
        title: "Account Reported",
        content: "Your account was reported by $reporterUsername",
        target_user_id: targetUserId,
        source_id: targetUserId,
        sender_user_id: reporterId,
      );
    } catch (error) {
      // If notification fails, don't affect the report submission
      print('Failed to send account report notification: $error');
    }
  }

  Future<bool> _checkExistingReport({
    required String reportType,
    String? targetUserId,
    String? targetPostId,
    String? targetCommentId,
  }) async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser!.uid;

      var query = supabase.from('reports').select().eq('reporter_id', currentUserId).eq('report_type', reportType);

      // Add target-specific filters based on report type
      switch (reportType) {
        case 'post':
          query = query.eq('target_post_id', targetPostId!);
          break;
        case 'comment':
          query = query.eq('target_comment_id', targetCommentId!);
          break;
        case 'account':
          query = query.eq('target_account_id', targetUserId!);
          break;
      }

      final response = await query;
      return response.isNotEmpty;
    } catch (error) {
      // If there's an error checking, allow the report to proceed
      return false;
    }
  }

  Future<bool> submitReport({
    required String reportType,
    String? targetUserId,
    String? targetPostId,
    String? targetCommentId,
  }) async {
    if (state.selectedReason == null) {
      return false;
    }

    setSubmitting(true);

    try {
      // Check if user has already reported this target
      final alreadyReported = await _checkExistingReport(
        reportType: reportType,
        targetUserId: targetUserId,
        targetPostId: targetPostId,
        targetCommentId: targetCommentId,
      );

      if (alreadyReported) {
        return false; // Will be handled in the UI to show appropriate message
      }

      final currentUserId = FirebaseAuth.instance.currentUser!.uid;

      final reportData = {
        'reporter_id': currentUserId,
        'report_type': reportType,
        'reason': state.selectedReason,
        'description': state.description.trim().isEmpty ? null : state.description.trim(),
      };

      // Add target IDs based on report type
      switch (reportType) {
        case 'post':
          reportData['target_post_id'] = targetPostId;
          break;
        case 'comment':
          reportData['target_comment_id'] = targetCommentId;
          break;
        case 'account':
          reportData['target_account_id'] = targetUserId;
          break;
      }

      await supabase.from('reports').insert(reportData);

      // Send notification if reporting an account
      if (reportType == 'account' && targetUserId != null) {
        await _sendAccountReportNotification(currentUserId, targetUserId);
      }

      return true;
    } catch (error) {
      return false;
    } finally {
      setSubmitting(false);
    }
  }
}

class ReportsPage extends ConsumerWidget {
  final String? targetUserId;
  final String? targetPostId;
  final String? targetCommentId;
  final String reportType; // 'post', 'comment', or 'account'

  const ReportsPage({
    super.key,
    this.targetUserId,
    this.targetPostId,
    this.targetCommentId,
    required this.reportType,
  });

  String get _reportTitle {
    switch (reportType) {
      case 'post':
        return 'Report Post';
      case 'comment':
        return 'Report Comment';
      case 'account':
        return 'Report Account';
      default:
        return 'Report';
    }
  }

  String get _reportSubtitle {
    switch (reportType) {
      case 'post':
        return 'Help us understand what\'s wrong with this post';
      case 'comment':
        return 'Help us understand what\'s wrong with this comment';
      case 'account':
        return 'Help us understand what\'s wrong with this account';
      default:
        return 'Help us understand the issue';
    }
  }

  Future<bool> _checkIfAlreadyReported(WidgetRef ref) async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser!.uid;

      var query = supabase.from('reports').select().eq('reporter_id', currentUserId).eq('report_type', reportType);

      // Add target-specific filters based on report type
      switch (reportType) {
        case 'post':
          query = query.eq('target_post_id', targetPostId!);
          break;
        case 'comment':
          query = query.eq('target_comment_id', targetCommentId!);
          break;
        case 'account':
          query = query.eq('target_account_id', targetUserId!);
          break;
      }

      final response = await query;
      return response.isNotEmpty;
    } catch (error) {
      return false;
    }
  }

  Future<void> _submitReport(WidgetRef ref, BuildContext context) async {
    final reportNotifier = ref.read(reportStateProvider.notifier);
    final reportState = ref.read(reportStateProvider);

    if (reportState.selectedReason == null) {
      Popup.showWarning(text: 'Please select a reason for reporting', context: context);
      return;
    }

    // Check if already reported before submitting
    final alreadyReported = await _checkIfAlreadyReported(ref);
    if (alreadyReported) {
      String targetType = reportType;
      if (targetType == 'account') targetType = 'user';

      Popup.showWarning(
        text: 'You have already reported this $targetType',
        context: context,
      );
      return;
    }

    final success = await reportNotifier.submitReport(
      reportType: reportType,
      targetUserId: targetUserId,
      targetPostId: targetPostId,
      targetCommentId: targetCommentId,
    );

    if (success) {
      Popup.showSuccess(text: 'Report submitted successfully', context: context);

      // Wait a moment for user to see success message
      await Future.delayed(const Duration(seconds: 1));

      if (context.mounted) {
        Navigator.of(context).pop();
      }
    } else {
      // Check again if it was a duplicate report issue
      final stillAlreadyReported = await _checkIfAlreadyReported(ref);
      if (stillAlreadyReported) {
        String targetType = reportType;
        if (targetType == 'account') targetType = 'user';

        Popup.showWarning(
          text: 'You have already reported this $targetType',
          context: context,
        );
      } else {
        Popup.showError(text: 'Failed to submit report. Please try again.', context: context);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportState = ref.watch(reportStateProvider);
    final descriptionController = ref.watch(reportDescriptionControllerProvider);
    final reasons = ref.watch(reportReasonsProvider);
    final reasonIcons = ref.watch(reportReasonIconsProvider);

    // Listen to controller changes and update state
    ref.listen(reportDescriptionControllerProvider, (previous, next) {
      next.addListener(() {
        ref.read(reportStateProvider.notifier).updateDescription(next.text);
      });
    });

    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        forceMaterialTransparency: true,
        backgroundColor: kWhite,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: kDeepPink),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _reportTitle,
          style: const TextStyle(
            color: kDeepPink,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: kWhite,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: kDeepPink.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.flag,
                      color: kDeepPink,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _reportTitle,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: kDeepPink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _reportSubtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Reason Selection
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: kWhite,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select a reason',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: kDeepPink,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...reasons.entries.map((entry) => _buildReasonOption(
                        ref,
                        entry.key,
                        entry.value,
                        reasonIcons[entry.key] ?? Icons.report,
                        reportState.selectedReason,
                      )),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Description Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: kWhite,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Additional details (optional)',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: kDeepPink,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Provide more context to help us understand the issue better.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    maxLines: 4,
                    maxLength: 500,
                    decoration: InputDecoration(
                      hintText: 'Describe the issue...',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: kDeepPink, width: 2),
                      ),
                      filled: true,
                      fillColor: kBackground,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: reportState.isSubmitting ? null : () => _submitReport(ref, context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kDeepPink,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                ),
                child: reportState.isSubmitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: kWhite,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Submit Report',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: kWhite,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 16),

            // Disclaimer
            Text(
              'Your report will be reviewed by our moderation team. We take all reports seriously and will take appropriate action.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReasonOption(
    WidgetRef ref,
    String value,
    String label,
    IconData icon,
    String? selectedReason,
  ) {
    final isSelected = selectedReason == value;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          ref.read(reportStateProvider.notifier).selectReason(value);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? kDeepPink : Colors.grey[300]!,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
            color: isSelected ? kDeepPink.withOpacity(0.05) : Colors.transparent,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? kDeepPink : Colors.grey[600],
                size: 24,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? kDeepPink : Colors.grey[800],
                  ),
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_circle,
                  color: kDeepPink,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
