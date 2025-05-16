import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_dialogs/dialogs.dart';
import 'package:material_dialogs/widgets/buttons/icon_button.dart';
import 'package:material_dialogs/widgets/buttons/icon_outline_button.dart';
import 'package:story_view/controller/story_controller.dart';
import 'package:story_view/utils.dart';
import 'package:story_view/widgets/story_view.dart';
import 'package:travia/Classes/story_item_model.dart';

import '../Classes/story_model.dart';
import '../Helpers/DummyCards.dart';
import '../Helpers/HelperMethods.dart';
import '../Helpers/PopUp.dart';
import '../Providers/ConversationProvider.dart';
import '../Providers/ImagePickerProvider.dart';
import '../Providers/LoadingProvider.dart';
import '../Providers/StoriesProviders.dart';
import '../Providers/UploadProviders.dart';
import '../database/DatabaseMethods.dart';
import '../main.dart';

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

                    ref.read(loadingProvider.notifier).setLoadingToTrue();

                    // If user already has a story, use that story's ID
                    if (userStory != null) {
                      storyId = userStory.storyId;
                      print("User already has a story with ID: $storyId");
                    } else {
                      // Otherwise, create a new story
                      storyId = await createNewStory();
                      if (storyId == null) {
                        ref.read(loadingProvider.notifier).setLoadingToFalse();
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
                    ref.read(loadingProvider.notifier).setLoadingToFalse();

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

class StoryViewerPage extends ConsumerStatefulWidget {
  final story_model story;

  const StoryViewerPage({
    Key? key,
    required this.story,
  }) : super(key: key);

  @override
  ConsumerState<StoryViewerPage> createState() => _StoryViewerPageState();
}

class _StoryViewerPageState extends ConsumerState<StoryViewerPage> {
  final controller = StoryController();
  final TextEditingController messageController = TextEditingController();

  Timer? _resumeTimer;
  int? _currentStoryIndex;

  @override
  void initState() {
    super.initState();
    messageController.addListener(_handleTextChange);
    _findCurrentStoryIndex();
  }

  @override
  void dispose() {
    _resumeTimer?.cancel();
    messageController.removeListener(_handleTextChange);
    messageController.dispose();
    controller.dispose();
    super.dispose();
  }

  void _handleTextChange() {
    _pauseStory();
    _resetResumeTimer();
  }

  void _pauseStory() {
    ref.read(storyPausedProvider.notifier).state = true;
    controller.pause();
  }

  void _resumeStory() {
    ref.read(storyPausedProvider.notifier).state = false;
    controller.play();
  }

  void _resetResumeTimer() {
    _resumeTimer?.cancel();
    _resumeTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        _resumeStory();
      }
    });
  }

  void _findCurrentStoryIndex() {
    final storiesAsync = ref.read(storiesProvider);
    if (storiesAsync is AsyncData) {
      final stories = storiesAsync.value;
      if (stories == null) return;

      // Get the current user ID
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;

      // Create a sorted list that matches the UI order (current user first, then others)
      List<story_model> sortedStories = [];

      // Add current user's story if it exists
      if (currentUserId != null) {
        final userStory = stories.where((s) => s.userId == currentUserId).firstOrNull;
        if (userStory != null) {
          sortedStories.add(userStory);
        }
      }

      // Add all other stories
      sortedStories.addAll(stories.where((s) => s.userId != currentUserId));

      // Find the index of the current story in the sorted list
      _currentStoryIndex = sortedStories.indexWhere((s) => s.storyId == widget.story.storyId);
      print("Current story index: $_currentStoryIndex out of ${sortedStories.length} stories");
    }
  }

// Navigate to the next story
  void _goToNextStory() {
    if (_currentStoryIndex == null) {
      print("No current story index found");
      Navigator.of(context).pop();
      return;
    }

    final storiesAsync = ref.read(storiesProvider);
    if (storiesAsync is AsyncData) {
      final stories = storiesAsync.value;
      if (stories == null || stories.isEmpty) {
        print("No stories available");
        Navigator.of(context).pop();
        return;
      }

      // Get the current user ID
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;

      // Create a sorted list that matches the UI order (current user first, then others)
      List<story_model> sortedStories = [];

      // Add current user's story if it exists
      if (currentUserId != null) {
        final userStory = stories.where((s) => s.userId == currentUserId).firstOrNull;
        if (userStory != null) {
          sortedStories.add(userStory);
        }
      }

      // Add all other stories
      sortedStories.addAll(stories.where((s) => s.userId != currentUserId));

      print("Navigating from story ${_currentStoryIndex} out of ${sortedStories.length} total stories");

      // Check if there's a next story available
      if (_currentStoryIndex! < sortedStories.length - 1) {
        final nextStory = sortedStories[_currentStoryIndex! + 1];
        print("Moving to next story: ${nextStory.username}");

        // Replace current story page with the next story
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => StoryViewerPage(story: nextStory),
          ),
        );
      } else {
        print("No more stories, closing viewer");
        // No more stories, close the viewer
        Navigator.of(context).pop();
      }
    } else {
      print("Could not access stories list");
      // If we can't access the stories list, just close the viewer
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final story = widget.story;
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;
    final sortedItems = List.from(story.items ?? [])..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final items = sortedItems
        .map(
          (itemMap) {
            story_item_model item = itemMap;
            if (item.mediaType == 'image') {
              return StoryItem.pageImage(
                  url: item.mediaUrl,
                  controller: controller,
                  loadingWidget: const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                  captionOuterPadding: const EdgeInsets.only(bottom: 50, left: 20),
                  duration: Duration(seconds: 10));
            } else if (item.mediaType == 'video' && item.mediaUrl != null) {
              // Use the fixed pageVideo function that supports looping
              return StoryItem.pageVideo(
                item.mediaUrl!,
                controller: controller,
                caption: Text(item.caption ?? ''),
                duration: Duration(seconds: 10),
              );
            }
            return null;
          },
        )
        .whereType<StoryItem>()
        .toList();

    return Consumer(
      builder: (context, ref, _) {
        final currentIndex = ref.watch(currentStoryItemIndexProvider);
        final isPaused = ref.watch(storyPausedProvider);

        final safeCurrentIndex = currentIndex >= sortedItems.length ? (sortedItems.isEmpty ? 0 : sortedItems.length - 1) : currentIndex;

        if (safeCurrentIndex != currentIndex && sortedItems.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(currentStoryItemIndexProvider.notifier).state = safeCurrentIndex;
          });
        }

        if (sortedItems.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pop();
          });
          return const SizedBox();
        }

        story_item_model currentItem = sortedItems[safeCurrentIndex];
        final currentItemId = currentItem.itemId;
        final likedStories = ref.watch(likeStoryItemProvider);
        final isLiked = likedStories[currentItemId] ?? false;

        if (isPaused) {
          controller.pause();
        } else {
          if (currentItem.mediaType != 'video') {
            controller.play();
          }
        }

        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              StoryView(
                storyItems: items,
                controller: controller,
                onComplete: () => _goToNextStory(),
                onVerticalSwipeComplete: (direction) {
                  if (direction == Direction.down) {
                    Navigator.of(context).pop();
                  }
                },
                onStoryShow: (storyItem, index) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ref.read(currentStoryItemIndexProvider.notifier).state = index;
                  });
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
                        const SizedBox(height: 4),
                        Text(
                          timeAgo(currentItem.createdAt),
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                    const Spacer(),
                    if (story.userId == currentUserId)
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.white),
                        onPressed: () {
                          controller.pause();
                          Dialogs.materialDialog(
                            msg: 'Are you sure? You can\'t undo this',
                            title: "Delete",
                            color: Colors.white,
                            context: context,
                            actions: [
                              IconsOutlineButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  controller.play();
                                },
                                text: 'Cancel',
                                iconData: Icons.cancel_outlined,
                                textStyle: const TextStyle(color: Colors.grey),
                                iconColor: Colors.grey,
                              ),
                              IconsButton(
                                onPressed: () async {
                                  try {
                                    deleteStoryFromDatabase(currentItemId);

                                    final newSortedItems = sortedItems.where((item) => item.itemId != currentItemId).toList();

                                    if (newSortedItems.isEmpty) {
                                      Navigator.of(context).pop();
                                      Navigator.of(context).pop();
                                      ref.invalidate(storiesProvider);
                                      return;
                                    }

                                    int newIndex = safeCurrentIndex;
                                    if (safeCurrentIndex >= newSortedItems.length) {
                                      newIndex = newSortedItems.length - 1;
                                    }

                                    ref.invalidate(storiesProvider);

                                    WidgetsBinding.instance.addPostFrameCallback((_) {
                                      ref.read(currentStoryItemIndexProvider.notifier).state = newIndex;
                                    });

                                    Popup.showPopUp(
                                      text: "Story item deleted, refresh to see changes",
                                      context: context,
                                      color: Colors.green,
                                    );

                                    Navigator.of(context).pop();

                                    controller.pause();
                                    WidgetsBinding.instance.addPostFrameCallback((_) {
                                      controller.play();
                                    });
                                  } catch (e) {
                                    print("Error while deleting story item: $e");
                                    Popup.showPopUp(
                                      text: "Error while deleting the story item",
                                      context: context,
                                      color: Colors.red,
                                    );
                                    Navigator.of(context).pop();
                                  }
                                },
                                text: 'Delete',
                                iconData: Icons.delete,
                                color: Colors.red,
                                textStyle: const TextStyle(color: Colors.white),
                                iconColor: Colors.white,
                              ),
                            ],
                          );
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
                      icon: Icon(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        color: isLiked ? Colors.red : Colors.white,
                      ),
                      onPressed: () {
                        ref.read(likeStoryItemProvider.notifier).toggleLike(
                              storyItemId: currentItemId,
                              likerId: currentUserId,
                              storyOwnerId: story.userId,
                            );
                        if (story.userId != currentUserId) {
                          Future.microtask(() async {
                            try {
                              await sendNotification(
                                type: 'story_like',
                                title: "liked your story ❤️",
                                content: "",
                                target_user_id: story.userId,
                                source_id: currentItemId,
                                sender_user_id: currentUserId,
                              );
                            } catch (e) {
                              print("Notification error: $e");
                            }
                          });
                        }
                      },
                    ),
                    Expanded(
                      child: TextField(
                        controller: messageController,
                        style: const TextStyle(color: Colors.white),
                        onTap: () {
                          _pauseStory();
                          _resetResumeTimer();
                        },
                        onChanged: (_) {
                          _pauseStory();
                          _resetResumeTimer();
                        },
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
                        onPressed: () async {
                          final msg = messageController.text.trim();
                          if (msg.isEmpty) return;

                          // Resume the story immediately after sending
                          _resumeStory();
                          _resumeTimer?.cancel();
                          _resumeTimer = null;

                          final currentUserId = FirebaseAuth.instance.currentUser!.uid;
                          final targetUserId = story.userId;
                          if (currentUserId == targetUserId) {
                            Popup.showPopUp(
                              text: "Cant send a message to yourself :)",
                              context: context,
                              color: Colors.red,
                            );
                            return;
                          }
                          messageController.clear();

                          try {
                            // Find or create a conversation via your provider
                            final conversationId = await ref.read(createConversationProvider(targetUserId).future);

                            story_item_model currentItem = sortedItems[safeCurrentIndex];
                            final storyMediaUrl = currentItem.mediaUrl ?? '';

                            await supabase
                                .from('messages')
                                .insert({
                                  'conversation_id': conversationId,
                                  'sender_id': currentUserId,
                                  'content': "$storyMediaUrl $msg",
                                  'content_type': 'story_reply',
                                })
                                .select('message_id')
                                .single();

                            // 5. Send notification
                            await sendNotification(
                              type: 'message',
                              title: "replied to your story",
                              content: msg,
                              target_user_id: targetUserId,
                              source_id: conversationId,
                              sender_user_id: currentUserId,
                            );

                            // 6. Optional: Show success message
                            Popup.showPopUp(
                              text: "Reply sent",
                              context: context,
                              color: Colors.green,
                            );
                          } catch (e) {
                            print("Error sending story reply: $e");
                            Popup.showPopUp(
                              text: "Failed to send reply",
                              context: context,
                              color: Colors.red,
                            );
                          }
                        }),
                  ],
                ),
              ),
            ],
          ),
        );
      },
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
