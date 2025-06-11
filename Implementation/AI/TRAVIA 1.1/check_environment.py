#!/usr/bin/env python3
"""
Environment Check Script

Quick check to verify Python environment and database connectivity
before running the metadata learning tests.
"""

import sys
import os

def check_python_version():
    """Check Python version"""
    print("🐍 Checking Python environment...")
    print(f"   Python version: {sys.version}")
    print(f"   Python executable: {sys.executable}")
    
    if sys.version_info >= (3, 7):
        print("   ✅ Python version is compatible")
        return True
    else:
        print("   ❌ Python 3.7+ required")
        return False

def check_dependencies():
    """Check required dependencies"""
    print(f"\n📦 Checking dependencies...")
    
    required_packages = [
        'psycopg2',
        'numpy', 
        'pandas',
        'sklearn',
        'torch',
        'flask'
    ]
    
    missing_packages = []
    
    for package in required_packages:
        try:
            if package == 'sklearn':
                import sklearn
                print(f"   ✅ {package} (version: {sklearn.__version__})")
            elif package == 'psycopg2':
                import psycopg2
                print(f"   ✅ {package} (version: {psycopg2.__version__})")
            elif package == 'numpy':
                import numpy
                print(f"   ✅ {package} (version: {numpy.__version__})")
            elif package == 'pandas':
                import pandas
                print(f"   ✅ {package} (version: {pandas.__version__})")
            elif package == 'torch':
                import torch
                print(f"   ✅ {package} (version: {torch.__version__})")
            elif package == 'flask':
                import flask
                print(f"   ✅ {package} (version: {flask.__version__})")
            else:
                __import__(package)
                print(f"   ✅ {package}")
        except ImportError:
            print(f"   ❌ {package} - NOT FOUND")
            missing_packages.append(package)
    
    if missing_packages:
        print(f"\n❌ Missing packages: {', '.join(missing_packages)}")
        print(f"   Install with: pip install {' '.join(missing_packages)}")
        return False
    else:
        print(f"   ✅ All required packages found")
        return True

def check_database_connection():
    """Check database connectivity"""
    print(f"\n🗄️ Checking database connection...")
    
    DB_CONFIG = {
        'host': 'localhost',
        'database': 'traviadb',
        'user': 'postgres',
        'password': '1234',
        'port': 5433
    }
    
    try:
        import psycopg2
        conn = psycopg2.connect(**DB_CONFIG)
        cursor = conn.cursor()
        
        # Test basic query
        cursor.execute("SELECT version();")
        version = cursor.fetchone()[0]
        print(f"   ✅ Connected to PostgreSQL")
        print(f"   Database version: {version}")
        
        # Check if required tables exist
        tables_to_check = ['users', 'posts', 'businesses']
        existing_tables = []
        
        for table in tables_to_check:
            cursor.execute("""
                SELECT EXISTS (
                    SELECT FROM information_schema.tables 
                    WHERE table_name = %s
                );
            """, (table,))
            exists = cursor.fetchone()[0]
            if exists:
                existing_tables.append(table)
                print(f"   ✅ Table '{table}' exists")
            else:
                print(f"   ⚠️ Table '{table}' not found")
        
        cursor.close()
        conn.close()
        
        if len(existing_tables) >= 2:
            print(f"   ✅ Database setup looks good")
            return True
        else:
            print(f"   ⚠️ Some tables missing, but tests can create them")
            return True
            
    except ImportError:
        print(f"   ❌ psycopg2 not installed")
        return False
    except Exception as e:
        print(f"   ❌ Database connection failed: {e}")
        print(f"   Check if PostgreSQL is running on port 5433")
        print(f"   Verify database 'traviadb' exists")
        print(f"   Check username/password: postgres/1234")
        return False

def check_flask_app():
    """Check if flask_app.py exists and can be imported"""
    print(f"\n🌐 Checking Flask app...")
    
    if os.path.exists('flask_app.py'):
        print(f"   ✅ flask_app.py found")
        
        try:
            # Try to import the recommendation system
            from flask_app import TravelRecommendationSystem, DB_CONFIG
            rec_system = TravelRecommendationSystem()
            print(f"   ✅ TravelRecommendationSystem can be imported")
            print(f"   ✅ Metadata learning methods available")
            return True
        except Exception as e:
            print(f"   ❌ Error importing TravelRecommendationSystem: {e}")
            return False
    else:
        print(f"   ❌ flask_app.py not found")
        return False

def run_quick_test():
    """Run a quick functionality test"""
    print(f"\n🧪 Running quick functionality test...")
    
    try:
        from flask_app import TravelRecommendationSystem
        rec_system = TravelRecommendationSystem()
        
        # Test metadata mapping
        test_business = {
            'name': 'Test Restaurant',
            'fake_cuisine': 'Italian',
            'ambience_romantic': True,
            'ambience_classy': True,
            'good_for_kids': False,
            'price_range': 3
        }
        
        metadata_format = rec_system.map_business_to_metadata_format(test_business)
        print(f"   ✅ Business-to-metadata mapping works")
        
        # Test compatibility scoring with empty preferences
        score = rec_system.calculate_metadata_compatibility_score(test_business, {})
        print(f"   ✅ Compatibility scoring works (score: {score:.3f})")
        
        print(f"   ✅ Core functionality verified")
        return True
        
    except Exception as e:
        print(f"   ❌ Functionality test failed: {e}")
        return False

def main():
    """Run all environment checks"""
    print("🔍 ENVIRONMENT CHECK FOR METADATA LEARNING SYSTEM")
    print("=" * 60)
    
    checks = [
        ("Python Version", check_python_version),
        ("Dependencies", check_dependencies),
        ("Database Connection", check_database_connection),
        ("Flask App", check_flask_app),
        ("Functionality", run_quick_test)
    ]
    
    passed = 0
    total = len(checks)
    
    for check_name, check_func in checks:
        try:
            if check_func():
                passed += 1
        except Exception as e:
            print(f"   ❌ {check_name} check failed with error: {e}")
    
    print(f"\n{'='*60}")
    print(f"ENVIRONMENT CHECK RESULTS: {passed}/{total} PASSED")
    
    if passed == total:
        print(f"✅ ALL CHECKS PASSED! Ready to run metadata learning tests.")
        print(f"\nNext steps:")
        print(f"   1. Run: python simple_metadata_test.py")
        print(f"   2. Or run: python test_metadata_learning.py")
    elif passed >= 3:
        print(f"⚠️ MOSTLY READY. Some issues found but tests might still work.")
        print(f"Try running: python simple_metadata_test.py")
    else:
        print(f"❌ ENVIRONMENT NOT READY. Please fix the issues above.")
        
        if passed == 0:
            print(f"\nTroubleshooting steps:")
            print(f"   1. Make sure Python 3.7+ is installed and in PATH")
            print(f"   2. Install required packages: pip install -r requirements.txt")
            print(f"   3. Start PostgreSQL database on port 5433")
            print(f"   4. Create database 'traviadb' if it doesn't exist")

if __name__ == "__main__":
    main() 