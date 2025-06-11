#!/usr/bin/env python3
"""
Comprehensive Test Script for Metadata-Based Learning System

This script tests:
1. Post likes simulation with metadata attributes
2. User preference learning from liked posts
3. Business recommendation improvement based on learned preferences
4. Detailed analytics and insights
"""

import psycopg2
import psycopg2.extras
import json
import random
import uuid
from datetime import datetime, timedelta
from flask_app import TravelRecommendationSystem, DB_CONFIG

class MetadataLearningTester:
    def __init__(self):
        self.recommendation_system = TravelRecommendationSystem()
        self.test_user_id = str(uuid.uuid4())
        self.test_posts = []
        
    def setup_test_environment(self):
        """Set up test data including posts, metadata, and initial user"""
        print("🔧 Setting up test environment...")
        
        conn = psycopg2.connect(**DB_CONFIG)
        cursor = conn.cursor()
        
        try:
            # Create test user with required fields
            cursor.execute("""
                INSERT INTO users (id, email, display_name, username, gender, viewed_posts, saved_posts, 
                                  is_younis, liked_posts, uploaded_posts, following_ids, friend_ids, 
                                  visited_countries, age, public, "showLikedPosts")
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                ON CONFLICT (id) DO NOTHING
            """, (self.test_user_id, f"test_{self.test_user_id[:8]}@example.com", f"Test User {self.test_user_id[:8]}", 
                  f"testuser_{self.test_user_id[:8]}", 'Male', '{}', '{}', False, '{}', '{}', '{}', '{}', '{}', 
                  datetime(2000, 1, 1), True, True))
            
            # Create sample posts with diverse metadata - using actual posts table structure
            sample_posts = [
                {
                    'post_id': f'test_post_{i}',
                    'user_id': f'poster_{i % 5}',  # Rotate between 5 different posters
                    'caption': self._generate_caption(i),
                    'location': random.choice(['Las Vegas, NV', 'Phoenix, AZ', 'Charlotte, NC', 'Tampa, FL']),
                    'poster_username': f'user_{i % 5}',
                    'likes_count': random.randint(5, 100),
                    'views': random.randint(20, 300),
                    'calm': random.choice([0, 1]),
                    'noisy': random.choice([0, 1]),
                    'romantic': random.choice([0, 1]),
                    'good_for_kids': random.choice([0, 1]),
                    'classy': random.choice([0, 1]),
                    'casual': random.choice([0, 1]),
                    'family_friendly_places': random.choice([0, 1]),
                    'cuisine_type': random.choice(['Italian', 'Chinese', 'Mexican', 'American', 'Thai', 'Indian', 'French', 'Japanese']),
                    'price_range': random.choice([1, 2, 3, 4])
                }
                for i in range(50)
            ]
            
            # Insert posts using actual table structure
            for post in sample_posts:
                try:
                    cursor.execute("""
                        INSERT INTO posts 
                        (id, user_id, caption, location, poster_username, likes_count, views, created_at) 
                        VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                        ON CONFLICT (id) DO UPDATE SET
                        caption = EXCLUDED.caption,
                        location = EXCLUDED.location,
                        likes_count = EXCLUDED.likes_count,
                        views = EXCLUDED.views
                    """, (
                        post['post_id'], post['user_id'], post['caption'], 
                        post['location'], post['poster_username'], 
                        post['likes_count'], post['views'], datetime.now()
                    ))
                except Exception as e:
                    print(f"Note: Error inserting post {post['post_id']}: {e}")
            
            # Insert metadata
            for post in sample_posts:
                cursor.execute("""
                    INSERT INTO metadata 
                    (post_id, calm, noisy, romantic, good_for_kids, classy, casual, 
                     family_friendly_places, location, cuisine_type, price_range)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                    ON CONFLICT (post_id) DO UPDATE SET
                    calm = EXCLUDED.calm,
                    noisy = EXCLUDED.noisy,
                    romantic = EXCLUDED.romantic,
                    good_for_kids = EXCLUDED.good_for_kids,
                    classy = EXCLUDED.classy,
                    casual = EXCLUDED.casual,
                    family_friendly_places = EXCLUDED.family_friendly_places,
                    location = EXCLUDED.location,
                    cuisine_type = EXCLUDED.cuisine_type,
                    price_range = EXCLUDED.price_range
                """, (
                    post['post_id'], post['calm'], post['noisy'], post['romantic'],
                    post['good_for_kids'], post['classy'], post['casual'],
                    post['family_friendly_places'], post['location'], 
                    post['cuisine_type'], post['price_range']
                ))
            
            self.test_posts = sample_posts
            conn.commit()
            print(f"✅ Created test user: {self.test_user_id}")
            print(f"✅ Created {len(sample_posts)} sample posts with metadata")
            
        except Exception as e:
            print(f"❌ Error setting up test environment: {e}")
            conn.rollback()
        finally:
            cursor.close()
            conn.close()
    
    def _generate_caption(self, index):
        """Generate realistic captions for test posts"""
        captions = [
            "Amazing dinner at this fantastic restaurant! 🍽️✨",
            "Perfect family spot for a great meal 👨‍👩‍👧‍👦🍕",
            "Romantic evening at this beautiful place 💕🌹",
            "Love the casual vibe here! Great food 😊🍔",
            "Upscale dining experience - totally worth it! 🥂✨",
            "Kids had so much fun here! Family-friendly 🎉👶",
            "Quiet and peaceful - perfect for a date 🌸🍣",
            "Lively atmosphere and delicious food! 🎊🌮",
            "Classy establishment with excellent service 🍷👔",
            "Casual but delicious - highly recommend! 👍🍝"
        ]
        return captions[index % len(captions)]
    
    def simulate_user_preferences(self, preference_profile="romantic_foodie"):
        """Simulate different user preference profiles"""
        profiles = {
            "romantic_foodie": {
                "likes": lambda post: (
                    post['romantic'] == 1 or 
                    post['classy'] == 1 or
                    post['cuisine_type'] in ['Italian', 'French'] or
                    post['price_range'] >= 3
                ),
                "description": "Likes romantic, classy places, especially Italian/French cuisine, higher price ranges"
            },
            "family_oriented": {
                "likes": lambda post: (
                    post['good_for_kids'] == 1 or
                    post['family_friendly_places'] == 1 or
                    post['casual'] == 1 or
                    post['price_range'] <= 2
                ),
                "description": "Likes family-friendly, casual places with moderate pricing"
            },
            "young_social": {
                "likes": lambda post: (
                    post['noisy'] == 1 or
                    post['casual'] == 1 or
                    post['cuisine_type'] in ['Mexican', 'American', 'Thai'] or
                    post['price_range'] <= 3
                ),
                "description": "Likes noisy, casual places, diverse cuisines, budget-conscious"
            },
            "quiet_contemplative": {
                "likes": lambda post: (
                    post['calm'] == 1 or
                    post['romantic'] == 1 or
                    post['classy'] == 1 or
                    post['cuisine_type'] in ['Japanese', 'Chinese']
                ),
                "description": "Likes calm, romantic, classy places, Asian cuisine"
            }
        }
        
        if preference_profile not in profiles:
            preference_profile = "romantic_foodie"
        
        profile = profiles[preference_profile]
        print(f"\n👤 Testing with profile: {preference_profile}")
        print(f"   Description: {profile['description']}")
        
        return profile['likes']
    
    def simulate_user_likes(self, preference_function, num_likes=15):
        """Simulate user liking posts based on preference function"""
        print(f"\n❤️ Simulating {num_likes} user likes...")
        
        conn = psycopg2.connect(**DB_CONFIG)
        cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        
        liked_posts = []
        attempts = 0
        max_attempts = len(self.test_posts) * 2
        
        while len(liked_posts) < num_likes and attempts < max_attempts:
            post = random.choice(self.test_posts)
            attempts += 1
            
            # Skip if already liked
            if post['post_id'] in [p['post_id'] for p in liked_posts]:
                continue
            
            # Check if user would like this post
            if preference_function(post):
                try:
                    cursor.execute("""
                        INSERT INTO likes (liker_user_id, post_id, type, created_at)
                        VALUES (%s, %s, %s, %s)
                    """, (self.test_user_id, post['post_id'], 'like', datetime.now()))
                    
                    # Get detailed post info for display
                    cursor.execute("""
                        SELECT p.caption, p.location, p.likes_count,
                               m.cuisine_type, m.romantic, m.good_for_kids, m.classy, m.price_range
                        FROM posts p
                        JOIN metadata m ON p.id = m.post_id
                        WHERE p.id = %s
                    """, (post['post_id'],))
                    
                    post_details = cursor.fetchone()
                    if post_details:
                        caption = post_details['caption']
                        location = post_details['location']
                        cuisine = post_details['cuisine_type']
                        romantic = bool(post_details['romantic'])
                        kids = bool(post_details['good_for_kids'])
                        classy = bool(post_details['classy'])
                        price = post_details['price_range']
                        
                        print(f"   ✅ Liked: {cuisine} in {location}")
                        print(f"      📝 \"{caption[:50]}...\"")
                        print(f"      🏷️ Romantic: {romantic} | Kids: {kids} | Classy: {classy} | Price: ${price}")
                    
                    liked_posts.append(post)
                    
                except Exception as e:
                    print(f"   ❌ Error liking post {post['post_id']}: {e}")
        
        conn.commit()
        cursor.close()
        conn.close()
        
        print(f"✅ Successfully simulated {len(liked_posts)} likes")
        return liked_posts
    
    def analyze_learned_preferences(self):
        """Analyze what the system learned from user likes"""
        print(f"\n🧠 Analyzing learned preferences for user {self.test_user_id}...")
        
        metadata_preferences = self.recommendation_system.analyze_user_metadata_preferences(self.test_user_id)
        
        if not metadata_preferences:
            print("❌ No preferences learned (not enough likes)")
            return None
        
        print(f"\n📊 LEARNED METADATA PREFERENCES:")
        print(f"   Calm places: {metadata_preferences.get('calm_preference', 0):.2f}")
        print(f"   Noisy places: {metadata_preferences.get('noisy_preference', 0):.2f}")
        print(f"   Romantic places: {metadata_preferences.get('romantic_preference', 0):.2f}")
        print(f"   Good for kids: {metadata_preferences.get('good_for_kids_preference', 0):.2f}")
        print(f"   Classy places: {metadata_preferences.get('classy_preference', 0):.2f}")
        print(f"   Casual places: {metadata_preferences.get('casual_preference', 0):.2f}")
        print(f"   Family-friendly: {metadata_preferences.get('family_friendly_preference', 0):.2f}")
        
        print(f"\n🍽️ PREFERRED CUISINES:")
        for cuisine, count in list(metadata_preferences.get('preferred_cuisines', {}).items())[:5]:
            print(f"   {cuisine}: {count} likes")
        
        print(f"\n💰 PREFERRED PRICE RANGES:")
        for price, count in list(metadata_preferences.get('preferred_price_ranges', {}).items())[:3]:
            print(f"   ${price}: {count} likes")
        
        print(f"\n📍 PREFERRED LOCATIONS:")
        for location, count in list(metadata_preferences.get('preferred_locations', {}).items())[:3]:
            print(f"   {location}: {count} likes")
        
        return metadata_preferences
    
    def test_business_recommendations(self, metadata_preferences):
        """Test how business recommendations are affected by learned preferences"""
        print(f"\n🏪 Testing business recommendation improvements...")
        
        # Get sample businesses
        conn = psycopg2.connect(**DB_CONFIG)
        cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        
        cursor.execute("""
            SELECT * FROM businesses 
            WHERE name IS NOT NULL AND name != ''
            ORDER BY RANDOM()
            LIMIT 20
        """)
        
        businesses = [dict(row) for row in cursor.fetchall()]
        cursor.close()
        conn.close()
        
        if not businesses:
            print("❌ No businesses found in database")
            return
        
        print(f"\n📈 BUSINESS COMPATIBILITY SCORES:")
        print("=" * 80)
        
        scored_businesses = []
        for business in businesses:
            compatibility_score = self.recommendation_system.calculate_metadata_compatibility_score(
                business, metadata_preferences
            )
            scored_businesses.append((business, compatibility_score))
        
        # Sort by compatibility score
        scored_businesses.sort(key=lambda x: x[1], reverse=True)
        
        print(f"{'Rank':<4} {'Business Name':<30} {'Cuisine':<12} {'Score':<6} {'Reasons'}")
        print("-" * 80)
        
        for i, (business, score) in enumerate(scored_businesses[:10], 1):
            business_metadata = self.recommendation_system.map_business_to_metadata_format(business)
            
            reasons = []
            if business_metadata['romantic'] and metadata_preferences.get('romantic_preference', 0) > 0.5:
                reasons.append("Romantic")
            if business_metadata['good_for_kids'] and metadata_preferences.get('good_for_kids_preference', 0) > 0.5:
                reasons.append("Kid-friendly")
            if business_metadata['classy'] and metadata_preferences.get('classy_preference', 0) > 0.5:
                reasons.append("Classy")
            if business_metadata['cuisine_type'] in metadata_preferences.get('preferred_cuisines', {}):
                reasons.append(f"Cuisine:{business_metadata['cuisine_type']}")
            
            reasons_str = ", ".join(reasons[:2]) if reasons else "General match"
            
            print(f"{i:<4} {business['name'][:30]:<30} {business.get('fake_cuisine', 'N/A')[:12]:<12} "
                  f"{score:.3f}:<6 {reasons_str}")
        
        return scored_businesses
    
    def compare_recommendations_before_after(self):
        """Compare recommendations before and after learning"""
        print(f"\n🔄 COMPARING RECOMMENDATIONS BEFORE/AFTER LEARNING:")
        print("=" * 70)
        
        # Test with empty preferences (before learning)
        empty_prefs = {}
        
        # Get sample businesses
        conn = psycopg2.connect(**DB_CONFIG)
        cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        
        cursor.execute("""
            SELECT * FROM businesses 
            WHERE name IS NOT NULL AND name != ''
            ORDER BY RANDOM()
            LIMIT 10
        """)
        
        businesses = [dict(row) for row in cursor.fetchall()]
        cursor.close()
        conn.close()
        
        if not businesses:
            print("❌ No businesses found")
            return
        
        print(f"\nBEFORE LEARNING (random/default scoring):")
        for i, business in enumerate(businesses[:5], 1):
            score_before = self.recommendation_system.calculate_metadata_compatibility_score(business, empty_prefs)
            print(f"  {i}. {business['name'][:40]} - Score: {score_before:.3f}")
        
        # After learning
        metadata_preferences = self.recommendation_system.analyze_user_metadata_preferences(self.test_user_id)
        
        if metadata_preferences:
            print(f"\nAFTER LEARNING (personalized scoring):")
            scored_after = []
            for business in businesses:
                score_after = self.recommendation_system.calculate_metadata_compatibility_score(business, metadata_preferences)
                scored_after.append((business, score_after))
            
            scored_after.sort(key=lambda x: x[1], reverse=True)
            
            for i, (business, score) in enumerate(scored_after[:5], 1):
                print(f"  {i}. {business['name'][:40]} - Score: {score:.3f}")
        
    def run_comprehensive_test(self, profile="romantic_foodie"):
        """Run the complete test suite"""
        print("🚀 STARTING COMPREHENSIVE METADATA LEARNING TEST")
        print("=" * 60)
        
        # Step 1: Setup
        self.setup_test_environment()
        
        # Step 2: Simulate user behavior
        preference_function = self.simulate_user_preferences(profile)
        liked_posts = self.simulate_user_likes(preference_function, num_likes=12)
        
        # Step 3: Analyze learning
        metadata_preferences = self.analyze_learned_preferences()
        
        if metadata_preferences:
            # Step 4: Test recommendations
            self.test_business_recommendations(metadata_preferences)
            
            # Step 5: Before/after comparison
            self.compare_recommendations_before_after()
        
        # Step 6: Summary
        self.print_test_summary(liked_posts, metadata_preferences)
    
    def print_test_summary(self, liked_posts, metadata_preferences):
        """Print a comprehensive test summary"""
        print(f"\n📋 TEST SUMMARY")
        print("=" * 50)
        print(f"Test User ID: {self.test_user_id}")
        print(f"Posts liked: {len(liked_posts)}")
        print(f"Learning successful: {'✅ Yes' if metadata_preferences else '❌ No'}")
        
        if metadata_preferences:
            # Find strongest preferences
            strongest_prefs = []
            for pref_key in ['calm_preference', 'romantic_preference', 'good_for_kids_preference', 'classy_preference']:
                value = metadata_preferences.get(pref_key, 0)
                if value > 0.5:
                    strongest_prefs.append(f"{pref_key.replace('_preference', '').title()}: {value:.2f}")
            
            print(f"Strongest learned preferences: {', '.join(strongest_prefs) if strongest_prefs else 'None strong'}")
            
            top_cuisine = list(metadata_preferences.get('preferred_cuisines', {}).keys())
            print(f"Preferred cuisines: {', '.join(top_cuisine[:3]) if top_cuisine else 'None identified'}")
        
        print(f"\n✅ Test completed successfully!")
        print(f"💡 The system can now provide personalized recommendations based on user's liked posts!")

def main():
    """Run different test scenarios"""
    tester = MetadataLearningTester()
    
    # Test different user profiles
    profiles_to_test = ["romantic_foodie", "family_oriented", "young_social", "quiet_contemplative"]
    
    for profile in profiles_to_test:
        print(f"\n{'='*80}")
        print(f"TESTING PROFILE: {profile.upper()}")
        print(f"{'='*80}")
        
        tester.test_user_id = str(uuid.uuid4())  # New user for each test
        tester.run_comprehensive_test(profile)
        
        print(f"\n⏸️  Press Enter to continue to next profile test...")
        input()

if __name__ == "__main__":
    main() 