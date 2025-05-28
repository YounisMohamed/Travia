from flask import Flask, render_template, request, jsonify, session, redirect
import psycopg2
import psycopg2.extras
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

app = Flask(__name__)
app.secret_key = 'your-secret-key-here'

# Database configuration - PORT 5433!
DB_CONFIG = {
    'host': 'localhost',
    'database': 'traviadb',
    'user': 'postgres',
    'password': '1234',
    'port': 5433
}

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

class TravelRecommendationSystem:
    def __init__(self):
        self.scaler = StandardScaler()
        self.tfidf_vectorizer = TfidfVectorizer(max_features=100)
        self.ppo_agent = None
        self.state_dim = 20  # Adjust based on feature engineering
        self.action_dim = 2  # Like/Dislike
        
    def get_db_connection(self):
        return psycopg2.connect(**DB_CONFIG)
    
    def extract_cuisine_from_name(self, business_name):
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

    def _extract_keywords_from_name(self, business_name):
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
    
    def create_user_feature_vector(self, user_preferences):
        """Convert user preferences to feature vector"""
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
        
        # Add padding to reach state_dim
        while len(features) < self.state_dim:
            features.append(0.0)
        
        return np.array(features[:self.state_dim])
    
    def create_business_feature_vector(self, business):
        """Convert business data to feature vector"""
        # Safe conversion of Decimal to float
        try:
            stars = float(business.get('stars', 3.0)) if business.get('stars') is not None else 3.0
            review_count = float(business.get('review_count', 0)) if business.get('review_count') is not None else 0.0
            price_range = float(business.get('price_range', 2)) if business.get('price_range') is not None else 2.0
        except (ValueError, TypeError):
            stars = 3.0
            review_count = 0.0
            price_range = 2.0
        
        features = [
            stars / 5.0,
            min(review_count, 1000) / 1000.0,
            price_range / 4.0 if price_range else 0.5,
            1.0 if business.get('good_for_kids') else 0.0,
            1.0 if business.get('ambience_classy') else 0.0,
            1.0 if business.get('ambience_casual') else 0.0,
            1.0 if business.get('is_restaurant') else 0.0,
            1.0 if business.get('is_cafe') else 0.0,
            1.0 if business.get('outdoor_seating') else 0.0,
            1.0 if business.get('wifi') else 0.0,
        ]
        
        # Add padding to reach state_dim
        while len(features) < self.state_dim:
            features.append(0.0)
        
        return np.array(features[:self.state_dim])
    
    def content_based_filtering(self, user_preferences, businesses, user_id=None, limit=50):
        """Apply content-based filtering enhanced with learned preferences"""
        filtered_businesses = []
        
        # DEBUG: Print user preferences first
        print(f"\n=== DEBUGGING CONTENT FILTERING ===")
        print(f"User ID: {user_id}")
        print(f"User preferences: {user_preferences}")
        print(f"Preferred cuisines from form: {user_preferences.get('preferred_cuisine', [])}")
        print(f"Total businesses to filter: {len(businesses)}")
        
        # Get user's learning history if available
        learned_patterns = {}
        if user_id:
            learned_patterns = self.get_learned_patterns(user_id)
            print(f"Learned patterns: {learned_patterns}")
        
        cuisine_matches = 0
        for business in businesses:
            score = 0
            business_cuisine = business.get('fake_cuisine')
            
            # DEBUG: Print first 10 businesses to see what cuisines we have
            if len(filtered_businesses) < 10:
                print(f"Business: {business.get('name')} | Cuisine: {business_cuisine} | Stars: {business.get('stars')}")
            
            # Budget matching with RL override
            if business.get('price_range') and user_preferences.get('budget'):
                try:
                    business_price = float(business['price_range'])
                    user_budget = float(user_preferences['budget'])
                    
                    # Apply learned budget preference if available
                    if 'preferred_budget' in learned_patterns:
                        user_budget = learned_patterns['preferred_budget']
                        
                    price_diff = abs(business_price - user_budget)
                    score += max(0, 1 - price_diff / 3.0) * 0.3
                except (ValueError, TypeError):
                    score += 0.15
            elif not business.get('price_range'):
                score += 0.15
            
            # USE INITIAL CUISINE PREFERENCES FROM FORM
            preferred_cuisines = user_preferences.get('preferred_cuisine', [])
            
            # FIX: Handle if preferred_cuisine is stored as string in database
            if isinstance(preferred_cuisines, str):
                # Convert PostgreSQL array string format to Python list
                if preferred_cuisines.startswith('{') and preferred_cuisines.endswith('}'):
                    # Remove braces and split by comma
                    preferred_cuisines = preferred_cuisines[1:-1].split(',')
                    # Clean up each cuisine name
                    preferred_cuisines = [cuisine.strip() for cuisine in preferred_cuisines if cuisine.strip()]
                else:
                    preferred_cuisines = []
            
            print(f"DEBUG: Processed preferred_cuisines: {preferred_cuisines} (type: {type(preferred_cuisines)})")
            
            if preferred_cuisines and business_cuisine:
                # Boost if business cuisine matches user's initial preferences
                if business_cuisine in preferred_cuisines:
                    score += 0.5  # Increased boost to make it more obvious
                    cuisine_matches += 1
                    print(f"✅✅ CUISINE MATCH! {business.get('name')} - {business_cuisine} matches user preference")
                
                # Also check for broader matches (e.g., user likes "Asian", business is "Chinese")
                for pref_cuisine in preferred_cuisines:
                    if pref_cuisine.lower() == 'asian' and business_cuisine in ['Chinese', 'Thai', 'Japanese', 'Korean', 'Vietnamese']:
                        score += 0.4
                        cuisine_matches += 1
                        print(f"✅ Asian cuisine match: {business.get('name')} - {business_cuisine}")
                        break
                    elif pref_cuisine.lower() == 'american' and business_cuisine in ['American', 'Fast Food']:
                        score += 0.4
                        cuisine_matches += 1
                        print(f"✅ American cuisine match: {business.get('name')} - {business_cuisine}")
                        break
            score = 0
            
            # Budget matching with RL override
            if business.get('price_range') and user_preferences.get('budget'):
                try:
                    business_price = float(business['price_range'])
                    user_budget = float(user_preferences['budget'])
                    
                    # Apply learned budget preference if available
                    if 'preferred_budget' in learned_patterns:
                        user_budget = learned_patterns['preferred_budget']
                        
                    price_diff = abs(business_price - user_budget)
                    score += max(0, 1 - price_diff / 3.0) * 0.3
                except (ValueError, TypeError):
                    score += 0.15
            elif not business.get('price_range'):
                score += 0.15
            
            # AGGRESSIVE EXACT NAME BLOCKING - This should catch repeated dislikes
            if 'disliked_names' in learned_patterns:
                business_name = business.get('name', '').strip()
                if business_name in learned_patterns['disliked_names']:
                    score -= 1.0  # Very heavy penalty to effectively block
                    print(f"🚫 BLOCKING {business_name} - exact name match in dislikes")
                    continue  # Skip this business entirely
            
            # Smart keyword filtering with RL learning
            if 'disliked_keywords' in learned_patterns:
                business_name = business.get('name', '').lower()
                business_keywords = self._extract_keywords_from_name(business_name)
                
                for keyword in learned_patterns['disliked_keywords']:
                    if keyword in business_keywords:
                        score -= 0.8
                        print(f"🚫 Heavy penalty for {business.get('name')} - disliked keyword: {keyword}")
                        # If this business got heavily penalized, don't include it
                        if score < -0.5:
                            print(f"🚫 EXCLUDING {business.get('name')} due to heavy penalties")
                            break
            
            # Skip this business if it was heavily penalized
            if score < -0.5:
                continue
            
            # Price range learning - penalize disliked price ranges
            if 'disliked_price_ranges' in learned_patterns and business.get('price_range'):
                try:
                    business_price = int(float(business['price_range']))
                    if business_price in learned_patterns['disliked_price_ranges']:
                        score -= 0.3
                        print(f"Penalizing {business.get('name')} for disliked price range: {business_price}")
                except (ValueError, TypeError):
                    pass
            
            # Family-friendly matching
            if user_preferences.get('family_friendly') is not None and business.get('good_for_kids') is not None:
                if user_preferences.get('family_friendly') == business.get('good_for_kids'):
                    score += 0.25
            
            # Ambience matching
            user_ambience = user_preferences.get('ambience_preference', 'casual')
            if user_ambience == 'classy' and business.get('ambience_classy'):
                score += 0.2
            elif user_ambience == 'casual' and business.get('ambience_casual'):
                score += 0.2
            elif user_ambience == 'casual' and not business.get('ambience_classy'):
                score += 0.1
            
            # Travel style matching
            travel_style = user_preferences.get('travel_style', 'tourist')
            if travel_style == 'tourist' and business.get('ambience_touristy'):
                score += 0.15
            elif travel_style == 'local' and not business.get('ambience_touristy'):
                score += 0.15
            
            # Business type variety scoring
            if business.get('is_restaurant'):
                score += 0.1
            if business.get('is_cafe'):
                score += 0.08
            if business.get('outdoor_seating'):
                score += 0.05
            
            # Star rating bonus
            if business.get('stars'):
                try:
                    stars = float(business.get('stars', 0))
                    score += (stars / 5.0) * 0.25
                except (ValueError, TypeError):
                    pass
            
            # Review count bonus
            if business.get('review_count'):
                try:
                    review_count = float(business.get('review_count', 0))
                    review_bonus = min(review_count / 100.0, 0.1)
                    score += review_bonus
                except (ValueError, TypeError):
                    pass
            
            # Apply learned positive patterns boost
            if 'liked_features' in learned_patterns:
                for feature, weight in learned_patterns['liked_features'].items():
                    if business.get(feature):
                        score += weight * 0.3  # Increased boost for liked features
                        print(f"✅ Boosting {business.get('name')} for liked feature: {feature} (weight: {weight:.2f})")
            
            business['content_score'] = float(score)
            
            # Much more aggressive filtering - exclude heavily penalized businesses
            if score > -0.5:  # Only include businesses that aren't heavily penalized
                filtered_businesses.append(business)
            else:
                print(f"🚫 FILTERED OUT {business.get('name')} with score: {score:.2f}")
        
        print(f"\n=== FILTERING RESULTS ===")
        print(f"Cuisine matches found: {cuisine_matches}")
        print(f"Content filtering: {len(businesses)} → {len(filtered_businesses)} businesses (removed {len(businesses) - len(filtered_businesses)})")
        
        # Sort by content score and return top businesses
        filtered_businesses.sort(key=lambda x: x['content_score'], reverse=True)
        
        # DEBUG: Print top 10 businesses after filtering
        print(f"\n=== TOP 10 BUSINESSES AFTER FILTERING ===")
        for i, business in enumerate(filtered_businesses[:10]):
            print(f"{i+1}. {business.get('name')} | Cuisine: {business.get('fake_cuisine')} | Score: {business.get('content_score', 0):.2f}")
        
        return filtered_businesses[:limit]
    
    def get_learned_patterns(self, user_id):
        """Extract learned patterns from user interactions"""
        interactions = self.get_user_interactions(user_id)
        
        patterns = {
            'disliked_names': [],      # Exact business names user disliked
            'disliked_keywords': [],   # Keywords in business names
            'disliked_cuisines': [],   # Specific cuisine types user dislikes (from fake_cuisine column)
            'liked_cuisines': [],      # Specific cuisine types user likes (from fake_cuisine column)
            'liked_features': {},
            'preferred_budget': None,
            'disliked_price_ranges': []
        }
        
        if len(interactions) < 2:  # Start learning after just 2 interactions
            return patterns
        
        likes = []
        dislikes = []
        
        for interaction in interactions:
            if interaction['interaction_type'] == 'like':
                likes.append(interaction)
            else:
                dislikes.append(interaction)
        
        print(f"Processing {len(dislikes)} dislikes and {len(likes)} likes")
        
        # Learn exact business names that were disliked
        for dislike in dislikes:
            business_name = dislike.get('name', '').strip()
            if business_name and business_name not in patterns['disliked_names']:
                patterns['disliked_names'].append(business_name)
                print(f"Added to disliked names: {business_name}")
        
        # Learn disliked cuisines using fake_cuisine column from database
        for dislike in dislikes:
            fake_cuisine = dislike.get('fake_cuisine')
            if fake_cuisine and fake_cuisine not in patterns['disliked_cuisines']:
                patterns['disliked_cuisines'].append(fake_cuisine)
                print(f"Added to disliked cuisines: {fake_cuisine} (from {dislike.get('name')})")
        
        # Learn liked cuisines using fake_cuisine column from database
        for like in likes:
            fake_cuisine = like.get('fake_cuisine')
            if fake_cuisine and fake_cuisine not in patterns['liked_cuisines']:
                patterns['liked_cuisines'].append(fake_cuisine)
                print(f"Added to liked cuisines: {fake_cuisine} (from {like.get('name')})")
        
        # Learn specific business name patterns for keywords (keep this for additional patterns)
        for dislike in dislikes:
            name = dislike.get('name', '').lower()
            keywords_found = self._extract_keywords_from_name(name)
            
            for keyword in keywords_found:
                if keyword not in patterns['disliked_keywords']:
                    patterns['disliked_keywords'].append(keyword)
                    print(f"Added to disliked keywords: {keyword} (from {name})")
            
            # Learn disliked price ranges
            if dislike.get('price_range'):
                try:
                    price = int(float(dislike['price_range']))
                    if price not in patterns['disliked_price_ranges']:
                        patterns['disliked_price_ranges'].append(price)
                        print(f"Added to disliked price ranges: {price}")
                except (ValueError, TypeError):
                    pass
        
        # Learn preferred budget from likes
        if likes:
            budget_sum = 0
            budget_count = 0
            for like in likes:
                if like.get('price_range'):
                    try:
                        budget_sum += float(like['price_range'])
                        budget_count += 1
                    except (ValueError, TypeError):
                        pass
            
            if budget_count > 0:
                patterns['preferred_budget'] = budget_sum / budget_count
                print(f"Learned preferred budget: {patterns['preferred_budget']:.1f}")
        
        # Learn liked features
        feature_counts = {}
        for like in likes:
            if like.get('outdoor_seating'):
                feature_counts['outdoor_seating'] = feature_counts.get('outdoor_seating', 0) + 1
            if like.get('wifi'):
                feature_counts['wifi'] = feature_counts.get('wifi', 0) + 1
            if like.get('ambience_classy'):
                feature_counts['ambience_classy'] = feature_counts.get('ambience_classy', 0) + 1
            if like.get('ambience_casual'):
                feature_counts['ambience_casual'] = feature_counts.get('ambience_casual', 0) + 1
        
        # Convert to weights (only if more than 50% of likes have this feature)
        total_likes = len(likes)
        if total_likes > 0:
            for feature, count in feature_counts.items():
                if count / total_likes > 0.5:
                    patterns['liked_features'][feature] = count / total_likes
                    print(f"Learned liked feature: {feature} (weight: {count / total_likes:.2f})")
        
        print(f"Final learned patterns for user {user_id}: {patterns}")
        return patterns
    
    def initialize_ppo_agent(self):
        """Initialize PPO agent"""
        self.ppo_agent = PPOAgent(self.state_dim, self.action_dim)
        self.ppo_optimizer = optim.Adam(self.ppo_agent.parameters(), lr=0.001)
    
    def get_user_interactions(self, user_id):
        """Get user interaction history"""
        conn = self.get_db_connection()
        cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        
        cursor.execute("""
            SELECT ui.*, b.* FROM user_interactions ui
            JOIN businesses b ON ui.business_id = b.id
            WHERE ui.user_id = %s
            ORDER BY ui.created_at DESC
        """, (user_id,))
        
        interactions = cursor.fetchall()
        cursor.close()
        conn.close()
        
        return interactions
    
    def update_ppo_model(self, user_id, user_preferences):
        """Update PPO model based on user interactions"""
        interactions = self.get_user_interactions(user_id)
        
        # Start learning after just 2 interactions instead of 5
        if len(interactions) < 2:
            return
        
        if not self.ppo_agent:
            self.initialize_ppo_agent()
        
        states = []
        actions = []
        rewards = []
        
        for interaction in interactions:
            try:
                # Create state (user preferences + business features)
                user_features = self.create_user_feature_vector(user_preferences)
                business_features = self.create_business_feature_vector(dict(interaction))
                
                # Combine features (you might want to do this differently)
                state = (user_features + business_features) / 2.0
                states.append(state)
                
                # Action (0: dislike, 1: like)
                action = 1 if interaction['interaction_type'] == 'like' else 0
                actions.append(action)
                
                # Stronger rewards for better learning
                reward = 2.0 if interaction['interaction_type'] == 'like' else -2.0
                rewards.append(reward)
            except Exception as e:
                print(f"Error processing interaction: {e}")
                continue
        
        if len(states) == 0:
            return
        
        print(f"Training PPO with {len(states)} interactions for user {user_id}")
        
        # Convert to tensors
        states_tensor = torch.FloatTensor(np.array(states))
        actions_tensor = torch.LongTensor(actions)
        rewards_tensor = torch.FloatTensor(rewards)
        
        # Simple PPO update (simplified version)
        old_action_probs, old_values = self.ppo_agent(states_tensor)
        old_action_probs = old_action_probs.gather(1, actions_tensor.unsqueeze(1))
        
        # Calculate advantages
        advantages = rewards_tensor - old_values.squeeze()
        
        # More aggressive PPO training
        for epoch in range(10):  # Increased from 5 to 10 epochs
            action_probs, values = self.ppo_agent(states_tensor)
            action_probs = action_probs.gather(1, actions_tensor.unsqueeze(1))
            
            ratio = action_probs / (old_action_probs.detach() + 1e-8)
            
            # Clipped surrogate loss
            epsilon = 0.3  # Increased from 0.2 for more aggressive updates
            clipped_ratio = torch.clamp(ratio, 1 - epsilon, 1 + epsilon)
            actor_loss = -torch.min(ratio * advantages.detach(), 
                                  clipped_ratio * advantages.detach()).mean()
            
            # Value loss
            critic_loss = nn.MSELoss()(values.squeeze(), rewards_tensor)
            
            # Total loss
            total_loss = actor_loss + 0.5 * critic_loss
            
            self.ppo_optimizer.zero_grad()
            total_loss.backward()
            self.ppo_optimizer.step()
        
        print(f"PPO training completed for user {user_id}")
    
    def predict_business_ranking(self, user_preferences, businesses):
        """Use PPO model to rank businesses"""
        if not self.ppo_agent:
            return businesses
        
        user_features = self.create_user_feature_vector(user_preferences)
        ranked_businesses = []
        
        for business in businesses:
            try:
                business_features = self.create_business_feature_vector(business)
                state = torch.FloatTensor((user_features + business_features) / 2.0).unsqueeze(0)
                
                with torch.no_grad():
                    action_probs, _ = self.ppo_agent(state)
                    like_prob = action_probs[0][1].item()  # Probability of liking
                
                business['rl_score'] = like_prob
                ranked_businesses.append(business)
            except Exception as e:
                print(f"Error ranking business {business.get('name', 'Unknown')}: {e}")
                business['rl_score'] = 0.5  # Neutral score
                ranked_businesses.append(business)
        
        # Sort by RL score
        ranked_businesses.sort(key=lambda x: x.get('rl_score', 0.5), reverse=True)
        return ranked_businesses

# Initialize recommendation system
recommendation_system = TravelRecommendationSystem()

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/select_user')
def select_user():
    """Show user selection page"""
    conn = recommendation_system.get_db_connection()
    cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    
    # Get all users with their preference counts
    cursor.execute("""
        SELECT u.id, u.created_at, 
               COUNT(up.id) as preference_count,
               COUNT(ui.id) as interaction_count
        FROM users u
        LEFT JOIN user_preferences up ON u.id = up.user_id
        LEFT JOIN user_interactions ui ON u.id = ui.user_id
        GROUP BY u.id, u.created_at
        ORDER BY u.created_at DESC
    """)
    
    users = cursor.fetchall()
    cursor.close()
    conn.close()
    
    return render_template('select_user.html', users=users)

@app.route('/set_user/<user_id>')
def set_user(user_id):
    """Set the current user"""
    session['user_id'] = user_id
    
    # Get user's latest preferences
    conn = recommendation_system.get_db_connection()
    cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    
    cursor.execute("""
        SELECT * FROM user_preferences 
        WHERE user_id = %s 
        ORDER BY created_at DESC 
        LIMIT 1
    """, (user_id,))
    
    latest_prefs = cursor.fetchone()
    cursor.close()
    conn.close()
    
    if latest_prefs:
        # Convert to dict and store in session
        preferred_cuisine = latest_prefs['preferred_cuisine']
        
        # FIX: Handle PostgreSQL array format
        if isinstance(preferred_cuisine, str) and preferred_cuisine.startswith('{') and preferred_cuisine.endswith('}'):
            # Convert "{Italian,Mexican}" to ["Italian", "Mexican"]
            preferred_cuisine = preferred_cuisine[1:-1].split(',')
            preferred_cuisine = [cuisine.strip() for cuisine in preferred_cuisine if cuisine.strip()]
        elif preferred_cuisine is None:
            preferred_cuisine = []
        
        user_prefs = {
            'budget': latest_prefs['budget'],
            'travel_days': latest_prefs['travel_days'],
            'travel_style': latest_prefs['travel_style'],
            'noise_preference': latest_prefs['noise_preference'],
            'family_friendly': latest_prefs['family_friendly'],
            'accommodation_type': latest_prefs['accommodation_type'],
            'preferred_cuisine': preferred_cuisine,  # Use the processed version
            'ambience_preference': latest_prefs['ambience_preference'],
            'good_for_kids': latest_prefs['good_for_kids']
        }
        
        print(f"DEBUG: Loaded preferences from DB: {user_prefs}")
        session['user_preferences'] = user_prefs
        return redirect('/itinerary')
    else:
        # No preferences found, redirect to preferences page
        return redirect('/preferences')

@app.route('/new_user')
def new_user():
    """Create a new user"""
    new_user_id = str(uuid.uuid4())
    
    # Create user in database
    conn = recommendation_system.get_db_connection()
    cursor = conn.cursor()
    
    try:
        # Insert user with only id (handle missing email column gracefully)
        cursor.execute("""
            INSERT INTO users (id) 
            VALUES (%s)
            ON CONFLICT (id) DO NOTHING
        """, (new_user_id,))
        
        conn.commit()
        print(f"✓ New user created: {new_user_id}")
        
    except Exception as e:
        print(f"Error creating user: {e}")
        # If there's an email constraint, try inserting with a dummy email
        try:
            cursor.execute("""
                INSERT INTO users (id, email) 
                VALUES (%s, %s)
                ON CONFLICT (id) DO NOTHING
            """, (new_user_id, f"user_{new_user_id}@temp.com"))
            conn.commit()
            print(f"✓ New user created with dummy email: {new_user_id}")
        except Exception as e2:
            print(f"Failed to create user even with email: {e2}")
            conn.rollback()
            # Generate a simple ID if database creation fails
            new_user_id = f"user_{random.randint(1000, 9999)}"
    finally:
        cursor.close()
        conn.close()
    
    session['user_id'] = new_user_id
    return redirect('/preferences')

@app.route('/preferences', methods=['GET', 'POST'])
def preferences():
    # Ensure user is selected
    if 'user_id' not in session:
        return redirect('/select_user')
    
    if request.method == 'POST':
        user_prefs = {
            'budget': int(request.form['budget']),
            'travel_days': int(request.form['travel_days']),
            'travel_style': request.form['travel_style'],
            'noise_preference': request.form['noise_preference'],
            'family_friendly': 'family_friendly' in request.form,
            'accommodation_type': request.form['accommodation_type'],
            'preferred_cuisine': request.form.getlist('cuisine'),
            'ambience_preference': request.form['ambience_preference'],
            'good_for_kids': 'good_for_kids' in request.form
        }
        
        # DEBUG: Print what we received from the form
        print(f"\n=== DEBUGGING PREFERENCES FORM ===")
        print(f"Raw form data: {dict(request.form)}")
        print(f"Cuisine checkboxes selected: {request.form.getlist('cuisine')}")
        print(f"Processed user preferences: {user_prefs}")
        
        # Store in session
        session['user_preferences'] = user_prefs
        user_id = session['user_id']
        
        # Save to database
        conn = recommendation_system.get_db_connection()
        cursor = conn.cursor()
        
        try:
            # Insert new preferences (user already exists)
            cursor.execute("""
                INSERT INTO user_preferences 
                (user_id, budget, travel_days, travel_style, noise_preference, 
                 family_friendly, accommodation_type, preferred_cuisine, 
                 ambience_preference, good_for_kids)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            """, (
                user_id, user_prefs['budget'], user_prefs['travel_days'],
                user_prefs['travel_style'], user_prefs['noise_preference'],
                user_prefs['family_friendly'], user_prefs['accommodation_type'],
                user_prefs['preferred_cuisine'], user_prefs['ambience_preference'],
                user_prefs['good_for_kids']
            ))
            
            conn.commit()
            print(f"✓ User preferences saved for user: {user_id}")
            
        except Exception as e:
            print(f"Error saving preferences: {e}")
            conn.rollback()
        finally:
            cursor.close()
            conn.close()
        
        return redirect('/itinerary')
    
    # GET request - show form with current user info
    user_id = session.get('user_id', 'Unknown')
    return render_template('preferences.html', current_user=user_id)

@app.route('/itinerary')
def itinerary():
    if 'user_preferences' not in session:
        return redirect('/preferences')
    
    user_prefs = session['user_preferences']
    user_id = session['user_id']
    
    # Get user's preferred cuisines
    preferred_cuisines = user_prefs.get('preferred_cuisine', [])
    
    # Get businesses from database with CUISINE-PRIORITIZED filtering
    conn = recommendation_system.get_db_connection()
    cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    
    if preferred_cuisines:
        print(f"🎯 User selected cuisines: {preferred_cuisines}")
        
        # PRIORITY: Get businesses matching user's preferred cuisines first
        cuisine_placeholders = ','.join(['%s'] * len(preferred_cuisines))
        priority_query = f"""
            SELECT * FROM businesses 
            WHERE (stars >= 3.0 OR stars IS NULL)
            AND name IS NOT NULL 
            AND name != ''
            AND fake_cuisine IN ({cuisine_placeholders})
            ORDER BY stars DESC NULLS LAST, review_count DESC
            LIMIT 150
        """
        
        cursor.execute(priority_query, preferred_cuisines)
        priority_businesses = cursor.fetchall()
        
        print(f"🍝 Found {len(priority_businesses)} businesses matching preferred cuisines: {preferred_cuisines}")
        
        # Get additional businesses for variety
        general_query = """
            SELECT * FROM businesses 
            WHERE (stars >= 3.0 OR stars IS NULL)
            AND name IS NOT NULL 
            AND name != ''
            ORDER BY stars DESC NULLS LAST, review_count DESC
            LIMIT 150
        """
        
        cursor.execute(general_query)
        all_businesses = cursor.fetchall()
        
        # Combine: preferred cuisines first, then others (avoiding duplicates)
        seen_ids = set()
        combined_businesses = []
        
        # Add cuisine matches first
        for business in priority_businesses:
            if business['id'] not in seen_ids:
                combined_businesses.append(business)
                seen_ids.add(business['id'])
        
        # Add other businesses for variety
        for business in all_businesses:
            if business['id'] not in seen_ids and len(combined_businesses) < 250:
                combined_businesses.append(business)
                seen_ids.add(business['id'])
        
        businesses = combined_businesses
        
        # Show top Italian restaurants found
        italian_found = [b for b in priority_businesses if b.get('fake_cuisine') == 'Italian']
        if italian_found:
            print(f"🍝 Top Italian restaurants found:")
            for i, restaurant in enumerate(italian_found[:10]):
                print(f"   {i+1}. {restaurant['name']} | ⭐{restaurant['stars']} | {restaurant['city']}")
        
    else:
        # No cuisine preference - use regular query
        query = """
            SELECT * FROM businesses 
            WHERE (stars >= 3.0 OR stars IS NULL)
            AND name IS NOT NULL 
            AND name != ''
            ORDER BY stars DESC NULLS LAST, review_count DESC
            LIMIT 200
        """
        
        cursor.execute(query)
        businesses = cursor.fetchall()
    
    cursor.close()
    conn.close()
    
    print(f"Retrieved {len(businesses)} businesses from database")
    
    # Convert to list of dicts
    businesses = [dict(business) for business in businesses]
    
    # Apply content-based filtering with learning
    filtered_businesses = recommendation_system.content_based_filtering(
        user_prefs, businesses, user_id, limit=120  # Increased limit
    )
    
    print(f"After content filtering: {len(filtered_businesses)} businesses")
    
    # Apply PPO ranking if we have enough businesses
    if len(filtered_businesses) > 0:
        recommendation_system.update_ppo_model(user_id, user_prefs)
        ranked_businesses = recommendation_system.predict_business_ranking(
            user_prefs, filtered_businesses
        )
    else:
        # Fallback: use all businesses if filtering is too strict
        print("Content filtering too restrictive, using all businesses")
        ranked_businesses = businesses[:50]
        for business in ranked_businesses:
            business['content_score'] = 0.5
    
    # Create k-day itinerary
    travel_days = user_prefs['travel_days']
    places_per_day = 5
    
    itinerary_data = []
    business_index = 0
    
    for day in range(1, travel_days + 1):
        day_businesses = []
        for _ in range(places_per_day):
            if business_index < len(ranked_businesses):
                day_businesses.append(ranked_businesses[business_index])
                business_index += 1
            else:
                if len(ranked_businesses) > 0:
                    fallback_business = ranked_businesses[business_index % len(ranked_businesses)].copy()
                    fallback_business['name'] += " (Alternative)"
                    day_businesses.append(fallback_business)
                    business_index += 1
        
        if day_businesses:
            itinerary_data.append({
                'day': day,
                'businesses': day_businesses
            })
    
    print(f"Generated itinerary for {len(itinerary_data)} days")
    
    return render_template('itinerary.html', itinerary=itinerary_data)

@app.route('/feedback', methods=['POST'])
def feedback():
    data = request.get_json()
    business_id = data['business_id']
    interaction_type = data['interaction_type']  # 'like' or 'dislike'
    
    if 'user_id' not in session:
        return jsonify({'error': 'No user session'}), 400
    
    user_id = session['user_id']
    user_prefs = session.get('user_preferences', {})
    
    # Store interaction in database
    conn = recommendation_system.get_db_connection()
    cursor = conn.cursor()
    
    cursor.execute("""
        INSERT INTO user_interactions 
        (user_id, business_id, interaction_type, context_preferences)
        VALUES (%s, %s, %s, %s)
    """, (user_id, business_id, interaction_type, json.dumps(user_prefs)))
    
    conn.commit()
    cursor.close()
    conn.close()
    
    # Update PPO model with new feedback
    recommendation_system.update_ppo_model(user_id, user_prefs)
    
    return jsonify({'status': 'success'})

if __name__ == '__main__':
    app.run(debug=True)