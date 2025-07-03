from fastapi import FastAPI, HTTPException, Depends, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel, Field
from typing import List, Optional, Dict, Any
import asyncpg
import json
import uuid
import torch
from datetime import datetime
import logging
from contextlib import asynccontextmanager
from services.recommendation_service import TravelRecommendationService
import os

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(_name_)

# Supabase Database Configuration
DATABASE_URL = "postgresql://postgres.cqcsgwlskhuylgbqegnz:traviaSupabase@aws-0-eu-central-1.pooler.supabase.com:5432/postgres"

# Global database pool
db_pool = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    global db_pool
    db_pool = await asyncpg.create_pool(
        DATABASE_URL,
        min_size=5,
        max_size=20,
        server_settings={
            'jit': 'off'
        }
    )
    logger.info("Database pool created")
    yield
    # Shutdown
    if db_pool:
        await db_pool.close()
        logger.info("Database pool closed")


app = FastAPI(
    title="TRAVIA AI Travel Planner API",
    description="FastAPI backend for TRAVIA travel recommendation system with Flutter mobile support",
    version="2.0.0",
    lifespan=lifespan
)

# CORS middleware for Flutter mobile app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure this for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Security
security = HTTPBearer(auto_error=False)


async def get_db():
    """Database connection dependency"""
    async with db_pool.acquire() as connection:
        yield connection


# Pydantic Models for Request/Response
class UserPreferences(BaseModel):
    budget: Optional[int] = Field(default=2, ge=1, le=4)
    travel_days: Optional[int] = Field(default=5, ge=1, le=30)
    travel_style: Optional[str] = Field(default="tourist", pattern="^(tourist|local)$")
    noise_preference: Optional[str] = Field(default="quiet", pattern="^(noisy|quiet)$")
    family_friendly: Optional[bool] = Field(default=False)
    accommodation_type: Optional[str] = Field(default="hotel", pattern="^(hotel|hostel|airbnb)$")
    preferred_cuisine: Optional[List[str]] = Field(default=[])
    ambience_preference: Optional[str] = Field(default="casual", pattern="^(classy|casual)$")
    good_for_kids: Optional[bool] = Field(default=False)
    include_gym: Optional[bool] = Field(default=False)
    include_bar: Optional[bool] = Field(default=False)
    include_nightlife: Optional[bool] = Field(default=False)
    include_beauty_health: Optional[bool] = Field(default=False)
    include_shop: Optional[bool] = Field(default=False)
    location: Optional[str] = Field(default=None)


class UserCreate(BaseModel):
    email: Optional[str] = None
    display_name: str


class UserResponse(BaseModel):
    id: str
    email: Optional[str]
    display_name: str
    created_at: datetime


class BusinessResponse(BaseModel):
    id: int
    business_id: str
    name: str
    address: str
    latitude: float
    longitude: float
    locality: str
    region: str
    country: str
    city: str
    stars: float
    review_count: int
    price_range: int
    primary_category: str
    categories: List[str]
    cuisines: List[str]
    phone: Optional[str]
    website: Optional[str]
    photos: List[str]
    accepts_credit_cards: bool
    payment_options: Optional[Dict[str, Any]]
    serves_beer: bool
    has_delivery: bool
    has_wifi: bool
    good_for_breakfast: bool
    good_for_lunch: bool
    good_for_dinner: bool
    good_for_dessert: bool
    ambience_classy: bool
    ambience_casual: bool
    ambience_romantic: bool
    ambience_touristy: bool
    ambience_trendy: bool
    good_for_kids: bool
    hours_monday: Optional[str]
    hours_tuesday: Optional[str]
    hours_wednesday: Optional[str]
    hours_thursday: Optional[str]
    hours_friday: Optional[str]
    hours_saturday: Optional[str]
    hours_sunday: Optional[str]
    is_bar: bool
    is_nightlife: bool
    is_beauty_health: bool
    is_cafe: bool
    is_gym: bool
    is_restaurant: bool
    is_shop: bool

class ItineraryDay(BaseModel):
    day: int
    breakfast: List[BusinessResponse]
    lunch: List[BusinessResponse]
    dinner: List[BusinessResponse]
    activities: List[BusinessResponse]
    dessert: List[BusinessResponse]


class ItineraryResponse(BaseModel):
    itinerary: List[ItineraryDay]
    total_businesses: int
    user_preferences: UserPreferences


class FeedbackRequest(BaseModel):
    business_id: int
    interaction_type: str = Field(pattern="^(like|dislike)$")


class LocationResponse(BaseModel):
    region: str
    country: str
    business_count: int


# PPO Agent is now implemented in services/recommendation_service.py

# Initialize recommendation service
recommendation_service = TravelRecommendationService()


# API Endpoints

@app.post("/users", response_model=UserResponse)
async def create_user(user_data: UserCreate, db: asyncpg.Connection = Depends(get_db)):
    """Create a new user"""
    try:
        user_id = str(uuid.uuid4())

        query = """
        INSERT INTO users (id, email, display_name, created_at)
        VALUES ($1, $2, $3, $4)
        RETURNING id, email, display_name, created_at
        """

        row = await db.fetchrow(
            query,
            user_id,
            user_data.email,
            user_data.display_name,
            datetime.now()
        )

        return UserResponse(**dict(row))

    except Exception as e:
        logger.error(f"Error creating user: {e}")
        raise HTTPException(status_code=500, detail="Failed to create user")


@app.get("/users", response_model=List[UserResponse])
async def get_users(db: asyncpg.Connection = Depends(get_db)):
    """Get all users"""
    try:
        query = """
        SELECT id, email, display_name, created_at
        FROM users
        ORDER BY created_at DESC
        """

        rows = await db.fetch(query)
        return [UserResponse(**dict(row)) for row in rows]

    except Exception as e:
        logger.error(f"Error fetching users: {e}")
        raise HTTPException(status_code=500, detail="Failed to fetch users")


@app.get("/users/{user_id}", response_model=UserResponse)
async def get_user(user_id: str, db: asyncpg.Connection = Depends(get_db)):
    """Get a specific user by ID"""
    try:
        query = """
        SELECT id, email, display_name, created_at
        FROM users
        WHERE id = $1
        """

        row = await db.fetchrow(query, user_id)

        if not row:
            raise HTTPException(status_code=404, detail="User not found")

        return UserResponse(**dict(row))

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching user: {e}")
        raise HTTPException(status_code=500, detail="Failed to fetch user")


@app.post("/users/{user_id}/preferences")
async def save_user_preferences(
        user_id: str,
        preferences: UserPreferences,
        db: asyncpg.Connection = Depends(get_db)
):
    """Save user travel preferences"""
    try:
        # Check if user exists
        user_check = await db.fetchrow("SELECT id FROM users WHERE id = $1", user_id)
        if not user_check:
            raise HTTPException(status_code=404, detail="User not found")

        # Convert preferred_cuisine list to PostgreSQL array format
        preferred_cuisine = preferences.preferred_cuisine or []

        query = """
        INSERT INTO user_preferences (
            user_id, budget, travel_days, travel_style, noise_preference,
            family_friendly, accommodation_type, preferred_cuisine, ambience_preference,
            good_for_kids, include_gym, include_bar, include_nightlife,
            include_beauty_health, include_shop, location, created_at
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17)
        """

        await db.execute(
            query,
            user_id,
            preferences.budget,
            preferences.travel_days,
            preferences.travel_style,
            preferences.noise_preference,
            preferences.family_friendly,
            preferences.accommodation_type,
            preferred_cuisine,
            preferences.ambience_preference,
            preferences.good_for_kids,
            preferences.include_gym,
            preferences.include_bar,
            preferences.include_nightlife,
            preferences.include_beauty_health,
            preferences.include_shop,
            preferences.location,
            datetime.now()
        )

        return {"message": "Preferences saved successfully"}

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error saving preferences: {e}")
        raise HTTPException(status_code=500, detail="Failed to save preferences")


@app.get("/users/{user_id}/preferences", response_model=UserPreferences)
async def get_user_preferences(user_id: str, db: asyncpg.Connection = Depends(get_db)):
    """Get user's latest preferences"""
    try:
        query = """
        SELECT budget, travel_days, travel_style, noise_preference,
               family_friendly, accommodation_type, preferred_cuisine, ambience_preference,
               good_for_kids, include_gym, include_bar, include_nightlife,
               include_beauty_health, include_shop, location
        FROM user_preferences
        WHERE user_id = $1
        ORDER BY created_at DESC
        LIMIT 1
        """

        row = await db.fetchrow(query, user_id)

        if not row:
            # Return default preferences if none found
            return UserPreferences()

        prefs_dict = dict(row)

        # Convert array back to list if needed
        if isinstance(prefs_dict.get('preferred_cuisine'), str):
            try:
                prefs_dict['preferred_cuisine'] = json.loads(prefs_dict['preferred_cuisine'])
            except:
                prefs_dict['preferred_cuisine'] = []

        return UserPreferences(**prefs_dict)

    except Exception as e:
        logger.error(f"Error fetching preferences: {e}")
        raise HTTPException(status_code=500, detail="Failed to fetch preferences")


@app.get("/locations", response_model=List[LocationResponse])
async def get_available_locations(db: asyncpg.Connection = Depends(get_db)):
    """Get available travel locations"""
    try:
        locations = await recommendation_service.get_available_locations(db)
        return [LocationResponse(**loc) for loc in locations]

    except Exception as e:
        logger.error(f"Error fetching locations: {e}")
        raise HTTPException(status_code=500, detail="Failed to fetch locations")


@app.post("/users/{user_id}/itinerary", response_model=ItineraryResponse)
async def generate_itinerary(
        user_id: str,
        city: str,
        db: asyncpg.Connection = Depends(get_db)
):
    """Generate travel itinerary for user"""
    try:
        # Get user preferences
        prefs_query = """
        SELECT budget, travel_days, travel_style, noise_preference,
               family_friendly, accommodation_type, preferred_cuisine, ambience_preference,
               good_for_kids, include_gym, include_bar, include_nightlife,
               include_beauty_health, include_shop, location
        FROM user_preferences
        WHERE user_id = $1
        ORDER BY created_at DESC
        LIMIT 1
        """

        prefs_row = await db.fetchrow(prefs_query, user_id)

        if not prefs_row:
            raise HTTPException(status_code=404, detail="User preferences not found")

        user_preferences = dict(prefs_row)

        # Convert array back to list if needed
        if isinstance(user_preferences.get('preferred_cuisine'), str):
            try:
                user_preferences['preferred_cuisine'] = json.loads(user_preferences['preferred_cuisine'])
            except:
                user_preferences['preferred_cuisine'] = []

        # 🧠 AI METADATA LEARNING: Analyze user's liked posts to extract preferences
        metadata_preferences = await recommendation_service.analyze_user_metadata_preferences(db, user_id)
        logger.info(f"🔍 AI found metadata preferences for user {user_id}: {metadata_preferences}")

        # 🤖 RL TRAINING: Train PPO agent based on user interactions
        await recommendation_service.train_ppo_agent(db, user_id)

        # Get businesses for the location with 70/30 balance (preferred vs variety)
        businesses = await recommendation_service.get_balanced_businesses_with_variety(
            db, city, user_preferences, limit=250, user_id=user_id
        )

        if not businesses:
            raise HTTPException(status_code=404, detail="No businesses found for this location")

        # Generate itinerary with AI-enhanced metadata preferences
        itinerary_data = await recommendation_service.create_static_division_itinerary(
            db, user_preferences, businesses, user_id
        )

        # Convert to response format
        itinerary_days = []
        for day_plan in itinerary_data['itinerary']:
            day = ItineraryDay(
                day=day_plan['day'],
                breakfast=[BusinessResponse(**b) for b in day_plan['breakfast']],
                lunch=[BusinessResponse(**b) for b in day_plan['lunch']],
                dinner=[BusinessResponse(**b) for b in day_plan['dinner']],
                activities=[BusinessResponse(**b) for b in day_plan['activities']],
                dessert=[BusinessResponse(**b) for b in day_plan['dessert']]
            )
            itinerary_days.append(day)

        return ItineraryResponse(
            itinerary=itinerary_days,
            total_businesses=itinerary_data['total_businesses'],
            user_preferences=UserPreferences(**user_preferences)
        )

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error generating itinerary: {e}")
        raise HTTPException(status_code=500, detail="Failed to generate itinerary")


@app.post("/users/{user_id}/feedback")
async def submit_feedback(
        user_id: str,
        feedback: FeedbackRequest,
        db: asyncpg.Connection = Depends(get_db)
):
    """Submit user feedback on a business"""
    try:
        # Check if user exists
        user_check = await db.fetchrow("SELECT id FROM users WHERE id = $1", user_id)
        if not user_check:
            raise HTTPException(status_code=404, detail="User not found")

        # Check if business exists
        business_check = await db.fetchrow("SELECT id FROM businesses WHERE id = $1", feedback.business_id)
        if not business_check:
            raise HTTPException(status_code=404, detail="Business not found")

        # Get current user preferences
        prefs_query = """
        SELECT budget, travel_days, travel_style, noise_preference,
               family_friendly, accommodation_type, preferred_cuisine, ambience_preference,
               good_for_kids, include_gym, include_bar, include_nightlife,
               include_beauty_health, include_shop, location
        FROM user_preferences
        WHERE user_id = $1
        ORDER BY created_at DESC
        LIMIT 1
        """

        prefs_row = await db.fetchrow(prefs_query, user_id)
        context_preferences = dict(prefs_row) if prefs_row else {}

        # Insert feedback
        query = """
        INSERT INTO user_interactions (user_id, business_id, interaction_type, context_preferences, created_at)
        VALUES ($1, $2, $3, $4, $5)
        """

        await db.execute(
            query,
            user_id,
            feedback.business_id,
            feedback.interaction_type,
            json.dumps(context_preferences),
            datetime.now()
        )

        # 🤖 RL RETRAINING: Retrain PPO agent with new feedback
        try:
            await recommendation_service.train_ppo_agent(db, user_id)
            logger.info(f"🤖 PPO agent retrained after feedback from user {user_id}")
        except Exception as e:
            logger.warning(f"🤖 PPO retraining failed: {e}")

        return {"message": "Feedback submitted successfully and AI model updated"}

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error submitting feedback: {e}")
        raise HTTPException(status_code=500, detail="Failed to submit feedback")


@app.get("/users/{user_id}/interactions")
async def get_user_interactions(user_id: str, db: asyncpg.Connection = Depends(get_db)):
    """Get user's interaction history"""
    try:
        query = """
        SELECT ui.id, ui.business_id, ui.interaction_type, ui.created_at,
               b.name as business_name, b.locality, b.region
        FROM user_interactions ui
        JOIN businesses b ON ui.business_id = b.id
        WHERE ui.user_id = $1
        ORDER BY ui.created_at DESC
        """

        rows = await db.fetch(query, user_id)

        interactions = []
        for row in rows:
            interactions.append({
                'id': row['id'],
                'business_id': row['business_id'],
                'business_name': row['business_name'],
                'locality': row['locality'],
                'region': row['region'],
                'interaction_type': row['interaction_type'],
                'created_at': row['created_at']
            })

        return interactions

    except Exception as e:
        logger.error(f"Error fetching interactions: {e}")
        raise HTTPException(status_code=500, detail="Failed to fetch interactions")
    

@app.delete("/users/{user_id}/interactions/{business_id}")
async def remove_user_interaction(
        user_id: str,
        business_id: int,
        db: asyncpg.Connection = Depends(get_db)
):
    """Remove user interaction for a specific business"""
    try:
        # Check if user exists
        user_check = await db.fetchrow("SELECT id FROM users WHERE id = $1", user_id)
        if not user_check:
            raise HTTPException(status_code=404, detail="User not found")

        # Check if business exists
        business_check = await db.fetchrow("SELECT id FROM businesses WHERE id = $1", business_id)
        if not business_check:
            raise HTTPException(status_code=404, detail="Business not found")

        # Check if interaction exists
        existing_interaction = await db.fetchrow(
            "SELECT id FROM user_interactions WHERE user_id = $1 AND business_id = $2",
            user_id, business_id
        )
        
        if not existing_interaction:
            raise HTTPException(status_code=404, detail="No interaction found to remove")

        # Delete the interaction
        delete_query = """
        DELETE FROM user_interactions 
        WHERE user_id = $1 AND business_id = $2
        """
        
        result = await db.execute(delete_query, user_id, business_id)
        
        # Check if deletion was successful
        if result == "DELETE 0":
            raise HTTPException(status_code=404, detail="No interaction found to remove")

        # 🤖 RL RETRAINING: Retrain PPO agent after interaction removal
        try:
            await recommendation_service.train_ppo_agent(db, user_id)
            logger.info(f"🤖 PPO agent retrained after interaction removal for user {user_id}")
        except Exception as e:
            logger.warning(f"🤖 PPO retraining failed: {e}")

        return {"message": "Interaction removed successfully and AI model updated"}

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error removing interaction: {e}")
        raise HTTPException(status_code=500, detail="Failed to remove interaction")


# Alternative endpoint that removes by interaction type (if you want more granular control)
@app.delete("/users/{user_id}/interactions/{business_id}/{interaction_type}")
async def remove_specific_interaction(
        user_id: str,
        business_id: int,
        interaction_type: str,
        db: asyncpg.Connection = Depends(get_db)
):
    """Remove specific user interaction (like or dislike) for a business"""
    try:
        # Validate interaction type
        if interaction_type not in ['like', 'dislike']:
            raise HTTPException(status_code=400, detail="Invalid interaction type. Must be 'like' or 'dislike'")

        # Check if user exists
        user_check = await db.fetchrow("SELECT id FROM users WHERE id = $1", user_id)
        if not user_check:
            raise HTTPException(status_code=404, detail="User not found")

        # Check if business exists
        business_check = await db.fetchrow("SELECT id FROM businesses WHERE id = $1", business_id)
        if not business_check:
            raise HTTPException(status_code=404, detail="Business not found")

        # Delete the specific interaction
        delete_query = """
        DELETE FROM user_interactions 
        WHERE user_id = $1 AND business_id = $2 AND interaction_type = $3
        """
        
        result = await db.execute(delete_query, user_id, business_id, interaction_type)
        
        # Check if deletion was successful
        if result == "DELETE 0":
            raise HTTPException(status_code=404, detail=f"No {interaction_type} interaction found to remove")

        # 🤖 RL RETRAINING: Retrain PPO agent after interaction removal
        try:
            await recommendation_service.train_ppo_agent(db, user_id)
            logger.info(f"🤖 PPO agent retrained after {interaction_type} removal for user {user_id}")
        except Exception as e:
            logger.warning(f"🤖 PPO retraining failed: {e}")

        return {"message": f"{interaction_type.capitalize()} interaction removed successfully and AI model updated"}

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error removing {interaction_type} interaction: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to remove {interaction_type} interaction")


@app.get("/users/{user_id}/metadata-preferences")
async def get_user_metadata_preferences(user_id: str, db: asyncpg.Connection = Depends(get_db)):
    """
    🧠 AI ENDPOINT: Get user's learned metadata preferences from liked posts
    This shows HOW THE AI KNOWS what the user likes!
    """
    try:
        # Get metadata preferences learned from liked posts
        metadata_preferences = await recommendation_service.analyze_user_metadata_preferences(db, user_id)

        # Get interaction data for additional context
        interaction_data = await recommendation_service.get_user_interactions_data(db, user_id)

        return {
            "user_id": user_id,
            "metadata_preferences": metadata_preferences,
            "interaction_summary": {
                "total_likes": interaction_data['total_likes'],
                "total_dislikes": interaction_data['total_dislikes'],
                "recent_interactions": interaction_data['interactions'][:10]  # Last 10
            },
            "ai_explanation": {
                "how_it_works": "AI analyzes metadata from posts you liked to learn your preferences",
                "calculation": "preference_score = liked_posts_with_attribute / total_liked_posts",
                "enhancement": "Cuisine preferences get 1.5x boost for patterns >30%",
                "minimum_data": "Requires at least 2 liked posts for meaningful analysis"
            }
        }

    except Exception as e:
        logger.error(f"Error fetching metadata preferences: {e}")
        raise HTTPException(status_code=500, detail="Failed to fetch metadata preferences")


@app.get("/users/{user_id}/rl-status")
async def get_rl_status(user_id: str, db: asyncpg.Connection = Depends(get_db)):
    """
    🤖 RL STATUS ENDPOINT: Check PPO agent training status and model info
    """
    try:
        # Get user interactions count
        interaction_data = await recommendation_service.get_user_interactions_data(db, user_id)

        # Check if model file exists
        model_exists = os.path.exists(recommendation_service.model_path)

        # Get metadata preferences
        metadata_preferences = await recommendation_service.analyze_user_metadata_preferences(db, user_id)

        # Test RL scoring with a sample business (if available)
        sample_business_query = """
        SELECT id, name, locality, region, country, stars, review_count, price_range,
               primary_category, categories, cuisines, phone, website, photos,
               payment_options, serves_beer, has_delivery, has_wifi,
               good_for_breakfast, good_for_lunch, good_for_dinner, good_for_dessert,
               ambience_classy, ambience_casual, ambience_romantic, ambience_touristy,
               good_for_kids
        FROM businesses LIMIT 1
        """

        sample_business_row = await db.fetchrow(sample_business_query)
        sample_rl_score = None

        if sample_business_row:
            # Get user preferences
            prefs_query = """
            SELECT budget, travel_days, travel_style, noise_preference,
                   family_friendly, accommodation_type, preferred_cuisine, ambience_preference,
                   good_for_kids, include_gym, include_bar, include_nightlife,
                   include_beauty_health, include_shop, location
            FROM user_preferences
            WHERE user_id = $1
            ORDER BY created_at DESC
            LIMIT 1
            """

            prefs_row = await db.fetchrow(prefs_query, user_id)
            if prefs_row:
                user_preferences = dict(prefs_row)
                if isinstance(user_preferences.get('preferred_cuisine'), str):
                    try:
                        user_preferences['preferred_cuisine'] = json.loads(user_preferences['preferred_cuisine'])
                    except:
                        user_preferences['preferred_cuisine'] = []

                sample_business = dict(sample_business_row)

                # Parse JSON fields
                if sample_business.get('categories') and isinstance(sample_business['categories'], str):
                    try:
                        sample_business['categories'] = json.loads(sample_business['categories'])
                    except:
                        sample_business['categories'] = []

                if sample_business.get('cuisines') and isinstance(sample_business['cuisines'], str):
                    try:
                        sample_business['cuisines'] = json.loads(sample_business['cuisines'])
                    except:
                        sample_business['cuisines'] = []

                # Test RL scoring
                sample_rl_score = recommendation_service.score_business_with_rl(
                    user_preferences, sample_business, metadata_preferences
                )

        return {
            "user_id": user_id,
            "rl_model_status": {
                "model_exists": model_exists,
                "model_path": recommendation_service.model_path,
                "state_dimension": recommendation_service.state_dim,
                "action_dimension": recommendation_service.action_dim,
                "model_architecture": "Actor-Critic PPO with 128 hidden units"
            },
            "training_data": {
                "total_interactions": len(interaction_data['interactions']),
                "total_likes": interaction_data['total_likes'],
                "total_dislikes": interaction_data['total_dislikes'],
                "ready_for_training": len(interaction_data['interactions']) >= 2,
                "recent_interactions": interaction_data['interactions'][:5]  # Last 5
            },
            "metadata_learning": {
                "preferences_found": len(metadata_preferences) > 0,
                "metadata_preferences": metadata_preferences
            },
            "rl_functionality": {
                "business_scoring_active": sample_rl_score is not None,
                "sample_rl_score": sample_rl_score,
                "weighted_random_selection": True,
                "duplicate_prevention": True
            },
            "system_info": {
                "pytorch_available": True,
                "gpu_available": torch.cuda.is_available() if 'torch' in globals() else False,
                "model_persistence": True,
                "auto_retraining": True
            }
        }

    except Exception as e:
        logger.error(f"Error getting RL status: {e}")
        raise HTTPException(status_code=500, detail="Failed to get RL status")


@app.get("/")
async def root():
    """Root endpoint for health check"""
    return {"message": "TRAVIA AI Travel Planner API v2.0.0", "status": "healthy"}


@app.get("/health")
async def health_check():
    """Health check endpoint for monitoring"""
    try:
        async with db_pool.acquire() as connection:
            await connection.fetchval("SELECT 1")
        return {"status": "healthy", "database": "connected"}
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        raise HTTPException(status_code=503, detail="Service unavailable")