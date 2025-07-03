import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:travia/Helpers/Constants.dart';

import '../Helpers/AppColors.dart';

// Models
class PostMetadata {
  final String metaId;
  final String postId;
  final int? romantic;
  final int? goodForKids;
  final int? classy;
  final int? casual;
  final String? combinedText;
  final DateTime createdAt;
  final String postMediaUrl;
  final String location;

  PostMetadata({
    required this.metaId,
    required this.postId,
    this.romantic,
    this.goodForKids,
    this.classy,
    this.casual,
    this.combinedText,
    required this.createdAt,
    required this.postMediaUrl,
    required this.location,
  });

  factory PostMetadata.fromJson(Map<String, dynamic> json) {
    return PostMetadata(
      metaId: json['meta_id'],
      postId: json['post_id'],
      romantic: json['romantic'],
      goodForKids: json['good_for_kids'],
      classy: json['classy'],
      casual: json['casual'],
      combinedText: json['combined_text'],
      createdAt: DateTime.parse(json['created_at']),
      postMediaUrl: json['post_media_url'],
      location: json['location'],
    );
  }
}

// Providers
final searchQueryProvider = StateProvider<String>((ref) => '');

final postsProvider = FutureProvider<List<PostMetadata>>((ref) async {
  final searchQuery = ref.watch(searchQueryProvider);
  final supabase = Supabase.instance.client;

  try {
    if (searchQuery.isEmpty) {
      // Fetch all posts
      final response = await supabase.from('metadata').select().order('created_at', ascending: false);

      return (response as List).map((e) => PostMetadata.fromJson(e)).toList();
    } else {
      // Search posts with fuzzy matching using ilike
      final response = await supabase.from('metadata').select().ilike('combined_text', '%$searchQuery%').order('created_at', ascending: false);

      return (response as List).map((e) => PostMetadata.fromJson(e)).toList();
    }
  } catch (e) {
    throw Exception('Failed to load posts: $e');
  }
});

final groupedPostsProvider = Provider<Map<String, List<PostMetadata>>>((ref) {
  final postsAsync = ref.watch(postsProvider);

  return postsAsync.when(
    data: (posts) {
      final grouped = <String, List<PostMetadata>>{};
      for (final post in posts) {
        final country = _extractCountry(post.location);
        grouped.putIfAbsent(country, () => []).add(post);
      }
      return grouped;
    },
    loading: () => {},
    error: (_, __) => {},
  );
});

// Helper function to extract country from location
String _extractCountry(String location) {
  // Assuming location format is "City, Country" or just "Country"
  final parts = location.split(',');
  if (parts.length > 1) {
    return parts.last.trim();
  }
  return location.trim();
}

// Main Search Page
class SearchPage extends ConsumerWidget {
  const SearchPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupedPosts = ref.watch(groupedPostsProvider);
    final postsAsync = ref.watch(postsProvider);

    return Scaffold(
      backgroundColor: kBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Search Header
            _buildSearchHeader(context, ref),

            // Content
            Expanded(
              child: postsAsync.when(
                data: (_) {
                  if (groupedPosts.isEmpty) {
                    return _buildEmptyState();
                  }
                  return _buildPostsList(groupedPosts);
                },
                loading: () => Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(kDeepPink),
                  ),
                ),
                error: (error, _) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 60, color: kDeepPink),
                      SizedBox(height: 16),
                      Text(
                        'Oops! Something went wrong',
                        style: GoogleFonts.lexendDeca(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        error.toString(),
                        style: GoogleFonts.lexendDeca(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchHeader(BuildContext context, WidgetRef ref) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_ios, color: kDeepPink),
                onPressed: () => Navigator.pop(context),
              ),
              Expanded(
                child: Text(
                  'Explore Posts',
                  style: GoogleFonts.lexendDeca(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(width: 48), // Balance the back button
            ],
          ),
          SizedBox(height: 16),
          // Search Bar
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [kDeepPink.withOpacity(0.1), kDeepPinkLight.withOpacity(0.1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: kDeepPink.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: TextField(
              onChanged: (value) {
                ref.read(searchQueryProvider.notifier).state = value;
              },
              style: GoogleFonts.lexendDeca(
                fontSize: 16,
                color: Colors.black87,
              ),
              decoration: InputDecoration(
                hintText: 'Search for posts and vibes...',
                hintStyle: GoogleFonts.lexendDeca(
                  fontSize: 16,
                  color: Colors.grey[500],
                ),
                prefixIcon: Icon(Icons.search, color: kDeepPink),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(40),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [kDeepPink.withOpacity(0.1), kDeepPinkLight.withOpacity(0.1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Icon(
              Icons.search_off,
              size: 80,
              color: kDeepPink,
            ),
          ),
          SizedBox(height: 24),
          Text(
            'No Posts found',
            style: GoogleFonts.lexendDeca(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Try adjusting your search',
            style: GoogleFonts.lexendDeca(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostsList(Map<String, List<PostMetadata>> groupedPosts) {
    final sortedCountries = groupedPosts.keys.toList()..sort();

    return ListView.builder(
      padding: EdgeInsets.only(bottom: 20),
      itemCount: sortedCountries.length,
      itemBuilder: (context, index) {
        final country = sortedCountries[index];
        final posts = groupedPosts[country]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(country, posts.length),
            SizedBox(
              height: 220,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 16),
                itemCount: posts.length,
                itemBuilder: (context, index) {
                  return _buildPostCard(posts[index], context);
                },
              ),
            ),
            SizedBox(height: 20),
          ],
        );
      },
    );
  }

  Widget _buildSectionTitle(String country, int count) {
    String countryIcon = getEmojiFromCountryName(country);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Text(
            "$country $countryIcon",
            style: GoogleFonts.ibmPlexSans(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(width: 8),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: kDeepPink.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kDeepPink.withOpacity(0.3)),
            ),
            child: Text(
              "$count ${count == 1 ? 'post' : 'posts'}",
              style: GoogleFonts.ibmPlexSans(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: kDeepPink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostCard(PostMetadata post, BuildContext context) {
    return Container(
      width: 160,
      margin: EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: () {
          context.push("/post/${post.postId}");
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Container(
              height: 160,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(
                  imageUrl: post.postMediaUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [kDeepPink.withOpacity(0.1), kDeepPinkLight.withOpacity(0.1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(kDeepPink),
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [kDeepPink.withOpacity(0.2), kDeepPinkLight.withOpacity(0.2)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Icon(Icons.image_not_supported, color: kDeepPink),
                  ),
                ),
              ),
            ),
            // Tags
            if (post.romantic != null || post.classy != null || post.casual != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  children: [
                    if (post.romantic != null && post.romantic! == 1) _buildTag('Romantic'),
                    if (post.classy != null && post.classy! == 1) _buildTag('Classy'),
                    if (post.casual != null && post.casual! == 1) _buildTag('Casual'),
                    if (post.goodForKids != null && post.goodForKids! == 1) _buildTag('Good For Kids'),
                  ].take(2).toList(), // Show max 2 tags
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String label) {
    return Container(
      margin: EdgeInsets.only(right: 4),
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [kDeepPink, kDeepPinkLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.lexendDeca(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      ),
    );
  }
}
