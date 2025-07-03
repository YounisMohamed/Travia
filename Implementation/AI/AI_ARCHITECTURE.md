# TRAVIA 2.0 - Complete AI Architecture

## 🏗️ System Overview

TRAVIA 2.0 is an intelligent travel recommendation system that combines multiple AI/ML techniques to provide personalized travel itineraries. The system uses a hybrid approach combining reinforcement learning, content-based filtering, and social preference learning.

## 🧠 Core AI Components

### 1. PPO (Proximal Policy Optimization) Agent
**Purpose**: Reinforcement learning agent that learns from user interactions to optimize recommendations

**Architecture**:
```
PPO Agent Neural Network
├── Actor Network (Policy)
│   ├── Input Layer: 18 features (user + business combined)
│   ├── Hidden Layer 1: 128 neurons + ReLU
│   ├── Hidden Layer 2: 128 neurons + ReLU
│   └── Output Layer: 2 actions (like/dislike) + Softmax
└── Critic Network (Value Function)
    ├── Input Layer: 18 features
    ├── Hidden Layer 1: 128 neurons + ReLU
    ├── Hidden Layer 2: 128 neurons + ReLU
    └── Output Layer: 1 value + Linear
```

**Training Process**:
1. **State Creation**: Combine user preferences (10 features) + business features (8 features)
2. **Action Space**: Binary classification (like=1, dislike=0)
3. **Reward Function**: 
   - Base reward: +2.0 for likes, -2.0 for dislikes
   - Cuisine bonus: +1.5 for preferred cuisine matches
   - Metadata bonus: +0.5 for ambience/attribute matches
4. **Training Loop**: 5 epochs with PPO clipping (ε=0.3)
5. **Model Persistence**: Saved to `models/ppo_agent.pth`

### 2. Content-Based Filtering System
**Purpose**: Match businesses to user preferences using feature similarity

**Feature Engineering**:
```
User Feature Vector (18 dimensions):
├── Basic Preferences (14 features)
│   ├── budget (normalized 0-1)
│   ├── travel_days (normalized 0-1)
│   ├── travel_style (one-hot: tourist/local)
│   ├── noise_preference (one-hot: noisy/quiet)
│   ├── family_friendly (binary)
│   ├── accommodation_type (one-hot: hotel/hostel/airbnb)
│   ├── ambience_preference (one-hot: classy/casual)
│   └── good_for_kids (binary)
    └── Cuisine preferences (4 features)
        ├── american_preference (0-1 score)
        ├── chinese_preference (0-1 score)
        ├── italian_preference (0-1 score)
        └── mexican_preference (0-1 score)


└── Metadata Preferences (4 features)
    ├── romantic_preference (0-1 score)
    ├── good_for_kids_preference (0-1 score)
    ├── classy_preference (0-1 score)
    ├── casual_preference (0-1 score)
    
Business Feature Vector (25 dimensions):
├── Basic Attributes (3 features)
│   ├── price_range (normalized 0-1)
│   ├── stars (normalized 0-1)
│   └── review_count (log-normalized 0-1)
├── Business Type (7 features)
│   ├── is_restaurant (binary)
│   ├── is_cafe (binary)
│   ├── is_bar (binary)
│   ├── is_gym (binary)
│   ├── is_shop (binary)
│   ├── is_beauty_health (binary)
│   └── is_nightlife (binary)
├── Meal Times (4 features)
│   ├── good_for_breakfast (binary)
│   ├── good_for_lunch (binary)
│   ├── good_for_dinner (binary)
│   └── good_for_dessert (binary)
├── Ambience (4 features)
│   ├── ambience_classy (binary)
│   ├── ambience_casual (binary)
│   ├── ambience_romantic (binary)
│   └── ambience_touristy (binary)
└── Facilities (7 features)
    ├── good_for_kids (binary)
    ├── has_wifi (binary)
    ├── has_delivery (binary)
    ├── serves_beer (binary)
    └── Placeholders (3 features)
```

### 3. Social Preference Learning
**Purpose**: Extract user preferences from social media interactions

**Metadata Analysis Pipeline**:
```
Social Learning Process:
1. User likes posts → Extract metadata
2. Analyze patterns across liked posts
3. Calculate preference scores (0-1)
4. Apply enhancement boost for strong patterns (>30% frequency)
5. Integrate into user feature vector

Metadata Attributes:
├── Binary Attributes
│   ├── romantic (0/1)
│   ├── good_for_kids (0/1)
│   ├── classy (0/1)
│   └── casual (0/1)
└── Cuisine Types
    └── cuisine_type (string classification)
```

## 🔄 Data Flow Architecture

### 1. User Interaction Pipeline
```
User Action → Database → AI Processing → Model Update
     ↓
1. User likes/dislikes business
2. Store in user_interactions table
3. Trigger PPO training with new data
4. Update model weights
5. Save improved model
```

### 2. Recommendation Generation Pipeline
```
User Request → Data Retrieval → AI Scoring → Itinerary Creation
     ↓
1. Get user preferences + metadata
2. Fetch businesses by location
3. Score each business with RL + content-based
4. Apply 70/30 balance (preferred/variety)
5. Generate daily itinerary structure
6. Return personalized plan
```

### 3. Learning Feedback Loop
```
Continuous Learning Cycle:
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   User Action   │───▶│  Store Feedback │───▶│  Train PPO      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         ▲                                              │
         │                                              ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  Better Recs    │◀───│  Updated Model  │◀───│  Save Model     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 🎯 Recommendation Algorithm

### 1. Business Selection Strategy
```
Balanced Variety Approach (70/30 Rule):
├── 70% Preferred Businesses
│   ├── Match user's explicit cuisine preferences
│   ├── Use RL scoring for ranking
│   └── Consider metadata preferences
└── 30% Variety Businesses
    ├── Different cuisines/experiences
    ├── Explore new options
    └── Prevent recommendation echo chambers
```

### 2. Itinerary Generation Logic
```
Daily Structure:
├── Breakfast (2 options)
│   ├── Cafes or breakfast restaurants
│   └── RL-ranked selection
├── Lunch (3 options)
│   ├── Restaurants with lunch service
│   └── Cuisine variety within preferences
├── Dinner (3 options)
│   ├── Restaurants with dinner service
│   └── Higher-end options for evening
├── Activities (1-4 options)
│   ├── Gym (if preferred)
│   ├── Shopping (if preferred)
│   ├── Beauty/Health (if preferred)
│   ├── Bars (if preferred)
│   └── Nightlife (if preferred)
└── Dessert (2 options)
    ├── Ice cream, bakeries, dessert places
    └── RL-ranked selection
```

### 3. Scoring Mechanism
```
Multi-Modal Scoring:
├── RL Score (70% weight)
│   ├── PPO agent prediction
│   ├── Like probability (0-1)
│   └── Confidence score
├── Content-Based Score (20% weight)
│   ├── Feature similarity
│   ├── Cuisine matching
│   └── Ambience compatibility
└── Metadata Score (10% weight)
    ├── Social preference alignment
    ├── Historical pattern matching
    └── Enhanced learning from likes
```

## 🗄️ Database Schema for AI

### Core Tables for ML/AI
```
1. users
   ├── id (UUID) - User identifier
   ├── email - Contact information
   └── display_name - User name

2. user_preferences
   ├── user_id (FK) - Links to users
   ├── budget (1-4) - Price preference
   ├── travel_days (1-30) - Trip duration
   ├── preferred_cuisine (array) - Cuisine preferences
   └── Activity flags (gym, bar, nightlife, etc.)

3. businesses
   ├── id (PK) - Business identifier
   ├── name, address, location - Basic info
   ├── stars, review_count, price_range - Ratings
   ├── cuisines (array) - Cuisine types
   ├── Business type flags (restaurant, cafe, bar, etc.)
   ├── Meal time flags (breakfast, lunch, dinner, dessert)
   ├── Ambience flags (classy, casual, romantic, touristy)
   └── Facility flags (wifi, delivery, kids, etc.)

4. user_interactions
   ├── user_id (FK) - Links to users
   ├── business_id (FK) - Links to businesses
   ├── interaction_type - 'like' or 'dislike'
   ├── context_preferences (JSON) - User prefs at time
   └── created_at - Timestamp

5. posts
   ├── id (PK) - Post identifier
   ├── user_id (FK) - Post author
   ├── caption - Post content
   └── created_at - Timestamp

6. likes
   ├── post_id (FK) - Links to posts
   ├── liker_user_id (FK) - User who liked
   ├── type - 'like'
   └── created_at - Timestamp

7. metadata
   ├── post_id (FK) - Links to posts
   ├── romantic (boolean) - Romantic ambience
   ├── good_for_kids (boolean) - Kid-friendly
   ├── classy (boolean) - Classy ambience
   ├── casual (boolean) - Casual ambience
   └── cuisine_type (string) - Cuisine classification
```

## 🤖 AI Model Management

### Model Persistence
```
Model Storage:
├── models/ppo_agent.pth
│   ├── model_state_dict - Neural network weights
│   ├── optimizer_state_dict - Training optimizer state
│   └── training_metadata - Training history
└── Model Loading/Saving
    ├── Automatic loading on service startup
    ├── Automatic saving after training
    └── Fallback to fresh model if loading fails
```

### Training Triggers
```
Training Conditions:
├── Minimum Interactions: 2+ user interactions
├── Training Frequency: After each feedback submission
├── Training Data: Last 50 interactions per user
└── Training Duration: 5 epochs (optimized for speed)
```

## 🔧 Technical Implementation

### 1. FastAPI Backend Architecture
```
API Layer:
├── main.py - FastAPI application
│   ├── Database connection pool
│   ├── CORS middleware for Flutter
│   ├── Pydantic models for validation
│   └── REST API endpoints
└── services/
    └── recommendation_service.py - Core AI logic
        ├── PPOAgent class
        ├── TravelRecommendationService class
        ├── Feature engineering methods
        ├── Training pipeline
        └── Recommendation algorithms
```

### 2. Async Database Operations
```
Database Layer:
├── asyncpg connection pool
├── Optimized queries with business details
├── JSON field parsing for arrays
└── Transaction management for data consistency
```

### 3. Machine Learning Dependencies
```
ML Stack:
├── PyTorch - Neural network framework
├── NumPy - Numerical computations
├── Pandas - Data manipulation
├── Scikit-learn - Feature extraction (TF-IDF)
└── AsyncPG - Database operations
```

## 📊 Performance Optimizations

### 1. Query Optimization
```
Database Optimizations:
├── Single query with JOINs instead of N+1 queries
├── Indexed columns for fast filtering
├── Array containment operators for cuisine matching
├── Limited result sets (50 interactions max)
└── Connection pooling for concurrent requests
```

### 2. Model Training Optimization
```
Training Optimizations:
├── Reduced epochs (5 instead of 10)
├── Limited training data (50 interactions max)
├── Efficient tensor operations
├── Model checkpointing
└── Background training to avoid blocking
```

### 3. Recommendation Speed
```
Speed Optimizations:
├── Pre-computed feature vectors
├── Cached metadata preferences
├── Efficient business categorization
├── Parallel processing where possible
└── Early termination for low-scoring businesses
```

## 🔒 Security & Privacy

### 1. Data Protection
```
Security Measures:
├── Input validation with Pydantic
├── SQL injection prevention with parameterized queries
├── CORS configuration for mobile apps
├── UUID-based user identification
└── No sensitive data in logs
```

### 2. Privacy Considerations
```
Privacy Features:
├── User data isolation by user_id
├── Optional email addresses
├── Anonymous interaction tracking
├── No personal data in model training
└── GDPR-compliant data handling
```

## 🚀 Scalability & Deployment

### 1. Horizontal Scaling
```
Scalability Features:
├── Stateless API design
├── Database connection pooling
├── Async/await for concurrency
├── Model sharing across instances
└── Load balancer ready
```

### 2. Production Deployment
```
Deployment Architecture:
├── FastAPI with Uvicorn
├── Supabase cloud database
├── Docker containerization
├── Environment-based configuration
└── Health check endpoints
```

## 📈 Monitoring & Analytics

### 1. Performance Metrics
```
Key Metrics:
├── API response times
├── Model training duration
├── Recommendation accuracy
├── User interaction rates
└── Database query performance
```

### 2. AI Model Monitoring
```
Model Metrics:
├── Training loss curves
├── Prediction confidence scores
├── User satisfaction rates
├── Model drift detection
└── Feature importance tracking
```

## 🔮 Future Enhancements

### 1. Advanced AI Features
```
Planned Improvements:
├── Multi-armed bandit for exploration
├── Deep learning for image analysis
├── Natural language processing for reviews
├── Collaborative filtering
└── Real-time learning updates
```

### 2. Enhanced Personalization
```
Personalization Features:
├── Seasonal preference learning
├── Location-based adaptation
├── Social network integration
├── Preference evolution tracking
└── Contextual recommendations
```

## 📚 API Documentation

### Core AI Endpoints
```
AI/ML Endpoints:
├── POST /users/{user_id}/itinerary - Generate recommendations
├── POST /users/{user_id}/feedback - Train AI model
├── GET /users/{user_id}/interactions - Get learning data
├── GET /users/{user_id}/metadata-preferences - Get learned preferences
└── GET /users/{user_id}/rl-status - Get AI model status
```

This architecture provides a comprehensive, scalable, and intelligent travel recommendation system that continuously learns and improves from user interactions while maintaining high performance and user privacy. 