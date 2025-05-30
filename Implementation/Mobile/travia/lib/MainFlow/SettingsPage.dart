import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travia/Auth/AuthMethods.dart';
import 'package:travia/Helpers/AppColors.dart';
import 'package:travia/Helpers/DeleteConfirmation.dart';
import 'package:travia/MainFlow/FeedbackPage.dart';
import 'package:travia/MainFlow/TermsAndPolicies.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: kDeepPink,
            size: 28,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(
            color: Colors.black,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 32),

            // Support & About Section
            const Text(
              'Support & About',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildSettingsItem(
                    icon: Icons.credit_card_outlined,
                    title: 'Support us',
                    onTap: () {},
                  ),
                  _buildDivider(),
                  _buildSettingsItem(
                    icon: Icons.info_outline,
                    title: 'Terms and Policies',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TermsAndPoliciesPage(),
                        ),
                      );
                    },
                    isLast: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Actions Section
            const Text(
              'Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildSettingsItem(
                    icon: Icons.feedback_outlined,
                    title: 'Add feedback',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FeedbackPage(),
                        ),
                      );
                    },
                  ),
                  _buildDivider(),
                  _buildSettingsItem(
                    icon: Icons.logout_outlined,
                    title: 'Logout',
                    onTap: () {
                      showCustomDialog(
                          context: context,
                          title: "Logout from Travia",
                          message: "Are you sure you want to logout? your information won't be lost, and you can sign in back anytime :)",
                          actionText: "Goodbye",
                          actionIcon: Icons.person,
                          onActionPressed: () async {
                            await signOut(context, ref);
                          });
                    },
                    isLast: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isLast = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(
              icon,
              size: 24,
              color: Colors.grey[700],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.only(left: 56),
      child: Divider(
        height: 1,
        thickness: 0.5,
        color: Colors.grey[300],
      ),
    );
  }
}
