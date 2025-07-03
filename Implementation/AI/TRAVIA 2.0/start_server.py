#!/usr/bin/env python3
"""
TRAVIA FastAPI Server Startup Script
====================================

This script starts the TRAVIA FastAPI server with proper configuration
for development and production environments.
"""

import uvicorn
import sys
import os
import asyncio
from pathlib import Path

def main():
    """Main startup function"""
    
    # Add current directory to Python path
    current_dir = Path(_file_).parent
    sys.path.insert(0, str(current_dir))
    
    print("🚀 Starting TRAVIA v2.0 FastAPI Server...")
    print("=" * 50)
    host = "192.168.8.17"
    # Development configuration
    config = {
        "app": "main:app",
        "host": host,
        "port": 8001,
        "reload": True,
        "reload_dirs": [str(current_dir)],
        "log_level": "info",
    }
    
    # Check if running in production
    if os.getenv("ENVIRONMENT") == "production":
        config.update({
            "reload": False,
            "workers": 4,
            "log_level": "warning"
        })
        print("🌐 Running in PRODUCTION mode")
    else:
        print("🛠  Running in DEVELOPMENT mode")
    
    print(f"📡 Server will be available at: http://{host}:{config['port']}")
    print(f"📚 API Documentation: http://{host}:{config['port']}/docs")
    print(f"🔄 Auto-reload: {'Enabled' if config['reload'] else 'Disabled'}")
    print("=" * 50)
    
    try:
        uvicorn.run(**config)
    except KeyboardInterrupt:
        print("\n🛑 Server stopped by user")
    except Exception as e:
        print(f"❌ Server startup failed: {e}")
        sys.exit(1)

if _name_ == "_main_":
    main()