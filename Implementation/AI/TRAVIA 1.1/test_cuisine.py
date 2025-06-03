#!/usr/bin/env python3
"""
Check how many Italian restaurants are in the FULL database
"""

import psycopg2
import psycopg2.extras

# Database configuration
DB_CONFIG = {
    'host': 'localhost',
    'database': 'traviadb',
    'user': 'postgres',
    'password': '1234',
    'port': 5433
}

def check_full_database():
    """Check the entire database for Italian restaurants"""
    print("🔍 CHECKING FULL DATABASE FOR ITALIAN RESTAURANTS")
    print("=" * 60)
    
    conn = psycopg2.connect(**DB_CONFIG)
    cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    
    # Count total businesses
    cursor.execute("SELECT COUNT(*) as total FROM businesses WHERE name IS NOT NULL AND name != ''")
    total_count = cursor.fetchone()['total']
    print(f"Total businesses in database: {total_count}")
    
    # Find ALL Italian restaurants
    cursor.execute("""
        SELECT name, fake_cuisine, stars, price_range, city, state
        FROM businesses 
        WHERE fake_cuisine = 'Italian'
        AND name IS NOT NULL 
        AND name != ''
        ORDER BY stars DESC NULLS LAST
    """)
    
    italian_restaurants = cursor.fetchall()
    print(f"Italian restaurants found: {len(italian_restaurants)}")
    
    if italian_restaurants:
        print("\n🍝 ALL ITALIAN RESTAURANTS:")
        print("-" * 60)
        for i, restaurant in enumerate(italian_restaurants, 1):
            print(f"{i:2d}. {restaurant['name']:<40} | {restaurant['city']:<15} | ⭐{restaurant['stars'] or 'N/A'}")
    else:
        print("❌ NO ITALIAN RESTAURANTS FOUND IN ENTIRE DATABASE!")
    
    # Check cuisine distribution
    cursor.execute("""
        SELECT fake_cuisine, COUNT(*) as count
        FROM businesses 
        WHERE fake_cuisine IS NOT NULL 
        AND name IS NOT NULL 
        AND name != ''
        GROUP BY fake_cuisine
        ORDER BY count DESC
    """)
    
    cuisine_counts = cursor.fetchall()
    print(f"\n📊 CUISINE DISTRIBUTION (Top 10):")
    print("-" * 60)
    for cuisine in cuisine_counts[:10]:
        percentage = (cuisine['count'] / total_count) * 100
        print(f"{cuisine['fake_cuisine']:<20} | {cuisine['count']:4d} businesses ({percentage:.1f}%)")
    
    cursor.close()
    conn.close()

if __name__ == "__main__":
    check_full_database()