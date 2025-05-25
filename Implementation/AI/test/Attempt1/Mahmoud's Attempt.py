# Import libraries
import pandas as pd
from sklearn.cluster import KMeans
from sklearn.preprocessing import StandardScaler
import numpy as np
import folium
from folium.plugins import MarkerCluster
import gym
from stable_baselines3 import PPO
from stable_baselines3.common.vec_env import DummyVecEnv
from gym import spaces

# Load dataset
file_path = 'C:/Users/mmahm_58hhl7x/Downloads/flattened_data(1)/flattened_data.csv'
df = pd.read_csv(file_path, low_memory=False)

# Remove duplicate columns
df = df.loc[:, ~df.columns.duplicated()]

# Selecting relevant features for clustering (numeric only)
numeric_features = [
    "latitude", "longitude", "stars", "review_count",
    "attributes_RestaurantsPriceRange2", "attributes_GoodForKids",
    "attributes_RestaurantsGoodForGroups", "attributes_NoiseLevel"
]

# Convert columns to numeric
df["review_count"] = pd.to_numeric(df["review_count"], errors="coerce")
df["attributes_RestaurantsPriceRange2"] = pd.to_numeric(df["attributes_RestaurantsPriceRange2"], errors="coerce")
df["attributes_GoodForKids"] = df["attributes_GoodForKids"].map({"True": 1, "False": 0})
df["attributes_RestaurantsGoodForGroups"] = df["attributes_RestaurantsGoodForGroups"].map({"True": 1, "False": 0})
df["attributes_NoiseLevel"] = df["attributes_NoiseLevel"].map({"quiet": 0, "average": 1, "loud": 2, "very_loud": 3})

# Fill missing values
df["review_count"] = df["review_count"].fillna(df["review_count"].median())
df["attributes_RestaurantsPriceRange2"] = df["attributes_RestaurantsPriceRange2"].fillna(df["attributes_RestaurantsPriceRange2"].median())
df["attributes_GoodForKids"] = df["attributes_GoodForKids"].fillna(0)
df["attributes_RestaurantsGoodForGroups"] = df["attributes_RestaurantsGoodForGroups"].fillna(0)
df["attributes_NoiseLevel"] = df["attributes_NoiseLevel"].fillna(df["attributes_NoiseLevel"].mode()[0])

# Keep only non-null lat/lon and include 'name' for recommendations
df_filtered = df[numeric_features + ["name"]].dropna(subset=["latitude", "longitude"])

# Standardizing the data (exclude 'name', 'latitude', 'longitude')
scaler = StandardScaler()
df_scaled = scaler.fit_transform(df_filtered[numeric_features])

# Applying K-Means clustering
num_clusters = 5
kmeans = KMeans(n_clusters=num_clusters, random_state=42, n_init=10)
df_filtered["cluster"] = kmeans.fit_predict(df_scaled)

# Cluster analysis (numeric columns only)
numeric_columns = df_filtered.select_dtypes(include=[np.number]).columns
grouped = df_filtered.groupby("cluster")[numeric_columns].mean()
print("\nCluster Analysis:")
print(grouped)

# Create interactive map
map_center = [df_filtered["latitude"].mean(), df_filtered["longitude"].mean()]
map_clusters = folium.Map(location=map_center, zoom_start=10)
marker_cluster = MarkerCluster().add_to(map_clusters)

# Add markers with restaurant names
colors = ["red", "blue", "green", "purple", "orange"]
for idx, row in df_filtered.iterrows():
    folium.Marker(
        location=[row["latitude"], row["longitude"]],
        popup=f"Name: {row['name']}\nCluster: {row['cluster']}\nStars: {row['stars']}\nPrice: {row['attributes_RestaurantsPriceRange2']}",
        icon=folium.Icon(color=colors[row["cluster"]])
    ).add_to(marker_cluster)

map_clusters.save("C:/Users/mmahm_58hhl7x/Downloads/clusters_map.html")
print("Map saved successfully.")

# RL Travel Planner
class TravelPlannerEnv(gym.Env):
    def __init__(self, df, user_preferences):
        super(TravelPlannerEnv, self).__init__()
        self.df = df
        self.user_preferences = user_preferences
        self.current_cluster = 0
        self.current_day = 1

        self.action_space = spaces.Discrete(len(df["cluster"].unique()))
        self.observation_space = spaces.Box(low=0, high=1, shape=(6,), dtype=np.float32)

    def reset(self):
        self.current_cluster = 0
        self.current_day = 1
        return self._get_obs()

    def step(self, action):
        self.current_cluster = action
        reward = self._calculate_reward()
        done = self.current_day >= self.user_preferences["travel_days"]
        self.current_day += 1
        return self._get_obs(), reward, done, {}

    def _get_obs(self):
        act_as = 0 if self.user_preferences["act_as"] == "local" else 1
        family_friendly = 1 if self.user_preferences["family_friendly"] == "yes" else 0
        calm_sites = 1 if self.user_preferences["calm_sites"] == "yes" else 0
        return np.array([
            self.user_preferences["budget"],
            self.user_preferences["travel_days"],
            act_as,
            family_friendly,
            calm_sites,
            self.current_cluster
        ], dtype=np.float32)

    def _calculate_reward(self):
        # Use only numeric columns for mean calculation
        cluster_data = self.df[self.df["cluster"] == self.current_cluster][numeric_features].mean()
        reward = 0
        if cluster_data["attributes_RestaurantsPriceRange2"] <= self.user_preferences["budget"]:
            reward += 1
        if self.user_preferences["family_friendly"] == "yes" and cluster_data["attributes_GoodForKids"] == 1:
            reward += 1
        return reward

    def generate_recommendations(self):
        cluster_data = self.df[self.df["cluster"] == self.current_cluster]
        return cluster_data.sort_values(by=["stars", "review_count"], ascending=False).head(3)

# Collect user input
user_preferences = {
    "budget": float(input("Enter your budget: ")),
    "travel_days": int(input("Enter travel days: ")),
    "act_as": input("Act as (local/tourist): "),
    "family_friendly": input("Family-friendly (yes/no): "),
    "calm_sites": input("Calm locations (yes/no): ")
}

# Train RL agent
env = TravelPlannerEnv(df_filtered, user_preferences)
env = DummyVecEnv([lambda: env])
model = PPO("MlpPolicy", env, verbose=1)
model.learn(total_timesteps=10000)

# Generate plan
obs = env.reset()
travel_plan = []
for day in range(user_preferences["travel_days"]):
    action, _ = model.predict(obs)
    obs, _, _, _ = env.step(action)
    recommendations = env.env_method("generate_recommendations")[0]
    travel_plan.append({
        "Day": day + 1,
        "Cluster": action,
        "Recommendations": recommendations[["name", "latitude", "longitude", "stars", "review_count"]]
    })

# Display plan
print("\nYour Travel Plan:")
for day_plan in travel_plan:
    print(f"\nDay {day_plan['Day']}: Cluster {day_plan['Cluster']}")
    print(day_plan["Recommendations"])