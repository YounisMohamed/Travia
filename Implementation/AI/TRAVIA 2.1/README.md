# TRAVIA v2.0 - AI Travel Planner (FastAPI + Supabase)

An intelligent travel recommendation system that generates personalized itineraries using machine learning and AI. This version has been completely refactored from Flask to FastAPI with Supabase backend and mobile-ready API endpoints for Flutter integration.

## 🚀 What's New in v2.0

### Major Changes
- **Framework Migration**: Flask → FastAPI for better performance and automatic API documentation
- **Database Migration**: Local PostgreSQL → Supabase (cloud PostgreSQL) 
- **Schema Update**: Migrated from dataset2 to dataset1 structure for businesses table
- **Mobile Ready**: API designed specifically for Flutter mobile app integration
- **Async Support**: Full async/await support for better concurrency
- **Auto Documentation**: Swagger/OpenAPI docs auto-generated at `/docs`

### Database Schema Changes
- `city/state` → `locality/region` for better international support
- `fake_cuisine` → `cuisines` (JSON array)
- `restaurants_delivery` → `has_delivery`
- `wifi` → `has_wifi`
- **New fields**: `phone`, `website`, `photos`, `payment_options`, `serves_beer`, `primary_category`, `categories`

## 🏗️ Architecture

```
TRAVIA v2.0 FastAPI Backend
├── main.py                     # FastAPI application & API endpoints
├── services/
│   ├── recommendation_service.py  # Core AI recommendation logic
│   └── __init__.py
├── database_migration.py       # Schema verification script
├── start_server.py            # Server startup script
├── requirements.txt           # Python dependencies
├── flutter_integration.md     # Flutter integration guide
└── README.md                  # This file
```

## 🛠️ Installation & Setup

### Prerequisites
- Python 3.8+
- Supabase account with database access
- Git

### 1. Clone Repository
```bash
git clone <repository-url>
cd TRAVIA-v2
```

### 2. Install Dependencies
```bash
pip install -r requirements.txt
```

### 3. Verify Database Connection
```bash
python database_migration.py
```

This script will:
- ✅ Test connection to Supabase
- ✅ Verify new schema structure
- ✅ Check data availability
- ✅ Test API compatibility

### 4. Start the Server

#### Option A: Using startup script (recommended)
```bash
python start_server.py
```

#### Option B: Direct uvicorn command
```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

### 5. Access the Application
- **API Server**: http://localhost:8000
- **API Documentation**: http://localhost:8000/docs
- **Health Check**: http://localhost:8000/health

## 📊 Database Configuration

### Supabase Connection
The application connects to Supabase using the following connection string:
```
postgresql://postgres.cqcsgwlskhuylgbqegnz:traviaSupabase@aws-0-eu-central-1.pooler.supabase.com:5432/postgres
```

### Required Tables
- `users` - User accounts
- `user_preferences` - Travel preferences
- `user_interactions` - User feedback (likes/dislikes)
- `businesses` - Venue/business data (updated schema)
- `posts` - Social media posts
- `likes` - Post likes
- `metadata` - Post metadata for learning

## 🔌 API Endpoints

### Authentication & Users
- `POST /users` - Create new user
- `GET /users` - List all users
- `GET /users/{user_id}` - Get specific user

### Preferences
- `POST /users/{user_id}/preferences` - Save travel preferences
- `GET /users/{user_id}/preferences` - Get user preferences

### Travel Planning
- `GET /locations` - Get available travel destinations
- `POST /users/{user_id}/itinerary` - Generate personalized itinerary

### Feedback & Learning
- `POST /users/{user_id}/feedback` - Submit business feedback
- `GET /users/{user_id}/interactions` - Get interaction history

### System
- `GET /health` - Health check
- `GET /` - API info

## 📱 Flutter Mobile Integration

### Quick Start
1. See `flutter_integration.md` for complete integration guide
2. Use the provided Dart models and API service classes
3. Base URL: `https://your-domain.com/api/v1`

### Example Flutter API Call
```dart
final apiService = TraviaApiService();
final locations = await apiService.getLocations();
final itinerary = await apiService.generateItinerary(userId, "Las Vegas", "Nevada");
```

## 🤖 AI Features

### Machine Learning Components
- **PPO Agent**: Reinforcement learning for recommendation optimization
- **Content-Based Filtering**: Business similarity matching
- **TF-IDF Vectorization**: Text analysis for preferences
- **Metadata Learning**: Social preference analysis

### Recommendation Algorithm
1. **User Profiling**: Extract features from preferences and past interactions
2. **Business Categorization**: Classify venues by type, cuisine, and attributes
3. **Similarity Scoring**: Calculate compatibility between user and businesses
4. **Itinerary Generation**: Create balanced daily plans with variety
5. **Feedback Learning**: Improve recommendations based on user feedback

## 🔧 Development

### Project Structure
```
TRAVIA/
├── main.py                 # FastAPI app with all endpoints
├── services/
│   └── recommendation_service.py  # Core ML/AI logic
├── requirements.txt        # Dependencies
├── database_migration.py   # Database verification
└── start_server.py        # Server startup
```

### Adding New Features
1. **New API Endpoint**: Add to `main.py`
2. **New ML Feature**: Add to `services/recommendation_service.py`
3. **Database Changes**: Update migration script
4. **Flutter Integration**: Update `flutter_integration.md`

### Testing
```bash
# Verify database
python database_migration.py

# Test API endpoints
curl http://localhost:8000/health
curl http://localhost:8000/locations

# View API docs
open http://localhost:8000/docs
```

## 🚀 Deployment

### Environment Variables
```bash
export ENVIRONMENT=production
export DATABASE_URL=postgresql://...
```

### Production Startup
```bash
ENVIRONMENT=production python start_server.py
```

### Docker (Optional)
```dockerfile
FROM python:3.9-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
CMD ["python", "start_server.py"]
```

## 📈 Performance

### FastAPI Benefits
- **2-3x faster** than Flask for concurrent requests
- **Async support** for database operations
- **Automatic validation** with Pydantic models
- **Built-in documentation** with Swagger UI

### Database Optimization
- **Connection pooling** with asyncpg
- **Prepared statements** for security
- **Indexed queries** on location and rating fields

## 🛡️ Security

### Current Implementation
- Input validation with Pydantic
- SQL injection protection with parameterized queries
- CORS enabled for mobile app access

### Recommended Additions
- JWT authentication
- Rate limiting
- API key management
- Input sanitization

## 🐛 Troubleshooting

### Common Issues

**Database Connection Failed**
```bash
# Verify connection
python database_migration.py
```

**Missing Dependencies**
```bash
pip install -r requirements.txt
```

**Port Already in Use**
```bash
# Change port in start_server.py or kill existing process
lsof -ti:8000 | xargs kill -9
```

**Import Errors**
```bash
# Ensure you're in the correct directory
cd /path/to/TRAVIA
python start_server.py
```

## 📝 API Documentation

Once the server is running, visit http://localhost:8000/docs for:
- Interactive API testing
- Request/response schemas
- Authentication details
- Example requests

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

For issues and questions:
1. Check the troubleshooting section above
2. Review the API documentation at `/docs`
3. Run the database verification script
4. Check server logs for error details

---

**TRAVIA v2.0** - Powered by FastAPI, Supabase, and AI 🚀 