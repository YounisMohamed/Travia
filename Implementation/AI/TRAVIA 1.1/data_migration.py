import pandas as pd
import psycopg2
from psycopg2.extras import execute_values
import json
import re

class BusinessDataMigration:
    def __init__(self, db_connection_string):
        self.conn = psycopg2.connect(db_connection_string)
        self.cursor = self.conn.cursor()
    
    def parse_hours(self, hours_str):
        """Parse hours string like '7:0-20:0' or handle None/empty values"""
        if pd.isna(hours_str) or hours_str == '' or hours_str == 'None':
            return None
        return str(hours_str)
    
    def parse_boolean(self, value):
        """Convert various boolean representations to actual boolean"""
        if pd.isna(value) or value == '' or value == 'None':
            return None
        if isinstance(value, bool):
            return value
        if isinstance(value, str):
            return value.lower() in ['true', '1', 'yes']
        return bool(value)
    
    def parse_cuisine_types(self, cuisine_str):
        """Parse cuisine string and return as array"""
        if pd.isna(cuisine_str) or cuisine_str == '' or cuisine_str == '0':
            return []
        # Split by common separators and clean up
        cuisines = re.split(r'[;,|]', str(cuisine_str))
        return [c.strip() for c in cuisines if c.strip()]
    
    def parse_float_to_boolean(self, value):
        """Convert float values (0.0/1.0) to boolean"""
        if pd.isna(value):
            return None
        return bool(int(value))
    
    def parse_string_to_boolean(self, value):
        """Convert string values to boolean"""
        if pd.isna(value) or value == '' or value == 'None':
            return None
        if isinstance(value, str):
            return value.lower() in ['true', '1', 'yes']
        return bool(value)
    
    def migrate_businesses(self, csv_file_path):
        """Migrate business data from CSV to PostgreSQL"""
        print("Reading CSV file...")
        df = pd.read_csv(csv_file_path)
        
        print(f"Found {len(df)} businesses to migrate")
        print("Dataset columns:", df.columns.tolist())
        
        businesses_data = []
        
        for index, row in df.iterrows():
            try:
                # Handle cuisine types - if it's a float (1.0), it means it's a restaurant
                has_cuisine = not pd.isna(row.get('Restaurants_Cuisines', 0)) and row.get('Restaurants_Cuisines', 0) == 1.0
                cuisine_list = ['Restaurant'] if has_cuisine else []
                
                business_data = (
                    str(row['business_id']),
                    str(row['name']),
                    str(row.get('address', '')),
                    str(row.get('city', '')),
                    str(row.get('state', '')),
                    str(row.get('postal_code', '')),
                    float(row['latitude']) if pd.notna(row['latitude']) else None,
                    float(row['longitude']) if pd.notna(row['longitude']) else None,
                    float(row['stars']) if pd.notna(row['stars']) else None,
                    int(row['review_count']) if pd.notna(row['review_count']) else 0,
                    int(row['attributes_RestaurantsPriceRange2']) if pd.notna(row['attributes_RestaurantsPriceRange2']) else None,
                    self.parse_float_to_boolean(row.get('attributes_GoodForKids')),
                    
                    # Ambience attributes (float values 0.0/1.0)
                    self.parse_float_to_boolean(row.get('attributes_Ambience_touristy')),
                    self.parse_float_to_boolean(row.get('attributes_Ambience_romantic')),
                    self.parse_float_to_boolean(row.get('attributes_Ambience_intimate')),
                    self.parse_float_to_boolean(row.get('attributes_Ambience_trendy')),
                    self.parse_float_to_boolean(row.get('attributes_Ambience_classy')),
                    self.parse_float_to_boolean(row.get('attributes_Ambience_casual')),
                    
                    # Business categories (float values 0.0/1.0)
                    self.parse_float_to_boolean(row.get('Bars_Night')),
                    self.parse_float_to_boolean(row.get('Bars_Night')),  # Using same for nightlife
                    self.parse_float_to_boolean(row.get('Beauty_Health_Care')),
                    self.parse_float_to_boolean(row.get('Cafes')),
                    self.parse_float_to_boolean(row.get('GYM')),
                    self.parse_float_to_boolean(row.get('Restaurants_Cuisines')),
                    self.parse_float_to_boolean(row.get('Shops')),
                    
                    # Cuisine types array
                    cuisine_list,
                    
                    # Restaurant attributes (string values)
                    self.parse_string_to_boolean(row.get('attributes_RestaurantsDelivery')),
                    self.parse_string_to_boolean(row.get('attributes_OutdoorSeating')),
                    self.parse_string_to_boolean(row.get('attributes_BusinessAcceptsCreditCards')),
                    self.parse_string_to_boolean(row.get('attributes_RestaurantsTakeOut')),
                    self.parse_string_to_boolean(row.get('attributes_WiFi')) if row.get('attributes_WiFi') != "u'free'" else True,
                    self.parse_string_to_boolean(row.get('attributes_RestaurantsGoodForGroups')),
                    str(row.get('attributes_RestaurantsAttire', '')),
                    str(row.get('attributes_NoiseLevel', '')),
                    
                    # Good for meal times (string values)
                    self.parse_string_to_boolean(row.get('attributes_GoodForMeal_dessert')),
                    self.parse_string_to_boolean(row.get('attributes_GoodForMeal_latenight')),
                    self.parse_string_to_boolean(row.get('attributes_GoodForMeal_lunch')),
                    self.parse_string_to_boolean(row.get('attributes_GoodForMeal_dinner')),
                    self.parse_string_to_boolean(row.get('attributes_GoodForMeal_brunch')),
                    self.parse_string_to_boolean(row.get('attributes_GoodForMeal_breakfast')),
                    
                    # Hours (string values)
                    self.parse_hours(row.get('hours_Monday')),
                    self.parse_hours(row.get('hours_Tuesday')),
                    self.parse_hours(row.get('hours_Wednesday')),
                    self.parse_hours(row.get('hours_Thursday')),
                    self.parse_hours(row.get('hours_Friday')),
                    self.parse_hours(row.get('hours_Saturday')),
                    self.parse_hours(row.get('hours_Sunday'))
                )
                
                businesses_data.append(business_data)
                
                if len(businesses_data) % 50 == 0:
                    print(f"Processed {len(businesses_data)} businesses...")
                    
            except Exception as e:
                print(f"Error processing row {index}: {e}")
                print(f"Row data: {dict(row)}")
                continue
        
        # Insert data in batches
        insert_query = """
        INSERT INTO businesses (
            business_id, name, address, city, state, postal_code,
            latitude, longitude, stars, review_count, price_range, good_for_kids,
            ambience_touristy, ambience_romantic, ambience_intimate, ambience_trendy,
            ambience_classy, ambience_casual, is_bar, is_nightlife, is_beauty_health,
            is_cafe, is_gym, is_restaurant, is_shop, cuisine_types,
            restaurants_delivery, outdoor_seating, accepts_credit_cards,
            restaurants_takeout, wifi, restaurants_good_for_groups,
            restaurants_attire, noise_level, good_for_dessert, good_for_latenight,
            good_for_lunch, good_for_dinner, good_for_brunch, good_for_breakfast,
            hours_monday, hours_tuesday, hours_wednesday, hours_thursday,
            hours_friday, hours_saturday, hours_sunday
        ) VALUES %s ON CONFLICT (business_id) DO UPDATE SET
            name = EXCLUDED.name,
            address = EXCLUDED.address,
            stars = EXCLUDED.stars,
            review_count = EXCLUDED.review_count
        """
        
        print("Inserting businesses into database...")
        execute_values(
            self.cursor, insert_query, businesses_data,
            template=None, page_size=1000
        )
        
        self.conn.commit()
        print(f"Successfully migrated {len(businesses_data)} businesses!")
    
    def close(self):
        self.cursor.close()
        self.conn.close()

# Usage example
if __name__ == "__main__":
    # Update with your database connection string
    DB_CONNECTION = "postgresql://postgres:1234@localhost:5433/traviadb"
    
    migrator = BusinessDataMigration(DB_CONNECTION)
    try:
        # Update with your CSV file path
        migrator.migrate_businesses("C:/Users/mmahm/Desktop/Travia AI/pre_processed_df_with.csv")
    finally:
        migrator.close()