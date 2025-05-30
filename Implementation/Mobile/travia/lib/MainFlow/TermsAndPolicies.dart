import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:travia/Helpers/AppColors.dart';

class TermsAndPoliciesPage extends StatefulWidget {
  const TermsAndPoliciesPage({super.key});

  @override
  State<TermsAndPoliciesPage> createState() => _TermsAndPoliciesPageState();
}

class _TermsAndPoliciesPageState extends State<TermsAndPoliciesPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Legal',
          style: GoogleFonts.lexendDeca(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(60),
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            decoration: BoxDecoration(
              color: kDeepGrey,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: EdgeInsets.all(4),
            child: TabBar(
              controller: _tabController,
              labelColor: kDeepPinkLight,
              unselectedLabelColor: kDeepPink,
              labelStyle: GoogleFonts.lexendDeca(fontWeight: FontWeight.bold),
              tabs: [
                Tab(text: 'Terms of Service'),
                Tab(text: 'Privacy Policy'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTermsOfService(),
          _buildPrivacyPolicy(),
        ],
      ),
    );
  }

  Widget _buildTermsOfService() {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader('TRAVIA Terms of Service'),
          _buildLastUpdated(),
          _buildIntroSection(),
          _buildSection(
            '1. Acceptance of Terms',
            'By accessing or using TRAVIA, you acknowledge that you have read, understood, and agree to be bound by these Terms of Service and our Privacy Policy. If you do not agree to these terms, please do not use our services.',
          ),
          _buildSection(
            '2. Description of Services',
            'TRAVIA is an intelligent travel planning and social networking application that provides:\n\n'
                '• AI-powered personalized travel planning\n'
                '• Social networking features for travelers\n'
                '• Location-based traveler discovery\n'
                '• Travel plan sharing and recommendations\n'
                '• Real-time event information\n'
                '• Travel content sharing platform',
          ),
          _buildSection(
            '3. User Registration and Account',
            'To use TRAVIA, you must:\n\n'
                '• Be at least 16 years of age\n'
                '• Provide accurate and complete registration information\n'
                '• Maintain the confidentiality of your account credentials\n'
                '• Notify us immediately of any unauthorized use of your account\n'
                '• Be responsible for all activities under your account',
          ),
          _buildSection(
            '4. User Content and Conduct',
            'When using TRAVIA, you agree to:\n\n'
                '• Not post content that is illegal, harmful, threatening, abusive, harassing, defamatory, or objectionable\n'
                '• Not impersonate any person or entity\n'
                '• Not share false or misleading information\n'
                '• Respect the intellectual property rights of others\n'
                '• Not use the service for any commercial purposes without our permission\n'
                '• Comply with all applicable Egyptian laws and regulations',
          ),
          _buildSection(
            '5. Location Services',
            'TRAVIA uses location services to:\n\n'
                '• Show nearby travelers and their plans\n'
                '• Provide location-based recommendations\n'
                '• Display real-time events in your plans\n\n'
                'You can control location sharing in your device settings. Continued use of GPS running in the background can decrease battery life.',
          ),
          _buildSection(
            '6. Intellectual Property',
            'All content on TRAVIA, including text, graphics, logos, and software, is the property of TRAVIA or its licensors and is protected by Egyptian and international copyright laws. You retain ownership of content you post but grant us a worldwide, non-exclusive, royalty-free license to use, reproduce, and distribute your content in connection with our services.',
          ),
          _buildSection(
            '7. Privacy and Data Protection',
            'Your use of TRAVIA is subject to our Privacy Policy, which complies with Egyptian Personal Data Protection Law No. 151 of 2020. We are committed to protecting your personal information and will process it only in accordance with applicable laws.',
          ),
          _buildSection(
            '8. Third-Party Services',
            'TRAVIA may contain links to third-party websites or services. We are not responsible for the content, privacy policies, or practices of these third parties. Your interactions with them are governed by their terms and policies.',
          ),
          _buildSection(
            '9. Disclaimers and Limitations of Liability',
            'TRAVIA is provided "as is" without warranties of any kind. We do not guarantee:\n\n'
                '• The accuracy of user-generated content\n'
                '• The safety or suitability of travel recommendations\n'
                '• Uninterrupted or error-free service\n\n'
                'To the fullest extent permitted by Egyptian law, TRAVIA shall not be liable for any indirect, incidental, special, or consequential damages.',
          ),
          _buildSection(
            '10. Indemnification',
            'You agree to indemnify and hold TRAVIA, its directors, developers, and agents harmless from any claims, losses, or damages arising from your use of the service or violation of these terms.',
          ),
          _buildSection(
            '11. Termination',
            'We may suspend your account at any time for violations of these terms. You may also log out of your account at any time.',
          ),
          _buildSection(
            '12. Governing Law',
            'These Terms shall be governed by the laws of the Arab Republic of Egypt. Any disputes shall be resolved in the courts of Cairo, Egypt.',
          ),
          _buildSection(
            '13. Changes to Terms',
            'We may update these Terms from time to time. We will notify you of material changes through the app or via email. Continued use after changes constitutes acceptance of the new terms.',
          ),
          _buildSection(
            '14. Contact Information',
            'For questions about these Terms, please contact us at:\n\n'
                'Email: youniesmm9@gmail.com OR mmahmoudgamal100@gmail.com\n'
                'Address: Cairo, Egypt',
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyPolicy() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader('TRAVIA Privacy Policy'),
          _buildLastUpdated(),
          _buildIntroSection(isPrivacy: true),
          _buildSection(
              '1. Information We Collect',
              'We collect the following types of information:\n\n'
                  'Personal Information:\n'
                  '• Name, email address, and username\n'
                  '• Age, gender, and relationship status\n'
                  '• Profile photo and bio\n'
                  '• Travel preferences and history\n'
                  '• Previously visited countries\n\n'
                  'Location Data:\n'
                  '• Real-time location (with your permission)\n'
                  'Usage Information:\n'
                  '• Social media interactions and features\n'
                  '• Travel plans created and shared\n'
                  '• Social connections and messages (Messages are encrypted)\n'
                  '• Posts, comments, and likes\n\n'),
          _buildSection(
            '2. Legal Basis for Processing',
            'In accordance with Egyptian Personal Data Protection Law, we process your data based on:\n\n'
                '• Your explicit consent\n'
                '• Performance of our services contract with you\n'
                '• Our legitimate interests in improving our services\n'
                '• Compliance with legal obligations',
          ),
          _buildSection(
            '3. How We Use Your Information',
            'We use your information to:\n\n'
                '• Provide personalized travel recommendations\n'
                '• Connect you with nearby travelers\n'
                '• Display real-time events and activities\n'
                '• Enable social features and messaging\n'
                '• Improve our AI algorithms and services\n'
                '• Send service updates and notifications\n'
                '• Ensure safety and prevent fraud\n'
                '• Comply with legal requirements',
          ),
          _buildSection(
            '4. Information Sharing',
            'We share your information with:\n\n'
                'Other Users:\n'
                '• Profile information based on your privacy settings\n'
                '• Travel plans you choose to make public from profile settings\n'
                '• Posts and content you share\n\n'
                'Service Providers:\n'
                '• Cloud storage providers (Supabase)\n'
                '• Analytics services\n'
                '• Payment processors (if applicable)\n\n'
                'Legal Requirements:\n'
                '• When required by Egyptian law or court order\n'
                '• To protect our rights or user safety',
          ),
          _buildSection(
            '5. Data Storage and Security',
            'Your data is:\n\n'
                '• Stored on secure servers with Supabase support\n'
                '• Protected using industry-standard encryption\n'
                '• Accessible only to authorized personnel (Admins)\n\n'
                'We will notify you within 72 hours of any data breach that may affect your personal information.',
          ),
          _buildSection(
            '6. Your Rights Under Egyptian Law',
            'You have the right to:\n\n'
                '• Access your personal data\n'
                '• Correct inaccurate information\n'
                '• Delete your account and data\n'
                '• Object to certain processing\n'
                '• Withdraw consent at any time\n'
                '• Data portability\n'
                '• Not be subject to automated decision-making\n\n'
                'To exercise these rights, contact us at youniesmm9@gmail.com OR mmahmoudgamal100@gmail.com',
          ),
          _buildSection(
            '7. Children\'s Privacy',
            'TRAVIA is not intended for children under 16. We do not knowingly collect data from children under this age. If we learn we have collected such information, we will promptly delete it.',
          ),
          _buildSection(
            '8. International Data Transfers',
            'Your data is primarily stored in secure Supabase servers. we ensure adequate protection through:\n\n'
                '• Data processing agreements\n'
                '• Appropriate safeguards as required by Egyptian law\n'
                '• Your explicit consent when necessary',
          ),
          _buildSection(
            '9. Changes to Privacy Policy',
            'We may update this policy to reflect changes in our practices or legal requirements. We will notify you of significant changes through the app or email.',
          ),
          _buildSection(
            '10. Contact Us',
            'For privacy-related questions or concerns:\n\n'
                'Email: youniesmm9@gmail.com OR mmahmoudgamal100@gmail.com\n'
                'Phone: +201069815476\n'
                'Address: Cairo, Egypt\n\n'
                'You may also contact the Egyptian Data Protection Authority for complaints.',
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String title) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [kDeepPink.withOpacity(0.1), kDeepPinkLight.withOpacity(0.1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            Icons.shield_outlined,
            size: 48,
            color: kDeepPink,
          ),
          SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.lexendDeca(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLastUpdated() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Text(
        'Last Updated: ${DateTime.now().toString().split(' ')[0]}',
        style: GoogleFonts.lexendDeca(
          fontSize: 14,
          color: Colors.grey.shade600,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  Widget _buildIntroSection({bool isPrivacy = false}) {
    return Container(
      padding: EdgeInsets.all(16),
      margin: EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: kDeepGrey,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isPrivacy
            ? 'This Privacy Policy explains how TRAVIA collects, uses, shares, and protects your information when you use our travel planning and social networking application. We are committed to protecting your privacy in accordance with Egyptian Personal Data Protection Law No. 151 of 2020 and international best practices.'
            : 'Welcome to TRAVIA! These Terms of Service ("Terms") govern your use of our travel planning and social networking application. By using TRAVIA, you agree to these Terms. Please read them carefully.',
        style: GoogleFonts.lexendDeca(
          fontSize: 14,
          height: 1.6,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Container(
      margin: EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [kDeepPinkLight, kDeepPink],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.lexendDeca(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Padding(
            padding: EdgeInsets.only(left: 16),
            child: Text(
              content,
              style: GoogleFonts.lexendDeca(
                fontSize: 14,
                height: 1.6,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
