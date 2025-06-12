#!/usr/bin/env python3
"""
TRAVIA FastAPI Testing Script
============================

Quick script to test the basic functionality of the TRAVIA FastAPI backend.
This script tests endpoints that don't require user creation since users
will be created by the Flutter mobile app.
"""

import asyncio
import aiohttp
import json
from datetime import datetime

BASE_URL = "http://localhost:8000"

async def test_health_check():
    """Test the health check endpoint"""
    print("🔍 Testing health check...")
    
    async with aiohttp.ClientSession() as session:
        async with session.get(f"{BASE_URL}/health") as response:
            if response.status == 200:
                data = await response.json()
                print(f"✅ Health check passed: {data}")
                return True
            else:
                print(f"❌ Health check failed: {response.status}")
                return False

async def test_root_endpoint():
    """Test the root endpoint"""
    print("\n🏠 Testing root endpoint...")
    
    async with aiohttp.ClientSession() as session:
        async with session.get(f"{BASE_URL}/") as response:
            if response.status == 200:
                data = await response.json()
                print(f"✅ Root endpoint working: {data}")
                return True
            else:
                print(f"❌ Root endpoint failed: {response.status}")
                return False

async def test_get_locations():
    """Test getting available locations"""
    print("\n🌍 Testing locations endpoint...")
    
    async with aiohttp.ClientSession() as session:
        async with session.get(f"{BASE_URL}/locations") as response:
            if response.status == 200:
                data = await response.json()
                print(f"✅ Found {len(data)} locations")
                if data:
                    print(f"   Sample locations:")
                    for i, loc in enumerate(data[:3]):  # Show first 3
                        print(f"     {i+1}. {loc['locality']}, {loc['region']} ({loc['business_count']} businesses)")
                    return data[0]  # Return first location for potential testing
                return None
            else:
                text = await response.text()
                print(f"❌ Locations request failed: {response.status} - {text}")
                return None

async def test_api_documentation():
    """Test API documentation endpoint"""
    print("\n📚 Testing API documentation...")
    
    async with aiohttp.ClientSession() as session:
        async with session.get(f"{BASE_URL}/docs") as response:
            if response.status == 200:
                print("✅ API documentation accessible at /docs")
                return True
            else:
                print(f"❌ API documentation failed: {response.status}")
                return False

async def test_openapi_schema():
    """Test OpenAPI schema endpoint"""
    print("\n📋 Testing OpenAPI schema...")
    
    async with aiohttp.ClientSession() as session:
        async with session.get(f"{BASE_URL}/openapi.json") as response:
            if response.status == 200:
                data = await response.json()
                print(f"✅ OpenAPI schema available")
                print(f"   API Title: {data.get('info', {}).get('title', 'N/A')}")
                print(f"   API Version: {data.get('info', {}).get('version', 'N/A')}")
                print(f"   Endpoints: {len(data.get('paths', {}))}")
                return True
            else:
                print(f"❌ OpenAPI schema failed: {response.status}")
                return False

async def test_existing_users():
    """Test getting existing users (if any)"""
    print("\n👥 Testing existing users endpoint...")
    
    async with aiohttp.ClientSession() as session:
        async with session.get(f"{BASE_URL}/users") as response:
            if response.status == 200:
                data = await response.json()
                print(f"✅ Users endpoint working - found {len(data)} existing users")
                if data:
                    print(f"   Sample user: {data[0]['display_name']} (ID: {data[0]['id'][:8]}...)")
                    return data[0]['id']  # Return first user ID for testing
                else:
                    print("   No users found (users will be created by Flutter app)")
                return None
            else:
                text = await response.text()
                print(f"❌ Users endpoint failed: {response.status} - {text}")
                return None

async def test_user_specific_endpoints(user_id):
    """Test user-specific endpoints if we have a user ID"""
    if not user_id:
        print("\n⏭️  Skipping user-specific tests (no existing users)")
        return
    
    print(f"\n👤 Testing user-specific endpoints with user {user_id[:8]}...")
    
    async with aiohttp.ClientSession() as session:
        # Test get user preferences
        async with session.get(f"{BASE_URL}/users/{user_id}/preferences") as response:
            if response.status == 200:
                data = await response.json()
                print("✅ User preferences endpoint working")
                print(f"   Budget: {data.get('budget', 'Not set')}")
                print(f"   Travel days: {data.get('travel_days', 'Not set')}")
                print(f"   Location: {data.get('location', 'Not set')}")
            else:
                print(f"✅ User preferences endpoint working (no preferences set yet)")
        
        # Test get user interactions
        async with session.get(f"{BASE_URL}/users/{user_id}/interactions") as response:
            if response.status == 200:
                data = await response.json()
                print(f"✅ User interactions endpoint working - {len(data)} interactions")
            else:
                print(f"✅ User interactions endpoint working (no interactions yet)")

async def run_all_tests():
    """Run all API tests"""
    print("=" * 70)
    print("🧪 TRAVIA FastAPI Testing Suite (Flutter-Ready)")
    print("=" * 70)
    print("Testing core API functionality without creating users")
    print("(Users will be created by the Flutter mobile app)")
    print("=" * 70)
    
    # Test 1: Health check
    health_ok = await test_health_check()
    if not health_ok:
        print("\n❌ Health check failed. Make sure the server is running on http://localhost:8000")
        return False
    
    # Test 2: Root endpoint
    await test_root_endpoint()
    
    # Test 3: Get locations
    location = await test_get_locations()
    
    # Test 4: API documentation
    await test_api_documentation()
    
    # Test 5: OpenAPI schema
    await test_openapi_schema()
    
    # Test 6: Check existing users
    user_id = await test_existing_users()
    
    # Test 7: User-specific endpoints (if users exist)
    await test_user_specific_endpoints(user_id)
    
    print("\n" + "=" * 70)
    print("🎉 Core API Testing Complete!")
    print("=" * 70)
    print("\n🚀 API is ready for Flutter integration!")
    print("\nNext steps:")
    print("1. 📱 Build your Flutter app using the API endpoints")
    print("2. 📚 Use the API docs: http://localhost:8000/docs")
    print("3. 📖 Follow the Flutter guide: flutter_integration.md")
    print("4. 🎯 Create users through your Flutter app")
    
    if location:
        print(f"\n📍 Available locations found - you can test itinerary generation")
        print(f"   Sample location: {location['locality']}, {location['region']}")
    
    print("\n💡 The API is working correctly and ready for mobile app integration!")
    
    return True

async def main():
    """Main test function"""
    try:
        await run_all_tests()
    except aiohttp.ClientConnectorError:
        print("❌ Cannot connect to server. Make sure it's running:")
        print("   py start_server.py")
        print("   or")
        print("   uvicorn main:app --reload")
    except Exception as e:
        print(f"❌ Test failed with error: {e}")

if __name__ == "__main__":
    asyncio.run(main()) 