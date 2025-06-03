# Metadata-Based Learning System for Travel Recommendations

## Overview

This enhanced recommendation system learns from user behavior by analyzing the posts they like and using the metadata attributes (Calm, Romantic, Good_for_Kids, etc.) to improve future recommendations. The system uses reinforcement learning to personalize recommendations based on user's demonstrated preferences.

## Key Features

### 🧠 Intelligent Learning
- **Post Metadata Analysis**: Learns from metadata of posts users like
- **Preference Scoring**: Calculates user preferences for attributes like romantic, calm, classy, etc.
- **Cuisine Learning**: Identifies preferred cuisine types from liked posts
- **Location Preferences**: Tracks preferred locations and price ranges

### 🎯 Enhanced Recommendations
- **Metadata Compatibility Scoring**: Matches businesses to learned preferences
- **PPO Reinforcement Learning**: Uses advanced ML to improve recommendations over time
- **Multi-factor Scoring**: Combines traditional filters with learned metadata preferences
- **Personalized Ranking**: Ranks businesses based on individual user patterns

## Database Schema

### Required Tables

#### MetaData Table
```sql
CREATE TABLE metadata (
    meta_id SERIAL PRIMARY KEY,
    post_id TEXT,
    calm INTEGER (0 or 1),
    noisy INTEGER (0 or 1),
    romantic INTEGER (0 or 1),
    good_for_kids INTEGER (0 or 1),
    classy INTEGER (0 or 1),
    casual INTEGER (0 or 1),
    family_friendly_places INTEGER (0 or 1),
    location TEXT,
    cuisine_type TEXT,
    price_range INTEGER
);
```

#### Likes Table
```sql
CREATE TABLE likes (
    post_id TEXT,
    liker_user_id TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (post_id, liker_user_id)
);
```

## System Architecture

### Core Components

1. **TravelRecommendationSystem Class** (Enhanced)
   - `get_user_liked_posts_metadata()`: Retrieves metadata of user's liked posts
   - `analyze_user_metadata_preferences()`: Analyzes patterns in liked posts
   - `calculate_metadata_compatibility_score()`: Scores businesses against learned preferences
   - `map_business_to_metadata_format()`: Converts business data to metadata format

2. **Enhanced PPO Agent**
   - Increased state dimension to include metadata features
   - Enhanced reward system based on metadata compatibility
   - Personalized feature vectors including learned preferences

3. **Content-Based Filtering** (Enhanced)
   - Integrates metadata preferences into scoring
   - Higher weight for metadata compatibility (0.6 multiplier)
   - Combines traditional filtering with learned patterns

## How It Works

### Learning Process

1. **User Interaction**: User likes posts in the system
2. **Metadata Extraction**: System extracts metadata from liked posts
3. **Pattern Analysis**: Calculates preference scores for each attribute
4. **Business Mapping**: Maps business attributes to metadata format
5. **Compatibility Scoring**: Scores businesses based on learned preferences
6. **Recommendation Enhancement**: Incorporates scores into ranking algorithm

### Preference Calculation

For each metadata attribute (calm, romantic, etc.):
```python
preference_score = count_of_likes_with_attribute / total_likes
```

### Business Compatibility Scoring

Uses weighted scoring system:
- **Binary Attributes**: Calm, Noisy, Romantic, etc. (weights: 0.25-0.4)
- **Cuisine Matching**: High weight (0.5) for cuisine preferences
- **Price Range**: Moderate weight (0.3) for price preferences
- **Location**: Lower weight (0.2) for location preferences

## Usage Guide

### 1. Setup and Testing

Run the simple test to verify the system:
```bash
python simple_metadata_test.py
```

This will:
- Create required database tables
- Insert sample posts with metadata
- Simulate user likes based on romantic preferences
- Demonstrate learning and recommendation improvements

### 2. Full System Testing

For comprehensive testing with multiple user profiles:
```bash
python test_metadata_learning.py
```

This tests different user profiles:
- **Romantic Foodie**: Likes romantic, classy places
- **Family Oriented**: Prefers family-friendly, casual spots
- **Young Social**: Enjoys noisy, casual places
- **Quiet Contemplative**: Prefers calm, romantic establishments

### 3. Integration with Flask App

The system is already integrated into `flask_app.py`. Key integration points:

#### Enhanced Content Filtering
```python
# In content_based_filtering method
if metadata_preferences:
    metadata_score = self.calculate_metadata_compatibility_score(business, metadata_preferences)
    score += metadata_score * 0.6  # High weight for metadata compatibility
```

#### Enhanced PPO Training
```python
# In update_ppo_model method
metadata_preferences = self.analyze_user_metadata_preferences(user_id)
user_features = self.create_user_feature_vector(user_preferences, metadata_preferences)
```

#### Enhanced Business Ranking
```python
# In predict_business_ranking method
ranked_businesses = recommendation_system.predict_business_ranking(
    user_prefs, filtered_businesses, user_id  # Pass user_id for metadata preferences
)
```

## Testing Results Analysis

### Expected Behavior

When testing with a "romantic foodie" profile:

1. **Learning Phase**:
   - User likes posts about romantic Italian restaurants
   - User likes posts about classy French bistros
   - User likes posts about serene Japanese restaurants

2. **Analysis Results**:
   ```
   📊 LEARNED PREFERENCES:
      Romantic: 1.00 (100% of likes were romantic places)
      Classy: 1.00 (100% of likes were classy places)
      Calm: 1.00 (100% of likes were calm places)
      Family-friendly: 0.00 (0% of likes were family-friendly)
   
   🍽️ PREFERRED CUISINES:
      Italian: 1 likes
      French: 1 likes
      Japanese: 1 likes
   ```

3. **Business Scoring**:
   ```
   📈 BUSINESS COMPATIBILITY SCORES:
   Romantic Italian Bistro    | Score: 0.850
   Upscale Steakhouse        | Score: 0.720
   Family Pizza Place        | Score: 0.200
   ```

### Key Insights

- **Higher Scores**: Businesses matching learned preferences get significantly higher scores
- **Personalization**: Same cuisine type (Italian) scores differently based on ambience
- **Multi-factor Learning**: System learns combinations of attributes, not just individual preferences
- **Improved Recommendations**: Recommendations become more targeted as the system learns

## Performance Monitoring

### Metrics to Track

1. **Learning Effectiveness**:
   - Number of liked posts analyzed
   - Strength of learned preferences (how clear the patterns are)
   - Consistency of user behavior

2. **Recommendation Quality**:
   - Average compatibility scores of recommended businesses
   - User satisfaction with recommendations
   - Click-through rates on recommended items

3. **System Performance**:
   - Response time for preference analysis
   - Database query efficiency
   - PPO training convergence

### Debug Output

The system provides extensive logging:
```
🧠 Analyzing learned preferences for user user_123...
Found 3 liked posts with metadata for user user_123
✅ Cuisine match: Italian (score: 0.33)
🎯 Metadata score for Restaurant ABC: 0.850
```

## Future Enhancements

### Potential Improvements

1. **Temporal Learning**: Consider how preferences change over time
2. **Context Awareness**: Factor in time of day, season, occasion
3. **Social Learning**: Learn from similar users' preferences
4. **Confidence Scoring**: Provide confidence levels for learned preferences
5. **Preference Explanation**: Explain why certain recommendations are made

### Scalability Considerations

1. **Caching**: Cache learned preferences to reduce database queries
2. **Batch Processing**: Process preference updates in batches
3. **Incremental Learning**: Update preferences incrementally rather than recalculating
4. **Distributed Computing**: Scale PPO training across multiple machines

## Troubleshooting

### Common Issues

1. **No Preferences Learned**:
   - Ensure user has liked at least 2 posts
   - Check metadata table has data for liked posts
   - Verify database connections

2. **Low Compatibility Scores**:
   - Check business attribute mapping
   - Verify metadata format consistency
   - Review weight distribution in scoring algorithm

3. **PPO Training Issues**:
   - Ensure sufficient interaction data
   - Check tensor dimensions match
   - Verify reward calculation logic

### Debug Commands

```python
# Check user's liked posts
rec_system.get_user_liked_posts_metadata(user_id)

# Analyze learned preferences
rec_system.analyze_user_metadata_preferences(user_id)

# Test business compatibility
rec_system.calculate_metadata_compatibility_score(business, preferences)
```

## Conclusion

This metadata-based learning system significantly enhances the travel recommendation platform by:

- **Learning from Real Behavior**: Uses actual user likes rather than just initial preferences
- **Multi-dimensional Understanding**: Captures complex preference patterns
- **Continuous Improvement**: Gets better recommendations over time
- **Personalized Experience**: Provides unique recommendations for each user

The system represents a major advancement in personalized travel recommendations, combining traditional content-based filtering with modern machine learning techniques to deliver highly relevant suggestions based on demonstrated user preferences. 