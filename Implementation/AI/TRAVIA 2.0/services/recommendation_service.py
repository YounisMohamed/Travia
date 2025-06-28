import asyncpg
import numpy as np
import pandas as pd
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity
from sklearn.preprocessing import StandardScaler
import torch
import torch.nn as nn
import torch.optim as optim
import json
import random
from datetime import datetime
import uuid
from typing import List, Dict, Any, Optional, Tuple
import logging
import os

logger = logging.getLogger(__name__)

# PPO Agent Class - moved here from main.py for better organization
class PPOAgent(nn.Module):
    def __init__(self, state_dim, action_dim, hidden_dim=128):
        super(PPOAgent, self).__init__()
        
        # Actor network
        self.actor = nn.Sequential(
            nn.Linear(state_dim, hidden_dim),
            nn.ReLU(),
            nn.Linear(hidden_dim, hidden_dim),
            nn.ReLU(),
            nn.Linear(hidden_dim, action_dim),
            nn.Softmax(dim=-1)
        )
        
        # Critic network
        self.critic = nn.Sequential(
            nn.Linear(state_dim, hidden_dim),
            nn.ReLU(),
            nn.Linear(hidden_dim, hidden_dim),
            nn.ReLU(),
            nn.Linear(hidden_dim, 1)
        )
    
    def forward(self, state):
        action_probs = self.actor(state)
        state_value = self.critic(state)
        return action_probs, state_value

class TravelRecommendationService:
    def __init__(self):
        self.scaler = StandardScaler()
        self.tfidf_vectorizer = TfidfVectorizer(max_features=100)
        self.state_dim = 18  # Reduced from 25 to 18 due to metadata table column reduction
        self.action_dim = 2  # Like/Dislike
        
        # Initialize PPO Agent
        self.ppo_agent = PPOAgent(self.state_dim, self.action_dim)
        self.optimizer = optim.Adam(self.ppo_agent.parameters(), lr=0.001)
        self.model_path = "models/ppo_agent.pth"
        
        # Create models directory if it doesn't exist
        os.makedirs("models", exist_ok=True)
        
        # Load existing model if available
        self.load_model()
        
    def load_model(self):
        """Load trained PPO model if available"""
        try:
            if os.path.exists(self.model_path):
                checkpoint = torch.load(self.model_path)
                self.ppo_agent.load_state_dict(checkpoint['model_state_dict'])
                self.optimizer.load_state_dict(checkpoint['optimizer_state_dict'])
                logger.info("🤖 PPO model loaded successfully")
            else:
                logger.info("🤖 No existing PPO model found, starting fresh")
        except Exception as e:
            logger.error(f"Error loading PPO model: {e}")
    
    def save_model(self):
        """Save trained PPO model"""
        try:
            torch.save({
                'model_state_dict': self.ppo_agent.state_dict(),
                'optimizer_state_dict': self.optimizer.state_dict(),
            }, self.model_path)
            logger.info("🤖 PPO model saved successfully")
        except Exception as e:
            logger.error(f"Error saving PPO model: {e}")
    
    async def train_ppo_agent(self, connection: asyncpg.Connection, user_id: str):
        """Train PPO agent based on user interactions - OPTIMIZED for performance"""
        try:
            # Get user interactions with business details already included
            interaction_data = await self.get_user_interactions_data(connection, user_id)
            interactions = interaction_data['interactions']
            
            if len(interactions) < 2:
                logger.info("🤖 Not enough interactions for PPO training")
                return
            
            # Get user preferences for state creation
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
            
            prefs_row = await connection.fetchrow(prefs_query, user_id)
            if not prefs_row:
                logger.info("🤖 No user preferences found for PPO training")
                return
            
            user_preferences = dict(prefs_row)
            
            # Convert array back to list if needed
            if isinstance(user_preferences.get('preferred_cuisine'), str):
                try:
                    user_preferences['preferred_cuisine'] = json.loads(user_preferences['preferred_cuisine'])
                except:
                    user_preferences['preferred_cuisine'] = []
            
            # Get metadata preferences
            metadata_preferences = await self.analyze_user_metadata_preferences(connection, user_id)
            
            # Prepare training data - OPTIMIZED: Use business details from interactions
            states = []
            actions = []
            rewards = []
            
            for interaction in interactions:
                # Create user feature vector (state)
                user_features = self.create_user_feature_vector(user_preferences, metadata_preferences)
                
                # Create business object from interaction data (no additional DB query needed)
                business = {
                    'id': interaction['business_id'],
                    'name': interaction['business_name'],
                    'primary_category': interaction['primary_category'],
                    'cuisines': interaction['cuisines'],
                    'price_range': interaction['price_range'],
                    'stars': interaction['stars'],
                    'ambience_romantic': interaction['ambience_romantic'],
                    'ambience_classy': interaction['ambience_classy'],
                    'ambience_casual': interaction['ambience_casual'],
                    'good_for_kids': interaction['good_for_kids']
                }
                
                # Parse cuisines if needed
                if business.get('cuisines') and isinstance(business['cuisines'], str):
                    try:
                        business['cuisines'] = json.loads(business['cuisines'])
                    except:
                        business['cuisines'] = []
                
                # Create business feature vector and combine with user features
                business_features = self.create_business_feature_vector(business)
                
                # Combine user and business features for state
                # Take first 18 features to match state dimension
                combined_state = (user_features + business_features)[:self.state_dim]
                
                # Pad if needed
                while len(combined_state) < self.state_dim:
                    combined_state.append(0.0)
                
                states.append(combined_state)
                
                # Action (0 = dislike, 1 = like)
                action = 1 if interaction['interaction_type'] == 'like' else 0
                actions.append(action)
                
                # Enhanced reward calculation
                base_reward = 2.0 if action == 1 else -2.0
                
                # Cuisine learning bonus
                cuisine_bonus = 0.0
                business_cuisines = business.get('cuisines', [])
                preferred_cuisines = user_preferences.get('preferred_cuisine', [])
                
                if action == 1 and business_cuisines and preferred_cuisines:
                    # Check if business cuisine matches preferred
                    for cuisine in business_cuisines:
                        if cuisine in preferred_cuisines:
                            cuisine_bonus += 1.5  # Primary cuisine bonus
                            break
                    else:
                        # Check for secondary cuisine patterns from metadata
                        for cuisine in business_cuisines:
                            cuisine_key = f"{cuisine.lower().replace(' ', '_')}_preference"
                            if metadata_preferences.get(cuisine_key, 0) > 0.3:
                                cuisine_bonus += 0.8  # Secondary cuisine bonus
                                break
                
                # Metadata compatibility bonus
                metadata_bonus = 0.0
                if action == 1 and metadata_preferences:
                    if business.get('ambience_romantic') and metadata_preferences.get('romantic_preference', 0) > 0.5:
                        metadata_bonus += 0.5
                    if business.get('good_for_kids') and metadata_preferences.get('good_for_kids_preference', 0) > 0.5:
                        metadata_bonus += 0.5
                    if business.get('ambience_classy') and metadata_preferences.get('classy_preference', 0) > 0.5:
                        metadata_bonus += 0.5
                    if business.get('ambience_casual') and metadata_preferences.get('casual_preference', 0) > 0.5:
                        metadata_bonus += 0.5
                
                total_reward = base_reward + cuisine_bonus + metadata_bonus
                rewards.append(total_reward)
            
            if len(states) < 2:
                logger.info("🤖 Not enough valid interactions for PPO training")
                return
            
            # Convert to tensors
            states_tensor = torch.FloatTensor(states)
            actions_tensor = torch.LongTensor(actions)
            rewards_tensor = torch.FloatTensor(rewards)
            
            # Normalize rewards
            rewards_tensor = (rewards_tensor - rewards_tensor.mean()) / (rewards_tensor.std() + 1e-8)
            
            # PPO Training Loop - OPTIMIZED: Reduced epochs for faster training
            self.ppo_agent.train()
            for epoch in range(5):  # Reduced from 10 to 5 epochs for speed
                # Forward pass
                action_probs, state_values = self.ppo_agent(states_tensor)
                
                # Calculate advantages
                advantages = rewards_tensor - state_values.squeeze()
                
                # Actor loss (policy gradient with clipping)
                old_action_probs = action_probs.detach()
                action_log_probs = torch.log(action_probs.gather(1, actions_tensor.unsqueeze(1)) + 1e-8)
                old_action_log_probs = torch.log(old_action_probs.gather(1, actions_tensor.unsqueeze(1)) + 1e-8)
                
                ratio = torch.exp(action_log_probs - old_action_log_probs)
                surr1 = ratio * advantages.unsqueeze(1)
                surr2 = torch.clamp(ratio, 0.7, 1.3) * advantages.unsqueeze(1)  # epsilon = 0.3
                actor_loss = -torch.min(surr1, surr2).mean()
                
                # Critic loss (value function)
                critic_loss = nn.MSELoss()(state_values.squeeze(), rewards_tensor)
                
                # Total loss
                total_loss = actor_loss + 0.5 * critic_loss
                
                # Backward pass
                self.optimizer.zero_grad()
                total_loss.backward()
                self.optimizer.step()
            
            # Save model after training
            self.save_model()
            
            logger.info(f"🤖 PPO training completed for user {user_id} with {len(interactions)} interactions")
            logger.info(f"🤖 Final loss - Actor: {actor_loss.item():.4f}, Critic: {critic_loss.item():.4f}")
            
        except Exception as e:
            logger.error(f"Error training PPO agent: {e}")
    
    def score_business_with_rl(self, user_preferences: Dict[str, Any], business: Dict[str, Any], metadata_preferences: Optional[Dict[str, float]] = None) -> float:
        """Score a business using the trained PPO agent"""
        try:
            # Create feature vectors
            user_features = self.create_user_feature_vector(user_preferences, metadata_preferences)
            business_features = self.create_business_feature_vector(business)
            
            # Combine features for state (first 18 features)
            combined_state = (user_features + business_features)[:self.state_dim]
            
            # Pad if needed
            while len(combined_state) < self.state_dim:
                combined_state.append(0.0)
            
            # Convert to tensor
            state_tensor = torch.FloatTensor(combined_state).unsqueeze(0)
            
            # Get prediction from PPO agent
            self.ppo_agent.eval()
            with torch.no_grad():
                action_probs, state_value = self.ppo_agent(state_tensor)
                
                # Use the probability of "like" action as the score
                like_probability = action_probs[0][1].item()
                confidence_score = state_value[0].item()
                
                # Combine probability and confidence
                final_score = (like_probability * 0.7) + (confidence_score * 0.3)
                
                return max(0.0, min(1.0, final_score))  # Clamp between 0 and 1
                
        except Exception as e:
            logger.error(f"Error scoring business with RL: {e}")
            return 0.5  # Default neutral score

    def extract_cuisine_from_name(self, business_name: str) -> List[str]:
        """Extract cuisine types from business name using smart detection"""
        if not business_name:
            return []
        
        name_lower = business_name.lower()
        cuisines = []
        
        # Tea/Coffee Places
        if 'tea' in name_lower or 'teatopia' in name_lower:
            cuisines.append('Tea House')
        elif 'coffee' in name_lower or 'cafe' in name_lower or 'espresso' in name_lower or 'starbucks' in name_lower:
            cuisines.append('Coffee')
        
        # Pizza
        if 'pizza' in name_lower or 'pizzeria' in name_lower:
            cuisines.append('Pizza')
        
        # Mexican
        if any(word in name_lower for word in ['mexican', 'taco', 'burrito', 'cantina', 'chipotle']):
            cuisines.append('Mexican')
        
        # Asian Cuisines
        if 'chinese' in name_lower or 'china' in name_lower:
            cuisines.append('Chinese')
        elif 'thai' in name_lower:
            cuisines.append('Thai')
        elif any(word in name_lower for word in ['sushi', 'japanese', 'ramen']):
            cuisines.append('Japanese')
        elif 'korean' in name_lower:
            cuisines.append('Korean')
        elif 'indian' in name_lower:
            cuisines.append('Indian')
        elif any(word in name_lower for word in ['vietnamese', 'pho']):
            cuisines.append('Vietnamese')
        
        # Italian
        if any(word in name_lower for word in ['italian', 'pasta', 'trattoria']):
            cuisines.append('Italian')
        
        # Mediterranean/Middle Eastern
        if any(word in name_lower for word in ['mediterranean', 'greek']):
            cuisines.append('Mediterranean')
        elif any(word in name_lower for word in ['middle eastern', 'lebanese', 'falafel']):
            cuisines.append('Middle Eastern')
        
        # American
        if any(word in name_lower for word in ['burger', 'bbq', 'steakhouse']):
            cuisines.append('American')
        
        # Bakery/Desserts
        if any(word in name_lower for word in ['bakery', 'pastry']):
            cuisines.append('Bakery')
        elif any(word in name_lower for word in ['ice cream', 'gelato', 'frozen']):
            cuisines.append('Ice Cream')
        elif any(word in name_lower for word in ['donut', 'doughnut']):
            cuisines.append('Donuts')
        
        # Deli/Sandwiches
        if any(word in name_lower for word in ['deli', 'sandwich']):
            cuisines.append('Deli')
        
        # Health Food
        if any(word in name_lower for word in ['vegan', 'vegetarian']):
            cuisines.append('Vegetarian')
        elif any(word in name_lower for word in ['organic', 'healthy']):
            cuisines.append('Healthy')
        
        # Fast Food Chains
        if any(chain in name_lower for chain in ['mcdonald', 'burger king', 'subway', 'taco bell', 'kfc', 'wendy']):
            cuisines.append('Fast Food')
        
        return cuisines

    def _extract_keywords_from_name(self, business_name: str) -> List[str]:
        """Helper method to extract keywords from business name"""
        if not business_name:
            return []
        
        keywords = []
        name_lower = business_name.lower()
        
        # Extract specific keywords that matter for recommendations
        if 'pizza' in name_lower:
            keywords.append('pizza')
        if any(word in name_lower for word in ['ice cream', 'gelato', 'frozen yogurt']):
            keywords.append('ice_cream')
        if any(word in name_lower for word in ['coffee', 'cafe', 'espresso', 'starbucks']):
            keywords.append('coffee')
        if 'deli' in name_lower:
            keywords.append('deli')
        if 'bakery' in name_lower:
            keywords.append('bakery')
        if any(chain in name_lower for chain in ['mcdonald', 'burger king', 'subway', 'taco bell', 'kfc', 'wendy']):
            keywords.append('chain')
        if any(word in name_lower for word in ['bar', 'pub', 'tavern']):
            keywords.append('bar')
        if any(word in name_lower for word in ['fast', 'quick', 'express']):
            keywords.append('fast_food')
        
        return keywords
    
    def create_user_feature_vector(self, user_preferences: Dict[str, Any], metadata_preferences: Optional[Dict[str, float]] = None) -> List[float]:
        """Convert user preferences to feature vector including metadata preferences"""
        # Safe conversion to float
        try:
            budget = float(user_preferences.get('budget', 2)) / 4.0
            travel_days = float(user_preferences.get('travel_days', 5)) / 10.0
        except (ValueError, TypeError):
            budget = 0.5
            travel_days = 0.5
        
        features = [
            budget,  # Normalize to 0-1
            travel_days,  # Normalize
            1.0 if user_preferences.get('travel_style') == 'tourist' else 0.0,
            1.0 if user_preferences.get('noise_preference') == 'noisy' else 0.0,
            1.0 if user_preferences.get('family_friendly') else 0.0,
            1.0 if user_preferences.get('accommodation_type') == 'hotel' else 0.0,
            1.0 if user_preferences.get('accommodation_type') == 'hostel' else 0.0,
            1.0 if user_preferences.get('accommodation_type') == 'airbnb' else 0.0,
            1.0 if user_preferences.get('ambience_preference') == 'classy' else 0.0,
            1.0 if user_preferences.get('good_for_kids') else 0.0,
        ]
        
        # Add metadata preferences if available
        if metadata_preferences:
            metadata_features = [
                metadata_preferences.get('romantic_preference', 0.0),
                metadata_preferences.get('good_for_kids_preference', 0.0),
                metadata_preferences.get('classy_preference', 0.0),
                metadata_preferences.get('casual_preference', 0.0),
                metadata_preferences.get('american_preference', 0.0),
                metadata_preferences.get('chinese_preference', 0.0),
                metadata_preferences.get('italian_preference', 0.0),
                metadata_preferences.get('mexican_preference', 0.0),
            ]
            features.extend(metadata_features)
        else:
            # Add default values for metadata features (reduced from 15 to 8)
            features.extend([0.0] * 8)
        
        return features

    def create_business_feature_vector(self, business: Dict[str, Any]) -> List[float]:
        """Convert business attributes to feature vector - updated for new schema"""
        # Price range (normalize)
        price_range = business.get('price_range', 2)
        if price_range is None:
            price_range = 2
        price_normalized = float(price_range) / 4.0
        
        # Stars (normalize)
        stars = business.get('stars', 3.0)
        if stars is None:
            stars = 3.0
        stars_normalized = float(stars) / 5.0
        
        # Review count (log normalize)
        review_count = business.get('review_count', 10)
        if review_count is None or review_count <= 0:
            review_count = 10
        review_normalized = min(np.log(review_count) / 10.0, 1.0)
        
        # Category-based features (using new schema)
        categories = business.get('categories', [])
        if isinstance(categories, str):
            try:
                categories = json.loads(categories)
            except:
                categories = []
        
        primary_category = business.get('primary_category', '').lower()
        
        # Determine business type from categories and primary_category
        is_restaurant = any('restaurant' in cat.lower() or 'food' in cat.lower() for cat in categories) or 'restaurant' in primary_category
        is_cafe = any('cafe' in cat.lower() or 'coffee' in cat.lower() for cat in categories) or 'cafe' in primary_category
        is_bar = any('bar' in cat.lower() or 'nightlife' in cat.lower() for cat in categories) or 'bar' in primary_category
        is_gym = any('gym' in cat.lower() or 'fitness' in cat.lower() for cat in categories) or 'gym' in primary_category
        is_shop = any('shop' in cat.lower() or 'retail' in cat.lower() for cat in categories) or 'shop' in primary_category
        is_beauty_health = any('beauty' in cat.lower() or 'spa' in cat.lower() or 'health' in cat.lower() for cat in categories) or any(word in primary_category for word in ['beauty', 'spa', 'health'])
        is_nightlife = any('nightlife' in cat.lower() or 'club' in cat.lower() for cat in categories) or 'nightlife' in primary_category
        
        # Meal time features (these would need to be inferred or set based on category)
        good_for_breakfast = business.get('good_for_breakfast', False) or any('breakfast' in cat.lower() for cat in categories)
        good_for_lunch = business.get('good_for_lunch', True)  # Default to true for restaurants
        good_for_dinner = business.get('good_for_dinner', True)  # Default to true for restaurants
        good_for_dessert = business.get('good_for_dessert', False) or any('dessert' in cat.lower() or 'ice cream' in cat.lower() for cat in categories)
        
        # Ambience features
        ambience_classy = business.get('ambience_classy', False)
        ambience_casual = business.get('ambience_casual', True)  # Default casual
        ambience_romantic = business.get('ambience_romantic', False)
        ambience_touristy = business.get('ambience_touristy', False)
        
        # Other features
        good_for_kids = business.get('good_for_kids', False)
        has_wifi = business.get('has_wifi', False)
        has_delivery = business.get('has_delivery', False)
        serves_beer = business.get('serves_beer', False)
        
        features = [
            price_normalized,
            stars_normalized, 
            review_normalized,
            1.0 if is_restaurant else 0.0,
            1.0 if is_cafe else 0.0,
            1.0 if is_bar else 0.0,
            1.0 if is_gym else 0.0,
            1.0 if is_shop else 0.0,
            1.0 if is_beauty_health else 0.0,
            1.0 if is_nightlife else 0.0,
            1.0 if good_for_breakfast else 0.0,
            1.0 if good_for_lunch else 0.0,
            1.0 if good_for_dinner else 0.0,
            1.0 if good_for_dessert else 0.0,
            1.0 if ambience_classy else 0.0,
            1.0 if ambience_casual else 0.0,
            1.0 if ambience_romantic else 0.0,
            1.0 if ambience_touristy else 0.0,
            1.0 if good_for_kids else 0.0,
            1.0 if has_wifi else 0.0,
            1.0 if has_delivery else 0.0,
            1.0 if serves_beer else 0.0,
            0.0,  # Placeholder for future features
            0.0,  # Placeholder for future features
            0.0   # Placeholder for future features
        ]
        
        return features

    async def create_static_division_itinerary(
            self,
            connection: asyncpg.Connection,
            user_preferences: Dict[str, Any],
            businesses: List[Dict[str, Any]],
            user_id: Optional[str] = None,
    ) -> Dict[str, Any]:
        """Create itinerary using static division approach - updated for new schema"""

        travel_days = user_preferences.get('travel_days', 5)
        include_gym = user_preferences.get('include_gym', False)
        include_bar = user_preferences.get('include_bar', False)
        include_nightlife = user_preferences.get('include_nightlife', False)
        include_beauty_health = user_preferences.get('include_beauty_health', False)
        include_shop = user_preferences.get('include_shop', False)

        # Categorize businesses using new schema
        restaurants = []
        cafes = []
        bars = []
        gyms = []
        shops = []
        beauty_health = []
        nightlife = []
        dessert_places = []
        activities = []

        for business in businesses:
            name_lower = business.get('name', '').lower()
            categories = business.get('categories', [])
            primary_category = business.get('primary_category', '').lower()
            cuisines = business.get('cuisines', [])

            # Categorize based on new schema fields and categories
            if any('restaurant' in cat.lower() or 'food' in cat.lower() for cat in
                   categories) or 'restaurant' in primary_category:
                if business.get('good_for_breakfast'):
                    restaurants.append({**business, 'meal_type': 'breakfast'})
                if business.get('good_for_lunch', True):
                    restaurants.append({**business, 'meal_type': 'lunch'})
                if business.get('good_for_dinner', True):
                    restaurants.append({**business, 'meal_type': 'dinner'})

            # Cafes
            if any('cafe' in cat.lower() or 'coffee' in cat.lower() for cat in
                   categories) or 'cafe' in primary_category or 'coffee' in name_lower:
                cafes.append(business)

            # Dessert places
            if (business.get('good_for_dessert') or
                    any('dessert' in cat.lower() or 'ice cream' in cat.lower() or 'bakery' in cat.lower() for cat in
                        categories) or
                    any(word in name_lower for word in ['ice cream', 'gelato', 'bakery', 'dessert'])):
                dessert_places.append(business)

            # Bars
            if any('bar' in cat.lower() or 'nightlife' in cat.lower() for cat in
                   categories) or 'bar' in primary_category:
                bars.append(business)

            # Gyms
            if any('gym' in cat.lower() or 'fitness' in cat.lower() for cat in categories) or 'gym' in primary_category:
                gyms.append(business)

            # Shops
            if any('shop' in cat.lower() or 'retail' in cat.lower() for cat in
                   categories) or 'shop' in primary_category:
                shops.append(business)

            # Beauty & Health
            if any('beauty' in cat.lower() or 'spa' in cat.lower() or 'health' in cat.lower() for cat in categories):
                beauty_health.append(business)

            # Nightlife
            if any('nightlife' in cat.lower() or 'club' in cat.lower() for cat in
                   categories) or 'nightlife' in primary_category:
                nightlife.append(business)

        # Get metadata preferences for RL scoring
        metadata_preferences = None
        if user_id:
            try:
                metadata_preferences = await self.analyze_user_metadata_preferences(connection, user_id)
            except:
                pass

        # Helper function to rank businesses using RL
        def rank_businesses_with_rl(business_list, limit):
            if not business_list:
                return []

            # Score each business with RL
            scored_businesses = []
            for business in business_list:
                rl_score = self.score_business_with_rl(user_preferences, business, metadata_preferences)
                scored_businesses.append((business, rl_score))

            # Sort by RL score (highest first) and take top results
            scored_businesses.sort(key=lambda x: x[1], reverse=True)

            # Add some randomness to avoid always picking the same businesses
            top_candidates = scored_businesses[:min(len(scored_businesses), limit * 2)]

            # Use weighted random selection from top candidates
            if len(top_candidates) <= limit:
                return [business for business, score in top_candidates]
            else:
                # Select with probability based on RL scores
                weights = [score + 0.1 for business, score in top_candidates]  # Add small baseline
                selected = []
                available = top_candidates.copy()

                for _ in range(min(limit, len(available))):
                    if not available:
                        break

                    # Weighted random selection
                    total_weight = sum(w for _, w in zip(available, weights[:len(available)]))
                    if total_weight <= 0:
                        selected.append(available.pop(0)[0])
                        continue

                    rand_val = random.random() * total_weight
                    cumsum = 0
                    for i, (business, score) in enumerate(available):
                        cumsum += weights[i]
                        if rand_val <= cumsum:
                            selected.append(business)
                            available.pop(i)
                            weights.pop(i)
                            break

                return selected

        # Create itinerary with RL-based business ranking
        itinerary = []
        used_businesses = set()  # Track used businesses to avoid duplicates

        for day in range(1, travel_days + 1):
            day_plan = {
                'day': day,
                'breakfast': [],
                'lunch': [],
                'dinner': [],
                'activities': [],
                'dessert': []
            }

            # Breakfast (cafes or breakfast restaurants) - RL ranked
            breakfast_options = [r for r in restaurants if
                                 r.get('meal_type') == 'breakfast' and r['id'] not in used_businesses] + \
                                [c for c in cafes if c['id'] not in used_businesses]
            if breakfast_options:
                selected_breakfast = rank_businesses_with_rl(breakfast_options, 2)
                day_plan['breakfast'] = selected_breakfast
                for b in selected_breakfast:
                    used_businesses.add(b['id'])
                logger.info(f"🤖 Day {day} breakfast: Selected {len(selected_breakfast)} businesses using RL")

            # Lunch - RL ranked
            lunch_options = [r for r in restaurants if r.get('meal_type') == 'lunch' and r['id'] not in used_businesses]
            if lunch_options:
                selected_lunch = rank_businesses_with_rl(lunch_options, 3)
                day_plan['lunch'] = selected_lunch
                for b in selected_lunch:
                    used_businesses.add(b['id'])
                logger.info(f"🤖 Day {day} lunch: Selected {len(selected_lunch)} businesses using RL")

            # Dinner - RL ranked
            dinner_options = [r for r in restaurants if
                              r.get('meal_type') == 'dinner' and r['id'] not in used_businesses]
            if dinner_options:
                selected_dinner = rank_businesses_with_rl(dinner_options, 3)
                day_plan['dinner'] = selected_dinner
                for b in selected_dinner:
                    used_businesses.add(b['id'])
                logger.info(f"🤖 Day {day} dinner: Selected {len(selected_dinner)} businesses using RL")

            # Activities based on preferences - RL ranked
            day_activities = []

            if include_gym and gyms:
                available_gyms = [g for g in gyms if g['id'] not in used_businesses]
                if available_gyms:
                    selected_gyms = rank_businesses_with_rl(available_gyms, 1)
                    day_activities.extend(selected_gyms)
                    for g in selected_gyms:
                        used_businesses.add(g['id'])

            if include_shop and shops:
                available_shops = [s for s in shops if s['id'] not in used_businesses]
                if available_shops:
                    selected_shops = rank_businesses_with_rl(available_shops, 2)
                    day_activities.extend(selected_shops)
                    for s in selected_shops:
                        used_businesses.add(s['id'])

            if include_beauty_health and beauty_health:
                available_bh = [bh for bh in beauty_health if bh['id'] not in used_businesses]
                if available_bh:
                    selected_bh = rank_businesses_with_rl(available_bh, 1)
                    day_activities.extend(selected_bh)
                    for bh in selected_bh:
                        used_businesses.add(bh['id'])

            if include_bar and bars:
                available_bars = [b for b in bars if b['id'] not in used_businesses]
                if available_bars:
                    selected_bars = rank_businesses_with_rl(available_bars, 1)
                    day_activities.extend(selected_bars)
                    for b in selected_bars:
                        used_businesses.add(b['id'])

            if include_nightlife and nightlife:
                available_nightlife = [n for n in nightlife if n['id'] not in used_businesses]
                if available_nightlife:
                    selected_nightlife = rank_businesses_with_rl(available_nightlife, 1)
                    day_activities.extend(selected_nightlife)
                    for n in selected_nightlife:
                        used_businesses.add(n['id'])

            day_plan['activities'] = day_activities

            # Dessert - RL ranked
            available_desserts = [d for d in dessert_places if d['id'] not in used_businesses]
            if available_desserts:
                selected_desserts = rank_businesses_with_rl(available_desserts, 2)
                day_plan['dessert'] = selected_desserts
                for d in selected_desserts:
                    used_businesses.add(d['id'])
                logger.info(f"🤖 Day {day} dessert: Selected {len(selected_desserts)} businesses using RL")

            itinerary.append(day_plan)

        return {
            'itinerary': itinerary,
            'total_businesses': len(businesses),
            'user_preferences': user_preferences
        }

    async def analyze_user_metadata_preferences(self, connection: asyncpg.Connection, user_id: str) -> Dict[str, float]:
        """
        Analyze user's liked posts to extract metadata preferences
        This is HOW THE AI KNOWS what the user likes based on post metadata
        OPTIMIZED: Limited to recent likes for better performance
        """
        try:
            # Query to get metadata from recent posts the user has liked (limited for performance)
            query = """
            SELECT m.romantic, m.good_for_kids, m.classy, m.casual, m.cuisine_types
            FROM likes l
            JOIN metadata m ON l.post_id = m.post_id
            WHERE l.liker_user_id = $1 AND l.type = 'like'
            ORDER BY l.created_at DESC
            LIMIT 30
            """
            
            rows = await connection.fetch(query, user_id)
            
            if not rows or len(rows) < 2:  # Need at least 2 likes for meaningful analysis
                return {}
            
            total_likes = len(rows)
            preferences = {}
            
            # Calculate preference scores for each metadata attribute
            # This is the AI learning from user behavior!
            
            # Binary attributes (0/1 values) - updated to only include remaining columns
            binary_attributes = ['romantic', 'good_for_kids', 'classy', 'casual']
            
            for attr in binary_attributes:
                positive_count = sum(1 for row in rows if row[attr] == 1)
                preference_score = positive_count / total_likes
                preferences[f"{attr}_preference"] = preference_score
            
            # Cuisine preferences with enhancement boost
            cuisine_counts = {}
            for row in rows:
                cuisine = row['cuisine_type']
                if cuisine:
                    cuisine_counts[cuisine] = cuisine_counts.get(cuisine, 0) + 1
            
            for cuisine, count in cuisine_counts.items():
                preference_score = count / total_likes
                # ENHANCED: 1.5x boost for strong patterns (>30% frequency)
                if preference_score > 0.3:
                    preference_score *= 1.5
                    preference_score = min(preference_score, 1.0)  # Cap at 1.0
                
                cuisine_clean = cuisine.lower().replace(' ', '_')
                preferences[f"{cuisine_clean}_preference"] = preference_score
            
            return preferences
            
        except Exception as e:
            print(f"Error analyzing metadata preferences: {e}")
            return {}

    async def get_user_interactions_data(self, connection: asyncpg.Connection, user_id: str) -> Dict[str, Any]:
        """
        Get user's interaction data for reinforcement learning
        This feeds the PPO Agent with like/dislike patterns
        OPTIMIZED: Single query with business details to avoid N+1 problem
        """
        try:
            query = """
            SELECT ui.business_id, ui.interaction_type, ui.context_preferences, ui.created_at,
                   b.name, b.primary_category, b.cuisines, b.price_range, b.stars,
                   b.ambience_romantic, b.ambience_classy, b.ambience_casual, b.good_for_kids
            FROM user_interactions ui
            JOIN businesses b ON ui.business_id = b.id
            WHERE ui.user_id = $1
            ORDER BY ui.created_at DESC
            LIMIT 50
            """
            
            rows = await connection.fetch(query, user_id)
            
            interactions = []
            for row in rows:
                interaction = {
                    'business_id': row['business_id'],
                    'interaction_type': row['interaction_type'],
                    'business_name': row['name'],
                    'primary_category': row['primary_category'],
                    'cuisines': row['cuisines'],
                    'price_range': row['price_range'],
                    'stars': row['stars'],
                    'created_at': row['created_at'],
                    # Include business details for faster processing
                    'ambience_romantic': row['ambience_romantic'],
                    'ambience_classy': row['ambience_classy'],
                    'ambience_casual': row['ambience_casual'],
                    'good_for_kids': row['good_for_kids']
                }
                
                # Parse context preferences if available
                if row['context_preferences']:
                    try:
                        if isinstance(row['context_preferences'], str):
                            interaction['context_preferences'] = json.loads(row['context_preferences'])
                        else:
                            interaction['context_preferences'] = row['context_preferences']
                    except:
                        interaction['context_preferences'] = {}
                
                interactions.append(interaction)
            
            return {
                'interactions': interactions,
                'total_likes': sum(1 for i in interactions if i['interaction_type'] == 'like'),
                'total_dislikes': sum(1 for i in interactions if i['interaction_type'] == 'dislike'),
            }
            
        except Exception as e:
            print(f"Error getting user interactions: {e}")
            return {'interactions': [], 'total_likes': 0, 'total_dislikes': 0}

    async def get_available_locations(self, connection: asyncpg.Connection) -> List[Dict[str, Any]]:
        """Get available locations from businesses table - updated for new schema"""
        try:
            query = """
            SELECT city as locality, region, country, COUNT(*) as business_count
            FROM businesses
            WHERE city IS NOT NULL AND region IS NOT NULL
            AND name IS NOT NULL AND name != ''
            GROUP BY city, region, country
            HAVING COUNT(*) >= 10
            ORDER BY business_count DESC, city ASC
            """

            rows = await connection.fetch(query)
            locations = []

            for row in rows:
                locations.append({
                    'locality': row['locality'],
                    'region': row['region'],
                    'country': row['country'],
                    'business_count': row['business_count']
                })

            return locations

        except Exception as e:
            logger.error(f"Error fetching locations: {e}")
            return []

    async def get_businesses_by_location_and_filters(
            self,
            connection: asyncpg.Connection,
            locality: str,
            user_preferences: Dict[str, Any],
            limit: int = 1000
    ) -> List[Dict[str, Any]]:
        """Get businesses filtered by location and user preferences - updated for new schema"""

        # Base query with new schema columns
        base_query = """
        SELECT id, business_id, name, address, latitude, longitude, locality, region, country, city,
       stars, review_count, price_range, primary_category, categories, cuisines, 
       phone, website, photos, accepts_credit_cards, payment_options, 
       serves_beer, has_delivery, has_wifi,
       good_for_breakfast, good_for_lunch, good_for_dinner, good_for_dessert,
       ambience_classy, ambience_casual, ambience_romantic, ambience_touristy, ambience_trendy,
       good_for_kids, hours_monday, hours_tuesday, hours_wednesday, hours_thursday,
       hours_friday, hours_saturday, hours_sunday,
       is_bar, is_nightlife, is_beauty_health, is_cafe, is_gym, is_restaurant, is_shop
FROM businesses 
WHERE city = $1
AND (stars >= 3.0 OR stars IS NULL)
AND name IS NOT NULL AND name != ''
"""

        params = [locality]
        param_count = 1

        # Add cuisine filtering if specified
        preferred_cuisine = user_preferences.get('preferred_cuisine', [])
        if preferred_cuisine:
            cuisine_conditions = []
            for cuisine in preferred_cuisine:
                param_count += 1
                # Use array containment operator to check if cuisine is in the array (case-insensitive)
                cuisine_conditions.append(f"EXISTS(SELECT 1 FROM unnest(cuisines) AS c WHERE LOWER(c) = LOWER(${param_count}))")
                params.append(cuisine)

            if cuisine_conditions:
                base_query += f" AND ({' OR '.join(cuisine_conditions)})"

        # Add ordering and limit
        base_query += " ORDER BY stars DESC NULLS LAST, review_count DESC"

        if limit:
            param_count += 1
            base_query += f" LIMIT ${param_count}"
            params.append(limit)

        try:
            rows = await connection.fetch(base_query, *params)
            businesses = []

            for row in rows:
                business = dict(row)

                # Parse JSON fields
                if business.get('categories') and isinstance(business['categories'], str):
                    try:
                        business['categories'] = json.loads(business['categories'])
                    except:
                        business['categories'] = []

                if business.get('cuisines') and isinstance(business['cuisines'], str):
                    try:
                        business['cuisines'] = json.loads(business['cuisines'])
                    except:
                        business['cuisines'] = []

                if business.get('photos') and isinstance(business['photos'], str):
                    try:
                        business['photos'] = json.loads(business['photos'])
                    except:
                        business['photos'] = []

                if business.get('payment_options') and isinstance(business['payment_options'], str):
                    try:
                        business['payment_options'] = json.loads(business['payment_options'])
                    except:
                        business['payment_options'] = {}

                businesses.append(business)

            return businesses

        except Exception as e:
            logger.error(f"Error fetching businesses: {e}")
            return []

    async def get_businesses_similar_to_liked(self, connection: asyncpg.Connection, user_id: str, locality: str, limit: int = 100) -> List[Dict[str, Any]]:
        """
        Get businesses similar to what the user has liked before
        This ensures interactions are considered in business selection
        """
        try:
            # Get user's liked businesses to find patterns
            liked_query = """
            SELECT DISTINCT b.cuisines, b.ambience_romantic, b.ambience_classy, b.ambience_casual, 
                   b.good_for_kids, b.price_range, b.stars, b.primary_category, ui.created_at
            FROM user_interactions ui
            JOIN businesses b ON ui.business_id = b.id
            WHERE ui.user_id = $1
              AND ui.interaction_type = 'like'
              AND ui.created_at = (
                  SELECT MAX(ui2.created_at)
                  FROM user_interactions ui2
                  WHERE ui2.user_id = ui.user_id AND ui2.business_id = ui.business_id
              )
              AND b.city = $2
            ORDER BY ui.created_at DESC
            LIMIT 20
            """
            
            liked_rows = await connection.fetch(liked_query, user_id, locality)
            
            if not liked_rows:
                return []
            
            # Extract patterns from liked businesses
            liked_cuisines = set()
            liked_ambience_romantic = 0
            liked_ambience_classy = 0
            liked_ambience_casual = 0
            liked_good_for_kids = 0
            avg_price_range = 0
            avg_stars = 0
            
            for row in liked_rows:
                if row['cuisines']:
                    try:
                        cuisines = json.loads(row['cuisines']) if isinstance(row['cuisines'], str) else row['cuisines']
                        liked_cuisines.update(cuisines)
                    except:
                        pass
                
                if row['ambience_romantic']:
                    liked_ambience_romantic += 1
                if row['ambience_classy']:
                    liked_ambience_classy += 1
                if row['ambience_casual']:
                    liked_ambience_casual += 1
                if row['good_for_kids']:
                    liked_good_for_kids += 1
                
                avg_price_range += row['price_range'] or 2
                avg_stars += row['stars'] or 3.5
            
            total_liked = len(liked_rows)
            if total_liked == 0:
                return []
            
            # Log what cuisines the user liked
            logger.info(f"🎯 User {user_id} liked businesses with cuisines: {list(liked_cuisines)}")
            
            # Calculate preferences
            romantic_pref = liked_ambience_romantic / total_liked > 0.3
            classy_pref = liked_ambience_classy / total_liked > 0.3
            casual_pref = liked_ambience_casual / total_liked > 0.3
            kids_pref = liked_good_for_kids / total_liked > 0.3
            avg_price = avg_price_range / total_liked
            avg_star = avg_stars / total_liked
            
            # Build query to find similar businesses
            similar_query = """
            SELECT id, business_id, name, address, latitude, longitude, locality, region, country, city,
                   stars, review_count, price_range, primary_category, categories, cuisines, 
                   phone, website, photos, accepts_credit_cards, payment_options, 
                   serves_beer, has_delivery, has_wifi,
                   good_for_breakfast, good_for_lunch, good_for_dinner, good_for_dessert,
                   ambience_classy, ambience_casual, ambience_romantic, ambience_touristy, ambience_trendy,
                   good_for_kids, hours_monday, hours_tuesday, hours_wednesday, hours_thursday,
                   hours_friday, hours_saturday, hours_sunday,
                   is_bar, is_nightlife, is_beauty_health, is_cafe, is_gym, is_restaurant, is_shop
            FROM businesses 
            WHERE city = $1
            AND (stars >= 3.0 OR stars IS NULL)
            AND name IS NOT NULL AND name != ''
            AND id NOT IN (
                SELECT business_id FROM user_interactions WHERE user_id = $2 AND (interaction_type = 'like' OR interaction_type = 'dislike')
            )
            """
            
            params = [locality, user_id]
            param_count = 2
            conditions = []
            
            # PRIORITY 1: Cuisine matching (most important)
            if liked_cuisines:
                cuisine_conditions = []
                for cuisine in list(liked_cuisines)[:5]:  # Limit to top 5 cuisines
                    param_count += 1
                    # Use array containment operator for exact cuisine matching (case-insensitive)
                    cuisine_conditions.append(f"EXISTS(SELECT 1 FROM unnest(cuisines) AS c WHERE LOWER(c) = LOWER(${param_count}))")
                    params.append(cuisine)
                
                if cuisine_conditions:
                    conditions.append(f"({' OR '.join(cuisine_conditions)})")
            
            # PRIORITY 2: Ambience preferences (secondary)
            ambience_conditions = []
            if romantic_pref:
                ambience_conditions.append("ambience_romantic = true")
            if classy_pref:
                ambience_conditions.append("ambience_classy = true")
            if casual_pref:
                ambience_conditions.append("ambience_casual = true")
            if kids_pref:
                ambience_conditions.append("good_for_kids = true")
            
            # PRIORITY 3: Price and stars (tertiary)
            price_star_conditions = []
            price_star_conditions.append(f"ABS(COALESCE(price_range, 2) - {avg_price:.1f}) <= 1")
            price_star_conditions.append(f"ABS(COALESCE(stars, 3.5) - {avg_star:.1f}) <= 1.0")
            
            # Combine conditions with proper priority
            if conditions:
                # Start with cuisine (most important)
                similar_query += f" AND ({' OR '.join(conditions)})"
                
                # Add ambience if available
                if ambience_conditions:
                    similar_query += f" AND ({' OR '.join(ambience_conditions)})"
                
                # Add price/stars if available
                if price_star_conditions:
                    similar_query += f" AND ({' AND '.join(price_star_conditions)})"
            
            similar_query += f" ORDER BY stars DESC NULLS LAST, review_count DESC LIMIT ${param_count + 1}"
            params.append(limit)
            
            rows = await connection.fetch(similar_query, *params)
            businesses = []
            
            for row in rows:
                business = dict(row)
                
                # Parse JSON fields
                if business.get('categories') and isinstance(business['categories'], str):
                    try:
                        business['categories'] = json.loads(business['categories'])
                    except:
                        business['categories'] = []
                
                if business.get('cuisines') and isinstance(business['cuisines'], str):
                    try:
                        business['cuisines'] = json.loads(business['cuisines'])
                    except:
                        business['cuisines'] = []
                
                if business.get('photos') and isinstance(business['photos'], str):
                    try:
                        business['photos'] = json.loads(business['photos'])
                    except:
                        business['photos'] = []
                
                if business.get('payment_options') and isinstance(business['payment_options'], str):
                    try:
                        business['payment_options'] = json.loads(business['payment_options'])
                    except:
                        business['payment_options'] = {}
                
                businesses.append(business)
            
            logger.info(f"🎯 Found {len(businesses)} businesses similar to what user {user_id} liked before")
            return businesses
            
        except Exception as e:
            logger.error(f"Error getting similar businesses: {e}")
            return []

    async def get_balanced_businesses_with_variety(
            self,
            connection: asyncpg.Connection,
            locality: str,
            user_preferences: Dict[str, Any],
            limit: int = 250,
            user_id: Optional[str] = None
    ) -> List[Dict[str, Any]]:
        """
        Get businesses with 70/30 balance: 70% preferred cuisine, 30% variety
        Implements the balanced variety/bias selection system from AI architecture
        """

        preferred_cuisine = user_preferences.get('preferred_cuisine', [])  # Keep original case
        preferred_limit = int(limit * 0.7)
        variety_limit = limit - preferred_limit  # ensure total = limit

        base_query_template = """
        SELECT id, business_id, name, address, latitude, longitude, locality, region, country, city,
       stars, review_count, price_range, primary_category, categories, cuisines, 
       phone, website, photos, accepts_credit_cards, payment_options, 
       serves_beer, has_delivery, has_wifi,
       good_for_breakfast, good_for_lunch, good_for_dinner, good_for_dessert,
       ambience_classy, ambience_casual, ambience_romantic, ambience_touristy, ambience_trendy,
       good_for_kids, hours_monday, hours_tuesday, hours_wednesday, hours_thursday,
       hours_friday, hours_saturday, hours_sunday,
       is_bar, is_nightlife, is_beauty_health, is_cafe, is_gym, is_restaurant, is_shop
FROM businesses 
WHERE city = $1
AND (stars >= 3.0 OR stars IS NULL)
AND name IS NOT NULL AND name != ''
"""

        preferred_businesses = []
        variety_businesses = []

        try:
            if preferred_cuisine:
                # Preferred cuisine businesses (70%) - STRICT filtering
                preferred_query = base_query_template
                cuisine_conditions = []
                params = [locality]
                param_count = 1

                for cuisine in preferred_cuisine:
                    param_count += 1
                    # Use array containment operator to check if cuisine is in the array (case-insensitive)
                    cuisine_conditions.append(f"EXISTS(SELECT 1 FROM unnest(cuisines) AS c WHERE LOWER(c) = LOWER(${param_count}))")
                    params.append(cuisine)

                if cuisine_conditions:
                    preferred_query += f" AND ({' OR '.join(cuisine_conditions)})"

                preferred_query += f" ORDER BY stars DESC NULLS LAST, review_count DESC LIMIT ${param_count + 1}"
                params.append(preferred_limit)

                preferred_rows = await connection.fetch(preferred_query, *params)
                preferred_businesses = [dict(row) for row in preferred_rows]

                # Include businesses that have the preferred cuisine (keep all their cuisines)
                filtered_preferred_businesses = []
                for business in preferred_businesses:
                    business_cuisines = business.get('cuisines', [])
                    if isinstance(business_cuisines, str):
                        try:
                            business_cuisines = json.loads(business_cuisines)
                        except:
                            business_cuisines = []
                    
                    # Debug: Log the business being processed
                    logger.debug(f"Processing business: {business.get('name')} with cuisines: {business_cuisines}")
                    
                    # Check if this business has the preferred cuisine (case-insensitive)
                    has_preferred = any(cuisine.lower() in [c.lower() for c in preferred_cuisine] for cuisine in business_cuisines)
                    logger.debug(f"Has preferred cuisine {preferred_cuisine}: {has_preferred}")
                    
                    if has_preferred:
                        # Include the business with all its original cuisines
                        filtered_preferred_businesses.append(business)
                        logger.debug(f"Added to preferred businesses: {business['name']} with cuisines: {business['cuisines']}")
                    else:
                        logger.debug(f"Excluded from preferred businesses: {business.get('name')}")
                
                preferred_businesses = filtered_preferred_businesses
                
                # Debug logging
                logger.info(f"🔍 Found {len(preferred_businesses)} businesses after filtering for cuisines: {preferred_cuisine}")

                # Variety businesses (30%) - EXCLUDE preferred cuisines
                variety_query = base_query_template
                variety_params = [locality]
                variety_param_count = 1
                
                # Add exclusion for preferred cuisines
                if preferred_cuisine:
                    exclusion_conditions = []
                    for cuisine in preferred_cuisine:
                        variety_param_count += 1
                        # Use array containment operator for exclusion (case-insensitive)
                        exclusion_conditions.append(f"NOT EXISTS(SELECT 1 FROM unnest(cuisines) AS c WHERE LOWER(c) = LOWER(${variety_param_count}))")
                        variety_params.append(cuisine)
                    
                    if exclusion_conditions:
                        variety_query += f" AND ({' AND '.join(exclusion_conditions)})"
                
                variety_query += f" ORDER BY RANDOM() LIMIT ${variety_param_count + 1}"
                variety_params.append(variety_limit)

                variety_rows = await connection.fetch(variety_query, *variety_params)
                variety_businesses = [dict(row) for row in variety_rows]
            else:
                # No explicit preferences: balance between similar businesses and variety
                if user_id:
                    # Get businesses similar to what the user liked (70%)
                    similar_limit = int(limit * 0.7)
                    variety_limit = limit - similar_limit
                    
                    similar_businesses = await self.get_businesses_similar_to_liked(connection, user_id, locality, similar_limit)
                    
                    if similar_businesses:
                        # Get variety businesses (30%) - different from what user liked
                        variety_query = base_query_template
                        variety_params = [locality]
                        variety_query += f" ORDER BY RANDOM() LIMIT $2"
                        variety_params.append(variety_limit)
                        
                        variety_rows = await connection.fetch(variety_query, *variety_params)
                        variety_businesses = [dict(row) for row in variety_rows]
                        
                        # Combine similar + variety
                        all_businesses = similar_businesses + variety_businesses
                        
                        # Parse JSON fields for variety businesses
                        for business in variety_businesses:
                            if business.get('categories') and isinstance(business['categories'], str):
                                try:
                                    business['categories'] = json.loads(business['categories'])
                                except:
                                    business['categories'] = []
                            
                            if business.get('cuisines') and isinstance(business['cuisines'], str):
                                try:
                                    business['cuisines'] = json.loads(business['cuisines'])
                                except:
                                    business['cuisines'] = []
                            
                            if business.get('photos') and isinstance(business['photos'], str):
                                try:
                                    business['photos'] = json.loads(business['photos'])
                                except:
                                    business['photos'] = []
                            
                            if business.get('payment_options') and isinstance(business['payment_options'], str):
                                try:
                                    business['payment_options'] = json.loads(business['payment_options'])
                                except:
                                    business['payment_options'] = {}
                        
                        logger.info(f"🎯 Using {len(similar_businesses)} similar + {len(variety_businesses)} variety businesses (balanced approach)")
                        return all_businesses
                    else:
                        # Fallback to metadata preferences if no similar businesses found
                        metadata_preferences = await self.analyze_user_metadata_preferences(connection, user_id)
                        
                        if metadata_preferences:
                            # Use metadata preferences to find businesses similar to liked ones
                            metadata_query = base_query_template
                            metadata_conditions = []
                            params = [locality]
                            param_count = 1
                            
                            # Add conditions based on metadata preferences
                            if metadata_preferences.get('romantic_preference', 0) > 0.3:
                                param_count += 1
                                metadata_conditions.append(f"ambience_romantic = true")
                            
                            if metadata_preferences.get('good_for_kids_preference', 0) > 0.3:
                                param_count += 1
                                metadata_conditions.append(f"good_for_kids = true")
                            
                            if metadata_preferences.get('classy_preference', 0) > 0.3:
                                param_count += 1
                                metadata_conditions.append(f"ambience_classy = true")
                            
                            if metadata_preferences.get('casual_preference', 0) > 0.3:
                                param_count += 1
                                metadata_conditions.append(f"ambience_casual = true")
                            
                            # Add cuisine preferences from metadata
                            cuisine_conditions = []
                            for cuisine_key, preference_score in metadata_preferences.items():
                                if cuisine_key.endswith('_preference') and preference_score > 0.3:
                                    cuisine_name = cuisine_key.replace('preference', '').replace('', ' ')
                                    param_count += 1
                                    cuisine_conditions.append(f"EXISTS(SELECT 1 FROM unnest(cuisines) AS c WHERE LOWER(c) = LOWER(${param_count}))")
                                    params.append(cuisine_name)
                            
                            if cuisine_conditions:
                                metadata_conditions.append(f"({' OR '.join(cuisine_conditions)})")
                            
                            if metadata_conditions:
                                metadata_query += f" AND ({' OR '.join(metadata_conditions)})"
                                metadata_query += f" ORDER BY stars DESC NULLS LAST, review_count DESC LIMIT ${param_count + 1}"
                                params.append(limit)
                                
                                metadata_rows = await connection.fetch(metadata_query, *params)
                                variety_businesses = [dict(row) for row in metadata_rows]
                                
                                logger.info(f"🎯 Using metadata preferences to find {len(variety_businesses)} businesses similar to liked ones")
                            else:
                                # Fallback to general selection if no strong metadata patterns
                                general_query = base_query_template + f" ORDER BY stars DESC NULLS LAST, review_count DESC LIMIT $2"
                                rows = await connection.fetch(general_query, locality, limit)
                                variety_businesses = [dict(row) for row in rows]
                                logger.info(f"📊 No strong metadata patterns found, using general selection")
                        else:
                            # No metadata preferences: general selection
                            general_query = base_query_template + f" ORDER BY stars DESC NULLS LAST, review_count DESC LIMIT $2"
                            rows = await connection.fetch(general_query, locality, limit)
                            variety_businesses = [dict(row) for row in rows]
                            logger.info(f"📊 No metadata preferences found, using general selection")
                else:
                    # No user_id: general selection
                    general_query = base_query_template + f" ORDER BY stars DESC NULLS LAST, review_count DESC LIMIT $2"
                    rows = await connection.fetch(general_query, locality, limit)
                    variety_businesses = [dict(row) for row in rows]
                    logger.info(f"📊 No user_id provided, using general selection")

            all_businesses = preferred_businesses + variety_businesses

            # Fallback if no results found
            if not all_businesses:
                logger.warning(f"⚠ No businesses found in balanced fetch — falling back to general filter.")
                return await self.get_businesses_by_location_and_filters(
                    connection, locality, user_preferences, limit
                )

            for business in all_businesses:
                if business.get('categories') and isinstance(business['categories'], str):
                    try:
                        business['categories'] = json.loads(business['categories'])
                    except:
                        business['categories'] = []

                if business.get('cuisines') and isinstance(business['cuisines'], str):
                    try:
                        business['cuisines'] = json.loads(business['cuisines'])
                    except:
                        business['cuisines'] = []

                if business.get('photos') and isinstance(business['photos'], str):
                    try:
                        business['photos'] = json.loads(business['photos'])
                    except:
                        business['photos'] = []

                if business.get('payment_options') and isinstance(business['payment_options'], str):
                    try:
                        business['payment_options'] = json.loads(business['payment_options'])
                    except:
                        business['payment_options'] = {}

            # Logging
            preferred_count = len(preferred_businesses)
            variety_count = len(variety_businesses)
            total_count = len(all_businesses)

            if total_count > 0:
                preferred_percentage = (preferred_count / total_count) * 100
                variety_percentage = (variety_count / total_count) * 100

                logger.info(
                    f"🍽 Cuisine Balance: {preferred_count} preferred ({preferred_percentage:.1f}%) + {variety_count} variety ({variety_percentage:.1f}%) = {total_count} total")

                # FIXED: Distinguish between user's explicit preferences and selected business cuisines
                user_explicit_cuisines = user_preferences.get('preferred_cuisine', [])
                if user_explicit_cuisines:
                    logger.info(f"👤 User's explicit cuisine preference: {user_explicit_cuisines}")
                else:
                    logger.info(f"👤 User has no explicit cuisine preference - using interaction-based selection")

                # Show cuisines of selected businesses (not user preferences)
                selected_business_cuisines = set()
                variety_business_cuisines = set()

                for business in preferred_businesses:
                    if business.get('cuisines'):
                        selected_business_cuisines.update(business['cuisines'])

                for business in variety_businesses:
                    if business.get('cuisines'):
                        variety_business_cuisines.update(business['cuisines'])

                logger.info(f"🏪 Cuisines of selected preferred businesses: {list(selected_business_cuisines)}")
                logger.info(f"📊 Cuisines of selected variety businesses: {list(variety_business_cuisines)}")

            return all_businesses

        except Exception as e:
            logger.error(f"Error fetching balanced businesses: {e}")
            return await self.get_businesses_by_location_and_filters(
                connection, locality, user_preferences, limit
            )