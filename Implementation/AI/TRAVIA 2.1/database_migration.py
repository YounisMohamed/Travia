"""
Database Migration Script for TRAVIA v2.0 - Supabase Migration
================================================================

This script verifies and validates the new Supabase database schema
with the updated businesses table structure (dataset1).

Key Changes:
- Uses locality/region instead of city/state  
- Uses cuisines instead of fake_cuisine
- Uses has_delivery instead of restaurants_delivery
- Uses has_wifi instead of wifi
- Added new fields: phone, website, photos, payment_options, serves_beer

IMPORTANT: This script assumes the data has already been migrated from 
dataset2 to dataset1 structure in Supabase. This script only validates
the new structure and tests connectivity.
"""

import asyncio
import asyncpg
import json
import logging
from datetime import datetime

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Supabase connection string
DATABASE_URL = "postgresql://postgres.cqcsgwlskhuylgbqegnz:traviaSupabase@aws-0-eu-central-1.pooler.supabase.com:5432/postgres"

async def verify_database_schema():
    """Verify that the new database schema is properly set up"""
    
    connection = None
    try:
        # Connect to Supabase
        connection = await asyncpg.connect(DATABASE_URL)
        logger.info("✅ Successfully connected to Supabase database")
        
        # Test 1: Verify businesses table structure
        logger.info("🔍 Verifying businesses table structure...")
        
        # Check if the new columns exist
        check_columns_query = """
        SELECT column_name, data_type 
        FROM information_schema.columns 
        WHERE table_name = 'businesses' 
        AND column_name IN (
            'locality', 'region', 'country', 'categories', 'primary_category',
            'phone', 'website', 'photos', 'payment_options', 'serves_beer',
            'has_delivery', 'has_wifi', 'cuisines'
        )
        ORDER BY column_name;
        """
        
        columns = await connection.fetch(check_columns_query)
        
        expected_columns = {
            'categories', 'country', 'cuisines', 'has_delivery', 'has_wifi',
            'locality', 'payment_options', 'phone', 'photos', 'primary_category',
            'region', 'serves_beer', 'website'
        }
        
        found_columns = {row['column_name'] for row in columns}
        
        logger.info(f"Found columns: {sorted(found_columns)}")
        
        missing_columns = expected_columns - found_columns
        if missing_columns:
            logger.error(f"❌ Missing required columns: {missing_columns}")
            return False
        else:
            logger.info("✅ All required new columns are present")
        
        # Test 2: Check data availability
        logger.info("🔍 Checking data availability...")
        
        data_check_query = """
        SELECT 
            COUNT(*) as total_businesses,
            COUNT(CASE WHEN locality IS NOT NULL THEN 1 END) as with_locality,
            COUNT(CASE WHEN region IS NOT NULL THEN 1 END) as with_region,
            COUNT(CASE WHEN cuisines IS NOT NULL THEN 1 END) as with_cuisines,
            COUNT(CASE WHEN categories IS NOT NULL THEN 1 END) as with_categories
        FROM businesses;
        """
        
        stats = await connection.fetchrow(data_check_query)
        
        logger.info(f"📊 Database Statistics:")
        logger.info(f"   Total businesses: {stats['total_businesses']:,}")
        logger.info(f"   With locality: {stats['with_locality']:,}")
        logger.info(f"   With region: {stats['with_region']:,}")
        logger.info(f"   With cuisines: {stats['with_cuisines']:,}")
        logger.info(f"   With categories: {stats['with_categories']:,}")
        
        if stats['total_businesses'] == 0:
            logger.error("❌ No businesses found in database")
            return False
        
        # Test 3: Sample data structure validation
        logger.info("🔍 Validating sample data structure...")
        
        sample_query = """
        SELECT id, name, locality, region, country, cuisines, categories, 
               primary_category, has_delivery, has_wifi, serves_beer
        FROM businesses 
        WHERE locality IS NOT NULL AND region IS NOT NULL
        LIMIT 5;
        """
        
        samples = await connection.fetch(sample_query)
        
        for i, sample in enumerate(samples, 1):
            logger.info(f"📋 Sample business {i}:")
            logger.info(f"   ID: {sample['id']}")
            logger.info(f"   Name: {sample['name']}")
            logger.info(f"   Location: {sample['locality']}, {sample['region']}, {sample['country']}")
            logger.info(f"   Primary Category: {sample['primary_category']}")
            
            # Parse JSON fields if they exist
            cuisines = sample['cuisines']
            if cuisines:
                try:
                    if isinstance(cuisines, str):
                        cuisines_parsed = json.loads(cuisines)
                        logger.info(f"   Cuisines: {cuisines_parsed}")
                    else:
                        logger.info(f"   Cuisines: {cuisines}")
                except:
                    logger.info(f"   Cuisines (raw): {cuisines}")
            
            categories = sample['categories']
            if categories:
                try:
                    if isinstance(categories, str):
                        categories_parsed = json.loads(categories)
                        logger.info(f"   Categories: {categories_parsed}")
                    else:
                        logger.info(f"   Categories: {categories}")
                except:
                    logger.info(f"   Categories (raw): {categories}")
            
            logger.info(f"   Has Delivery: {sample['has_delivery']}")
            logger.info(f"   Has WiFi: {sample['has_wifi']}")
            logger.info(f"   Serves Beer: {sample['serves_beer']}")
            logger.info("   " + "-" * 50)
        
        # Test 4: Verify location coverage
        logger.info("🔍 Checking location coverage...")
        
        location_query = """
        SELECT locality, region, country, COUNT(*) as business_count
        FROM businesses
        WHERE locality IS NOT NULL AND region IS NOT NULL
        GROUP BY locality, region, country
        ORDER BY business_count DESC
        LIMIT 10;
        """
        
        locations = await connection.fetch(location_query)
        
        logger.info("🌍 Top 10 locations by business count:")
        for loc in locations:
            logger.info(f"   {loc['locality']}, {loc['region']}, {loc['country']}: {loc['business_count']:,} businesses")
        
        # Test 5: Verify other required tables
        logger.info("🔍 Checking other required tables...")
        
        required_tables = ['users', 'user_preferences', 'user_interactions', 'posts', 'likes', 'metadata']
        
        for table in required_tables:
            count_query = f"SELECT COUNT(*) as count FROM {table};"
            try:
                result = await connection.fetchval(count_query)
                logger.info(f"   Table '{table}': {result:,} records")
            except Exception as e:
                logger.warning(f"   Table '{table}': Error - {e}")
        
        logger.info("✅ Database schema verification completed successfully!")
        return True
        
    except Exception as e:
        logger.error(f"❌ Database verification failed: {e}")
        return False
        
    finally:
        if connection:
            await connection.close()
            logger.info("🔐 Database connection closed")

async def test_api_compatibility():
    """Test that the new schema works with our API queries"""
    
    connection = None
    try:
        connection = await asyncpg.connect(DATABASE_URL)
        logger.info("🧪 Testing API compatibility...")
        
        # Test location query (used by /locations endpoint)
        location_test_query = """
        SELECT locality, region, country, COUNT(*) as business_count
        FROM businesses
        WHERE locality IS NOT NULL AND region IS NOT NULL
        AND name IS NOT NULL AND name != ''
        GROUP BY locality, region, country
        HAVING COUNT(*) >= 10
        ORDER BY business_count DESC, locality ASC
        LIMIT 5;
        """
        
        locations = await connection.fetch(location_test_query)
        logger.info(f"✅ Location query test: Found {len(locations)} valid locations")
        
        if locations:
            # Test business query for a specific location
            test_location = locations[0]
            business_test_query = """
            SELECT id, name, locality, region, country, stars, review_count, price_range,
                   primary_category, categories, cuisines, phone, website, photos,
                   payment_options, serves_beer, has_delivery, has_wifi,
                   good_for_breakfast, good_for_lunch, good_for_dinner, good_for_dessert,
                   ambience_classy, ambience_casual, ambience_romantic, ambience_touristy,
                   good_for_kids
            FROM businesses 
            WHERE locality = $1 AND region = $2
            AND (stars >= 3.0 OR stars IS NULL)
            AND name IS NOT NULL AND name != ''
            ORDER BY stars DESC NULLS LAST, review_count DESC
            LIMIT 10;
            """
            
            businesses = await connection.fetch(
                business_test_query, 
                test_location['locality'], 
                test_location['region']
            )
            
            logger.info(f"✅ Business query test: Found {len(businesses)} businesses for {test_location['locality']}, {test_location['region']}")
            
            if businesses:
                sample_business = businesses[0]
                logger.info(f"   Sample business: {sample_business['name']}")
                logger.info(f"   Stars: {sample_business['stars']}")
                logger.info(f"   Categories: {sample_business['categories']}")
                logger.info(f"   Cuisines: {sample_business['cuisines']}")
        
        logger.info("✅ API compatibility tests passed!")
        return True
        
    except Exception as e:
        logger.error(f"❌ API compatibility test failed: {e}")
        return False
        
    finally:
        if connection:
            await connection.close()

async def main():
    """Main migration verification function"""
    
    logger.info("=" * 80)
    logger.info("TRAVIA v2.0 - Supabase Database Migration Verification")
    logger.info("=" * 80)
    logger.info("")
    
    # Step 1: Verify schema
    schema_ok = await verify_database_schema()
    
    if not schema_ok:
        logger.error("❌ Schema verification failed. Please check your database setup.")
        return False
    
    logger.info("")
    logger.info("-" * 80)
    logger.info("")
    
    # Step 2: Test API compatibility
    api_ok = await test_api_compatibility()
    
    if not api_ok:
        logger.error("❌ API compatibility test failed.")
        return False
    
    logger.info("")
    logger.info("=" * 80)
    logger.info("🎉 MIGRATION VERIFICATION COMPLETED SUCCESSFULLY!")
    logger.info("=" * 80)
    logger.info("")
    logger.info("Your Supabase database is ready for TRAVIA v2.0 FastAPI backend!")
    logger.info("")
    logger.info("Next steps:")
    logger.info("1. Install dependencies: pip install -r requirements.txt")
    logger.info("2. Start FastAPI server: uvicorn main:app --reload")
    logger.info("3. Access API docs at: http://localhost:8000/docs")
    logger.info("4. Begin Flutter integration using flutter_integration.md")
    logger.info("")
    
    return True

if __name__ == "__main__":
    asyncio.run(main()) 