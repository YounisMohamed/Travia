#!/usr/bin/env python3
"""
Schema Verification Script

This script verifies that our database schema matches expectations
and tests basic CRUD operations for the metadata learning system.
"""

import psycopg2
import psycopg2.extras
import uuid
from datetime import datetime

# Database configuration
DB_CONFIG = {
    'host': 'localhost',
    'database': 'traviadb',
    'user': 'postgres',
    'password': '1234',
    'port': 5433
}

def check_table_columns(table_name):
    """Check the actual columns in a table"""
    print(f"\n🔍 Checking columns in '{table_name}' table...")
    
    conn = psycopg2.connect(**DB_CONFIG)
    cursor = conn.cursor()
    
    try:
        cursor.execute("""
            SELECT column_name, data_type, is_nullable
            FROM information_schema.columns
            WHERE table_name = %s
            ORDER BY ordinal_position;
        """, (table_name,))
        
        columns = cursor.fetchall()
        
        if columns:
            print(f"✅ Found {len(columns)} columns in '{table_name}':")
            for col_name, data_type, nullable in columns:
                print(f"   - {col_name} ({data_type}) {'NULL' if nullable == 'YES' else 'NOT NULL'}")
        else:
            print(f"❌ Table '{table_name}' not found")
        
        return [col[0] for col in columns]
        
    except Exception as e:
        print(f"❌ Error checking table {table_name}: {e}")
        return []
    finally:
        cursor.close()
        conn.close()

def verify_required_tables():
    """Verify that all required tables exist"""
    print("🏗️ Verifying required tables exist...")
    
    required_tables = ['users', 'posts', 'likes', 'metadata']
    
    conn = psycopg2.connect(**DB_CONFIG)
    cursor = conn.cursor()
    
    existing_tables = []
    missing_tables = []
    
    for table in required_tables:
        try:
            cursor.execute("""
                SELECT EXISTS (
                    SELECT FROM information_schema.tables 
                    WHERE table_name = %s
                );
            """, (table,))
            exists = cursor.fetchone()[0]
            
            if exists:
                existing_tables.append(table)
                print(f"   ✅ {table}")
            else:
                missing_tables.append(table)
                print(f"   ❌ {table} - NOT FOUND")
        except Exception as e:
            print(f"   ❌ Error checking {table}: {e}")
            missing_tables.append(table)
    
    cursor.close()
    conn.close()
    
    return existing_tables, missing_tables

def test_basic_operations():
    """Test basic CRUD operations with the correct schema"""
    print("\n🧪 Testing basic operations...")
    
    conn = psycopg2.connect(**DB_CONFIG)
    cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    
    try:
        # Test 1: Check if we can read existing users
        print("   1. Testing user table access...")
        cursor.execute("SELECT id, email, display_name FROM users LIMIT 1")
        user = cursor.fetchone()
        if user:
            print(f"   ✅ Can read users (found user: {user['display_name']})")
            test_user_id = user['id']
        else:
            print("   ❌ No users found")
            return False
        
        # Test 2: Check if we can read existing posts
        print("   2. Testing post table access...")
        cursor.execute("SELECT id, user_id, caption FROM posts LIMIT 1")
        post = cursor.fetchone()
        if post:
            print(f"   ✅ Can read posts (found post: {post['caption'][:30]}...)")
            test_post_id = post['id']
        else:
            print("   ❌ No posts found")
            return False
        
        # Test 3: Create metadata for existing post (test metadata creation)
        print("   3. Testing metadata creation...")
        test_metadata_id = f"test_meta_{uuid.uuid4().hex[:8]}"
        cursor.execute("""
            INSERT INTO metadata (post_id, romantic, classy, cuisine_type, price_range)
            VALUES (%s, %s, %s, %s, %s)
        """, (test_post_id, 1, 1, 'Italian', 3))
        print("   ✅ Metadata created successfully")
        
        # Test 4: Create a like with correct schema
        print("   4. Testing like creation...")
        test_like_id = f"like_{uuid.uuid4().hex[:8]}"
        cursor.execute("""
            INSERT INTO likes (id, liker_user_id, post_id, type, created_at)
            VALUES (%s, %s, %s, %s, %s)
        """, (test_like_id, test_user_id, test_post_id, 'like', datetime.now()))
        print("   ✅ Like created successfully")
        
        # Test 5: Query liked posts with metadata (the key query for our system)
        print("   5. Testing metadata learning query...")
        cursor.execute("""
            SELECT m.romantic, m.classy, m.cuisine_type, m.price_range,
                   p.caption, p.location
            FROM likes l
            JOIN metadata m ON l.post_id = m.post_id
            JOIN posts p ON l.post_id = p.id
            WHERE l.liker_user_id = %s AND l.type = 'like'
        """, (test_user_id,))
        
        results = cursor.fetchall()
        if results:
            print("   ✅ Metadata learning query successful")
            print(f"      Found {len(results)} liked posts with metadata")
            for result in results[:2]:  # Show first 2 results
                print(f"      Example: {result['cuisine_type']} post, Romantic: {result['romantic']}, Classy: {result['classy']}")
        else:
            print("   ❌ No results from metadata learning query")
        
        # Clean up only our test data
        print("   6. Cleaning up test data...")
        cursor.execute("DELETE FROM likes WHERE id = %s", (test_like_id,))
        cursor.execute("DELETE FROM metadata WHERE post_id = %s AND cuisine_type = 'Italian'", (test_post_id,))
        print("   ✅ Test data cleaned up")
        
        conn.commit()
        print("✅ All basic operations successful!")
        return True
        
    except Exception as e:
        print(f"❌ Error during testing: {e}")
        conn.rollback()
        return False
    finally:
        cursor.close()
        conn.close()

def check_existing_data():
    """Check what data already exists in tables"""
    print("\n📊 Checking existing data...")
    
    conn = psycopg2.connect(**DB_CONFIG)
    cursor = conn.cursor()
    
    tables_to_check = ['users', 'posts', 'likes', 'metadata']
    
    for table in tables_to_check:
        try:
            cursor.execute(f"SELECT COUNT(*) FROM {table}")
            count = cursor.fetchone()[0]
            print(f"   {table}: {count} records")
        except Exception as e:
            print(f"   {table}: Error - {e}")
    
    cursor.close()
    conn.close()

def main():
    """Run schema verification"""
    print("🔍 DATABASE SCHEMA VERIFICATION")
    print("=" * 50)
    
    try:
        # Step 1: Check basic connectivity
        print("🌐 Testing database connection...")
        conn = psycopg2.connect(**DB_CONFIG)
        conn.close()
        print("✅ Database connection successful")
        
        # Step 2: Check tables exist
        existing_tables, missing_tables = verify_required_tables()
        
        if missing_tables:
            print(f"\n⚠️ Missing tables: {missing_tables}")
            print("Run simple_metadata_test.py to create missing tables")
            return
        
        # Step 3: Check table schemas
        for table in ['users', 'posts', 'likes', 'metadata']:
            check_table_columns(table)
        
        # Step 4: Check existing data
        check_existing_data()
        
        # Step 5: Test operations
        if test_basic_operations():
            print(f"\n✅ SCHEMA VERIFICATION SUCCESSFUL!")
            print(f"🎯 Your database is ready for metadata learning tests!")
            print(f"\nNext steps:")
            print(f"   1. Run: python simple_metadata_test.py")
            print(f"   2. Or run: python test_metadata_learning.py")
        else:
            print(f"\n❌ Basic operations failed - check error messages above")
            
    except Exception as e:
        print(f"❌ Schema verification failed: {e}")
        print("Check your database connection and credentials")

if __name__ == "__main__":
    main() 