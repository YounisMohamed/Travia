import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:story_view/controller/story_controller.dart';
import 'package:story_view/utils.dart';
import 'package:story_view/widgets/story_view.dart';

import '../Classes/story_model.dart';
import '../Helpers/DummyCards.dart';
import '../Helpers/HelperMethods.dart';
import '../Helpers/PopUp.dart';
import '../Providers/ImagePickerProvider.dart';
import '../Providers/StoriesProviders.dart';
import '../Providers/UploadProviders.dart';

class StoryBar extends ConsumerWidget {
  const StoryBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storiesAsync = ref.watch(storiesProvider);
    final user = FirebaseAuth.instance.currentUser;

    return storiesAsync.when(
      data: (stories) {
        final userStory = user != null ? stories.where((s) => s.userId == user.uid).firstOrNull : null;

        return SizedBox(
          height: 90,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: stories.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                // First tile is always the "Add Story" bubble
                return _AddStoryBubble(
                  userPhotoUrl: user?.photoURL,
                  hasActiveStory: userStory != null,
                  onTap: () async {
                    print("Tapped: Starting media selection process");

                    // Clear any previously selected files
                    print("Clearing previously selected files...");
                    ref.read(multiMediaPickerProvider.notifier).clearFiles();

                    // Pick multiple media files
                    print("Opening media picker...");
                    await ref.read(multiMediaPickerProvider.notifier).pickMultipleMedia(context);
                    print("Media picker closed");

                    // Get the selected files
                    final mediaFiles = ref.read(multiMediaPickerProvider).toSet().toList();
                    print("Selected ${mediaFiles.length} media files");

                    if (mediaFiles.isEmpty) {
                      print("No media files selected, exiting");
                      return;
                    }

                    String? storyId;

                    // If user already has a story, use that story's ID
                    if (userStory != null) {
                      storyId = userStory.storyId;
                      print("User already has a story with ID: $storyId");
                    } else {
                      // Otherwise, create a new story
                      storyId = await createNewStory();
                      if (storyId == null) {
                        print("Failed to create story");
                        Popup.showPopUp(
                          text: 'Failed to create story',
                          context: context,
                          color: Colors.redAccent,
                        );
                        return;
                      }
                      print("Created new story with ID: $storyId");
                    }

                    // Track success/failure counts
                    int successCount = 0;
                    int failCount = 0;

                    // Process each media file as an item in the same story
                    for (final mediaFile in mediaFiles) {
                      print("Processing file: ${mediaFile.path}");

                      // Upload the media to Supabase
                      final mediaUrl = await ref.read(storyMediaUploadProvider.notifier).uploadStory(
                            userId: user!.uid,
                            mediaFile: mediaFile,
                          );
                      print("Upload result URL: $mediaUrl");

                      if (mediaUrl == null) {
                        print("Upload failed for: ${mediaFile.path}");
                        failCount++;
                        continue;
                      }

                      // Determine if the file is a video
                      final isVideo = mediaFile.path.endsWith('.mp4') || mediaFile.path.endsWith('.mov');
                      print("Media type detected: ${isVideo ? "video" : "image"}");
                      if (storyId == null) throw Exception();
                      try {
                        // Add the item to the story
                        print("Adding item to story for: $mediaUrl");
                        final success = await addStoryItem(
                          storyId: storyId,
                          mediaUrl: mediaUrl,
                          mediaType: isVideo ? "video" : "image",
                        );

                        if (success) {
                          print("Story item added successfully for $mediaUrl");
                          successCount++;
                        } else {
                          print("Story item addition failed for $mediaUrl");
                          failCount++;
                        }
                      } catch (e) {
                        print("Exception occurred while adding story item for $mediaUrl: $e");
                        failCount++;
                      }
                    }

                    // Show appropriate feedback based on the results
                    print("Upload complete: $successCount succeeded, $failCount failed");
                    if (successCount > 0 && failCount == 0) {
                      final isUpdate = userStory != null;
                      Popup.showPopUp(
                        text: isUpdate ? 'Your story has been updated!' : 'Your story has been created!',
                        context: context,
                        color: Colors.greenAccent,
                      );
                    } else if (successCount > 0 && failCount > 0) {
                      Popup.showPopUp(
                        text: 'Added $successCount items to your story, but $failCount failed',
                        context: context,
                        color: Colors.orangeAccent,
                      );
                    } else {
                      Popup.showPopUp(
                        text: 'Failed to update story',
                        context: context,
                        color: Colors.redAccent,
                      );
                    }
                    ref.invalidate(storiesProvider);

                    // Clear the files after processing
                    print("Clearing selected files after processing");
                    ref.read(multiMediaPickerProvider.notifier).clearFiles();

                    print("onTap process completed");
                  },
                );
              }

              // For the user's own story (if they have one), show it at index 1
              if (index == 1 && userStory != null) {
                return _buildStoryBubble(context, userStory);
              }

              // Adjust index for other stories to account for the user's story possibly taking slot 1
              final adjustedIndex = userStory != null ? index - 1 : index;
              final otherStories = stories.where((s) => s.userId != user?.uid).toList();

              // Check if the adjusted index is valid for other stories
              if (adjustedIndex - 1 < otherStories.length) {
                final story = otherStories[adjustedIndex - 1];
                return _buildStoryBubble(context, story);
              }

              return const SizedBox.shrink(); // Fallback for any edge cases
            },
          ),
        );
      },
      loading: () => DummyStory(),
      error: (err, stack) => const SizedBox.shrink(),
    );
  }

  Widget _buildStoryBubble(BuildContext context, story_model story) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => StoryViewerPage(story: story),
        ));
      },
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Colors.purpleAccent,
              child: CircleAvatar(
                radius: 25,
                backgroundImage: story.userPhotoUrl != null ? CachedNetworkImageProvider(story.userPhotoUrl!) : null,
                child: story.userPhotoUrl == null ? const Icon(Icons.person) : null,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              story.username ?? 'User',
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class StoryViewerPage extends StatefulWidget {
  final story_model story;

  const StoryViewerPage({super.key, required this.story});

  @override
  State<StoryViewerPage> createState() => _StoryViewerPageState();
}

class _StoryViewerPageState extends State<StoryViewerPage> {
  final controller = StoryController();
  final TextEditingController messageController = TextEditingController();
  bool isLiked = false;

  @override
  Widget build(BuildContext context) {
    final story = widget.story;
    final items = story.items
            ?.map(
              (item) {
                if (item.mediaType == 'image' && item.mediaUrl != null) {
                  return StoryItem.pageImage(
                    url: item.mediaUrl!,
                    controller: controller,
                    caption: Text("${item.caption}\n${timeAgo(item.createdAt)}" ?? ''),
                    captionOuterPadding: EdgeInsets.only(bottom: 50, left: 20),
                  );
                } else if (item.mediaType == 'video' && item.mediaUrl != null) {
                  return StoryItem.pageVideo(
                    item.mediaUrl!,
                    controller: controller,
                    caption: Text("${item.caption}\n${timeAgo(item.createdAt)}" ?? ''),
                  );
                } else if (item.mediaType == 'text') {
                  return StoryItem.text(
                    title: "${item.caption}\n${timeAgo(item.createdAt)}" ?? '',
                    backgroundColor: Colors.white,
                  );
                }
                return null;
              },
            )
            .whereType<StoryItem>()
            .toList() ??
        [];

    if (items.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_upload_outlined, size: 64, color: Colors.white70),
                SizedBox(height: 16),
                Text(
                  'Loading Story..',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Close off the story and it will be uploaded..',
                  style: TextStyle(color: Colors.white54),
                ),
                SizedBox(height: 24),
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          StoryView(
            storyItems: items,
            controller: controller,
            onComplete: () => Navigator.of(context).pop(),
            onVerticalSwipeComplete: (direction) {
              if (direction == Direction.down) {
                Navigator.of(context).pop();
              }
            },
          ),

          // Top Bar
          Positioned(
            top: 60,
            left: 16,
            right: 16,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: NetworkImage(story.userPhotoUrl ?? ''),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      story.username ?? '',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const Spacer(),
                if (story.userId == FirebaseAuth.instance.currentUser!.uid)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.white),
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Delete Story?'),
                          content: const Text('This will delete the entire story.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        // TODO: delete story from Supabase
                      }
                    },
                  ),
              ],
            ),
          ),

          // Bottom Input Bar
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: Row(
              children: [
                IconButton(
                  icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border, color: Colors.red),
                  onPressed: () {},
                ),
                Expanded(
                  child: TextField(
                    controller: messageController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Send a message...',
                      hintStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.white24,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.white),
                  onPressed: () {
                    final msg = messageController.text.trim();
                    if (msg.isNotEmpty) {
                      // TODO: handle sending message (to story owner or backend)
                      messageController.clear();
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddStoryBubble extends StatelessWidget {
  final String? userPhotoUrl;
  final bool hasActiveStory;
  final VoidCallback onTap;

  const _AddStoryBubble({
    super.key,
    required this.userPhotoUrl,
    required this.hasActiveStory,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    print(userPhotoUrl);
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  child: CircleAvatar(
                    radius: 25,
                    backgroundImage: userPhotoUrl != null ? CachedNetworkImageProvider(userPhotoUrl!) : null,
                    child: userPhotoUrl == null ? const Icon(Icons.person) : null,
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: CircleAvatar(
                    radius: 10,
                    backgroundColor: Colors.white,
                    child: Icon(hasActiveStory ? Icons.add_circle : Icons.add, color: Colors.purple, size: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              hasActiveStory ? "Add to Story" : "Your Story",
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
