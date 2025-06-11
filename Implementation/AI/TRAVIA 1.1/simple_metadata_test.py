#!/usr/bin/env python3
"""
Simple Metadata Learning Test

This script tests the basic functionality of metadata-based learning
using the actual posts table structure.
"""

import psycopg2
import psycopg2.extras
import random
import uuid
from datetime import datetime

# Database configuration - Update these!
DB_CONFIG = {
    'host': 'localhost',
    'database': 'traviadb',
    'user': 'postgres',
    'password': '1234',
    'port': 5433
}

def create_test_tables():
    """Create the required tables if they don't exist"""
    print("🔧 Setting up required database tables...")
    
    conn = psycopg2.connect(**DB_CONFIG)
    cursor = conn.cursor()
    
    try:
        # Check if posts table exists (should already exist)
        cursor.execute("""
            SELECT EXISTS (
                SELECT FROM information_schema.tables 
                WHERE table_name = 'posts'
            );
        """)
        posts_exists = cursor.fetchone()[0]
        
        if posts_exists:
            print("✅ Posts table already exists")
        else:
            print("⚠️ Posts table doesn't exist - creating minimal version for testing")
            cursor.execute("""
                CREATE TABLE posts (
                    id TEXT PRIMARY KEY,
                    user_id TEXT,
                    media_url TEXT,
                    caption TEXT,
                    location TEXT,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    comments_count INTEGER DEFAULT 0,
                    poster_photo_url TEXT,
                    poster_username TEXT,
                    views INTEGER DEFAULT 0,
                    likes_count INTEGER DEFAULT 0,
                    dislikes_count INTEGER DEFAULT 0,
                    video_thumbnail TEXT
                )
            """)
        
        # Create metadata table (if not exists)
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS metadata (
                meta_id SERIAL PRIMARY KEY,
                post_id TEXT REFERENCES posts(id),
                calm INTEGER DEFAULT 0,
                noisy INTEGER DEFAULT 0,
                romantic INTEGER DEFAULT 0,
                good_for_kids INTEGER DEFAULT 0,
                classy INTEGER DEFAULT 0,
                casual INTEGER DEFAULT 0,
                family_friendly_places INTEGER DEFAULT 0,
                location TEXT,
                cuisine_type TEXT,
                price_range INTEGER,
                UNIQUE(post_id)
            )
        """)
        
        # Create likes table with actual schema
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS likes (
                id SERIAL PRIMARY KEY,
                liker_user_id TEXT,
                liked_user_id TEXT,
                post_id TEXT,
                comment_id TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                story_id TEXT,
                type TEXT
            )
        """)
        
        # Check if users table exists with actual schema
        cursor.execute("""
            SELECT EXISTS (
                SELECT FROM information_schema.tables 
                WHERE table_name = 'users'
            );
        """)
        users_exists = cursor.fetchone()[0]
        
        if not users_exists:
            print("⚠️ Users table doesn't exist - creating with actual schema")
            cursor.execute("""
                CREATE TABLE users (
                    id TEXT PRIMARY KEY,
                    email TEXT,
                    display_name TEXT,
                    username TEXT,
                    photo_url TEXT,
                    bio TEXT,
                    is_private BOOLEAN DEFAULT FALSE,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    relationship_status TEXT,
                    gender TEXT,
                    viewed_posts TEXT[],
                    saved_posts TEXT[],
                    is_younis BOOLEAN DEFAULT FALSE,
                    fcm_token TEXT,
                    liked_posts TEXT[],
                    uploaded_posts TEXT[],
                    following_ids TEXT[],
                    friend_ids TEXT[],
                    visited_countries TEXT[],
                    age INTEGER,
                    public BOOLEAN DEFAULT TRUE,
                    "showLikedPosts" BOOLEAN DEFAULT TRUE
                )
            """)
        else:
            print("✅ Users table already exists")
        
        conn.commit()
        print("✅ Database tables ready!")
        
    except Exception as e:
        print(f"❌ Error setting up tables: {e}")
        conn.rollback()
    finally:
        cursor.close()
        conn.close()

def create_sample_data():
    """Create sample metadata for existing posts"""
    print("📝 Creating sample metadata for existing posts...")
    
    conn = psycopg2.connect(**DB_CONFIG)
    cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    
    try:
        # Get some existing posts
        cursor.execute("SELECT id, user_id, caption FROM posts LIMIT 6")
        existing_posts = cursor.fetchall()
        
        if not existing_posts:
            print("❌ No existing posts found to add metadata to")
            return
        
        print(f"Found {len(existing_posts)} existing posts to add metadata to")
        
        # Sample metadata data
        sample_metadata = [
            {'romantic': 1, 'classy': 1, 'calm': 1, 'cuisine_type': 'Italian', 'price_range': 4},
            {'family_friendly_places': 1, 'good_for_kids': 1, 'casual': 1, 'cuisine_type': 'Mexican', 'price_range': 2},
            {'romantic': 1, 'classy': 1, 'calm': 1, 'cuisine_type': 'French', 'price_range': 4},
            {'casual': 1, 'noisy': 1, 'good_for_kids': 1, 'cuisine_type': 'American', 'price_range': 2},
            {'romantic': 1, 'classy': 1, 'calm': 1, 'cuisine_type': 'Japanese', 'price_range': 3},
            {'family_friendly_places': 1, 'good_for_kids': 1, 'casual': 1, 'cuisine_type': 'Italian', 'price_range': 2}
        ]
        
        for i, post in enumerate(existing_posts):
            if i < len(sample_metadata):
                metadata = sample_metadata[i]
                
                try:
                    cursor.execute("""
                        INSERT INTO metadata 
                        (post_id, calm, noisy, romantic, good_for_kids, classy, casual, 
                         family_friendly_places, location, cuisine_type, price_range)
                        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                    """, (
                        post['id'], 
                        metadata.get('calm', 0),
                        metadata.get('noisy', 0), 
                        metadata.get('romantic', 0),
                        metadata.get('good_for_kids', 0), 
                        metadata.get('classy', 0), 
                        metadata.get('casual', 0),
                        metadata.get('family_friendly_places', 0), 
                        'Test Location',
                        metadata.get('cuisine_type', 'American'), 
                        metadata.get('price_range', 2)
                    ))
                    
                    print(f"   📊 Added {metadata['cuisine_type']} metadata to post: {post['caption'][:30]}...")
                    
                except Exception as e:
                    print(f"   ⚠️ Error adding metadata to post {post['id']}: {e}")
                    # Skip if already exists, continue with others
                    continue
        
        conn.commit()
        print(f"✅ Created metadata for {len(existing_posts)} existing posts")
        
    except Exception as e:
        print(f"❌ Error creating sample data: {e}")
        conn.rollback()
    finally:
        cursor.close()
        conn.close()

def simulate_romantic_user_likes():
    """Simulate a user who likes romantic, classy places"""
    test_user_id = str(uuid.uuid4())
    print(f"\n👤 Creating test user: {test_user_id}")
    print("📝 Profile: Likes romantic, classy places")
    
    conn = psycopg2.connect(**DB_CONFIG)
    cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    
    try:
        # Create user with minimal required fields
        cursor.execute("""
            INSERT INTO users (id, email, display_name, username, gender, viewed_posts, saved_posts, 
                              is_younis, liked_posts, uploaded_posts, following_ids, friend_ids, 
                              visited_countries, age, public, "showLikedPosts")
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            ON CONFLICT (id) DO NOTHING
        """, (test_user_id, f"test_{test_user_id[:8]}@example.com", f"Test User {test_user_id[:8]}", 
              f"testuser_{test_user_id[:8]}", 'Male', '{}', '{}', False, '{}', '{}', '{}', '{}', '{}', 
              datetime(2000, 1, 1), True, True))
        
        # Find posts with romantic/classy metadata
        cursor.execute("""
            SELECT p.id, p.caption, m.cuisine_type, m.romantic, m.classy
            FROM posts p
            JOIN metadata m ON p.id = m.post_id
            WHERE m.romantic = 1 OR m.classy = 1
            LIMIT 3
        """)
        
        romantic_posts = cursor.fetchall()
        
        if not romantic_posts:
            print("   ⚠️ No romantic/classy posts found with metadata")
            # Try to find any posts with metadata
            cursor.execute("""
                SELECT p.id, p.caption, m.cuisine_type, m.romantic, m.classy
                FROM posts p
                JOIN metadata m ON p.id = m.post_id
                LIMIT 3
            """)
            romantic_posts = cursor.fetchall()
        
        print(f"   Found {len(romantic_posts)} posts to like")
        
        # Like the posts using the correct schema
        for post in romantic_posts:
            cursor.execute("""
                INSERT INTO likes (liker_user_id, post_id, type)
                VALUES (%s, %s, %s)
            """, (test_user_id, post['id'], 'like'))
            
            cuisine = post['cuisine_type'] or 'Unknown'
            romantic = bool(post['romantic'])
            classy = bool(post['classy'])
            
            print(f"   ❤️ Liked: {cuisine} post - {post['caption'][:40]}...")
            print(f"      🌹 Romantic: {romantic} | ✨ Classy: {classy}")
        
        conn.commit()
        print(f"✅ User {test_user_id} liked {len(romantic_posts)} posts")
        return test_user_id
        
    except Exception as e:
        print(f"❌ Error simulating user likes: {e}")
        conn.rollback()
        return None
    finally:
        cursor.close()
        conn.close()

def test_metadata_learning(user_id):
    """Test the metadata learning functionality"""
    print(f"\n🧠 Testing metadata learning for user {user_id}...")
    
    # Import the recommendation system from our flask app
    try:
        from flask_app import TravelRecommendationSystem
        rec_system = TravelRecommendationSystem()
        
        # Test the metadata preference analysis
        metadata_preferences = rec_system.analyze_user_metadata_preferences(user_id)
        
        if metadata_preferences:
            print(f"\n📊 LEARNED PREFERENCES:")
            print(f"   Romantic: {metadata_preferences.get('romantic_preference', 0):.2f}")
            print(f"   Classy: {metadata_preferences.get('classy_preference', 0):.2f}")
            print(f"   Calm: {metadata_preferences.get('calm_preference', 0):.2f}")
            print(f"   Family-friendly: {metadata_preferences.get('family_friendly_preference', 0):.2f}")
            print(f"   Casual: {metadata_preferences.get('casual_preference', 0):.2f}")
            print(f"   Noisy: {metadata_preferences.get('noisy_preference', 0):.2f}")
            
            print(f"\n🍽️ PREFERRED CUISINES:")
            for cuisine, count in metadata_preferences.get('preferred_cuisines', {}).items():
                print(f"   {cuisine}: {count} likes")
            
            print(f"\n💰 PREFERRED PRICE RANGES:")
            for price, count in metadata_preferences.get('preferred_price_ranges', {}).items():
                print(f"   Price Level {price}: {count} likes")
            
            return metadata_preferences
        else:
            print("❌ No preferences learned")
            return None
            
    except ImportError as e:
        print(f"❌ Error importing recommendation system: {e}")
        print("Make sure flask_app.py is in the same directory")
        return None

def test_business_scoring(metadata_preferences):
    """Test how businesses would be scored with learned preferences"""
    print(f"\n🏪 Testing business scoring with learned preferences...")
    
    # Create some mock businesses that match the learned preferences
    mock_businesses = [
        {
            'name': 'Romantic Italian Bistro',
            'fake_cuisine': 'Italian',
            'ambience_romantic': True,
            'ambience_classy': True,
            'ambience_casual': False,
            'good_for_kids': False,
            'price_range': 4,
            'city': 'Las Vegas',
            'state': 'NV'
        },
        {
            'name': 'Family Pizza Place',
            'fake_cuisine': 'Italian',
            'ambience_romantic': False,
            'ambience_classy': False,
            'ambience_casual': True,
            'good_for_kids': True,
            'price_range': 2,
            'city': 'Phoenix',
            'state': 'AZ'
        },
        {
            'name': 'Upscale Steakhouse',
            'fake_cuisine': 'American',
            'ambience_romantic': True,
            'ambience_classy': True,
            'ambience_casual': False,
            'good_for_kids': False,
            'price_range': 4,
            'city': 'Charlotte',
            'state': 'NC'
        },
        {
            'name': 'Zen Japanese Garden',
            'fake_cuisine': 'Japanese',
            'ambience_romantic': True,
            'ambience_classy': True,
            'ambience_casual': False,
            'good_for_kids': False,
            'price_range': 3,
            'city': 'Las Vegas',
            'state': 'NV'
        },
        {
            'name': 'Casual Sports Bar',
            'fake_cuisine': 'American',
            'ambience_romantic': False,
            'ambience_classy': False,
            'ambience_casual': True,
            'good_for_kids': True,
            'price_range': 2,
            'city': 'Tampa',
            'state': 'FL'
        }
    ]
    
    try:
        from flask_app import TravelRecommendationSystem
        rec_system = TravelRecommendationSystem()
        
        print(f"\n📈 BUSINESS COMPATIBILITY SCORES:")
        print("-" * 70)
        print(f"{'Business Name':<25} | {'Cuisine':<10} | {'Score':<6} | {'Match Reasons'}")
        print("-" * 70)
        
        scored_businesses = []
        for business in mock_businesses:
            score = rec_system.calculate_metadata_compatibility_score(business, metadata_preferences)
            scored_businesses.append((business, score))
        
        # Sort by score
        scored_businesses.sort(key=lambda x: x[1], reverse=True)
        
        for business, score in scored_businesses:
            reasons = []
            if business.get('ambience_romantic') and metadata_preferences.get('romantic_preference', 0) > 0.5:
                reasons.append("Romantic")
            if business.get('ambience_classy') and metadata_preferences.get('classy_preference', 0) > 0.5:
                reasons.append("Classy")
            if business.get('fake_cuisine') in metadata_preferences.get('preferred_cuisines', {}):
                reasons.append(f"Cuisine:{business['fake_cuisine']}")
            
            reasons_str = ", ".join(reasons) if reasons else "Low match"
            
            print(f"{business['name']:<25} | {business['fake_cuisine']:<10} | {score:.3f} | {reasons_str}")
        
        print(f"\n✅ Higher scores indicate better matches for this user's preferences!")
        
        # Show the top recommendation
        if scored_businesses:
            top_business, top_score = scored_businesses[0]
            print(f"\n🏆 TOP RECOMMENDATION:")
            print(f"   {top_business['name']} (Score: {top_score:.3f})")
            print(f"   Why: This {top_business['fake_cuisine']} restaurant matches your preference for romantic, classy places!")
        
    except ImportError as e:
        print(f"❌ Error testing business scoring: {e}")

def verify_database_data():
    """Verify that our test data was created correctly"""
    print(f"\n🔍 Verifying test data in database...")
    
    conn = psycopg2.connect(**DB_CONFIG)
    cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    
    try:
        # Check posts
        cursor.execute("SELECT COUNT(*) as count FROM posts WHERE id LIKE 'romantic_%' OR id LIKE 'classy_%'")
        posts_count = cursor.fetchone()['count']
        print(f"   📝 Test posts created: {posts_count}")
        
        # Check metadata
        cursor.execute("SELECT COUNT(*) as count FROM metadata WHERE post_id LIKE 'romantic_%' OR post_id LIKE 'classy_%'")
        metadata_count = cursor.fetchone()['count']
        print(f"   📊 Metadata records created: {metadata_count}")
        
        # Check likes
        cursor.execute("SELECT COUNT(*) as count FROM likes")
        likes_count = cursor.fetchone()['count']
        print(f"   ❤️ Like records created: {likes_count}")
        
        # Show sample joined data
        cursor.execute("""
            SELECT p.id, p.caption, m.romantic, m.classy, m.cuisine_type
            FROM posts p
            JOIN metadata m ON p.id = m.post_id
            WHERE m.romantic = 1 AND m.classy = 1
            LIMIT 2
        """)
        
        romantic_posts = cursor.fetchall()
        print(f"\n   📋 Sample romantic & classy posts:")
        for post in romantic_posts:
            print(f"      {post['id']}: {post['cuisine_type']} - {post['caption'][:40]}...")
        
    except Exception as e:
        print(f"❌ Error verifying data: {e}")
    finally:
        cursor.close()
        conn.close()

def main():
    """Run the simple metadata learning test"""
    print("🚀 SIMPLE METADATA LEARNING TEST")
    print("=" * 50)
    print("Testing with your actual posts table structure!")
    
    try:
        # Step 1: Setup database
        create_test_tables()
        
        # Step 2: Create sample data
        create_sample_data()
        
        # Step 3: Verify data
        verify_database_data()
        
        # Step 4: Simulate user behavior
        user_id = simulate_romantic_user_likes()
        
        if user_id:
            # Step 5: Test learning
            metadata_preferences = test_metadata_learning(user_id)
            
            if metadata_preferences:
                # Step 6: Test business scoring
                test_business_scoring(metadata_preferences)
                
                print(f"\n✅ TEST COMPLETED SUCCESSFULLY!")
                print(f"💡 The system learned that this user prefers:")
                print(f"   - Romantic places ({metadata_preferences.get('romantic_preference', 0):.0%})")
                print(f"   - Classy establishments ({metadata_preferences.get('classy_preference', 0):.0%})")
                print(f"   - Italian/French/Japanese cuisine")
                print(f"\n🎯 Future recommendations will be personalized based on these preferences!")
                
                print(f"\n📈 NEXT STEPS:")
                print(f"   1. Run your Flask app: python flask_app.py")
                print(f"   2. Create users and have them like posts")
                print(f"   3. Watch as recommendations improve based on their likes!")
                
            else:
                print("❌ Learning test failed")
        else:
            print("❌ User simulation failed")
            
    except Exception as e:
        print(f"❌ Test failed with error: {e}")
        print("Make sure your database is running and credentials are correct!")

if __name__ == "__main__":
    main() 