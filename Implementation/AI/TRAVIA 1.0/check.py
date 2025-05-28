import psycopg2

def check_database():
    """Quick check of database contents"""
    
    # Update with your actual credentials
    DB_CONFIG = {
        'host': 'localhost',
        'database': 'traviadb',
        'user': 'postgres', 
        'password': '1234'  # Update this
    }
    
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        cursor = conn.cursor()
        
        # Check businesses count
        cursor.execute("SELECT COUNT(*) FROM businesses;")
        business_count = cursor.fetchone()[0]
        print(f"📊 Businesses in database: {business_count}")
        
        if business_count == 0:
            print("⚠️  No businesses found! You need to run the data migration first.")
            print("Run: python data_migration.py")
            return False
        
        # Check a sample business
        cursor.execute("SELECT name, stars, city FROM businesses LIMIT 3;")
        sample_businesses = cursor.fetchall()
        
        print("\n📍 Sample businesses:")
        for business in sample_businesses:
            print(f"  - {business[0]} ({business[1]} stars) in {business[2]}")
        
        # Check users count
        cursor.execute("SELECT COUNT(*) FROM users;")
        user_count = cursor.fetchone()[0]
        print(f"\n👥 Users in database: {user_count}")
        
        # Check user_preferences count
        cursor.execute("SELECT COUNT(*) FROM user_preferences;")
        prefs_count = cursor.fetchone()[0]
        print(f"⚙️  User preferences saved: {prefs_count}")
        
        cursor.close()
        conn.close()
        
        return True
        
    except Exception as e:
        print(f"❌ Database check failed: {e}")
        return False

if __name__ == "__main__":
    check_database()