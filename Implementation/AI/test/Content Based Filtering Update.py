import pandas as pd
import numpy as np
from sklearn.metrics.pairwise import cosine_similarity


data_set = pd.read_csv("E:/Travia-main/Implementation/AI/DataSet/lateset Dataset Main/pre_processed_df_with.csv")    


data_set.head()


# # feature selection

ds = data_set[
    [
        "stars",

        "attributes_RestaurantsPriceRange2",

        # good for kids or romantic
        "attributes_GoodForKids", # option1

        "attributes_Ambience_romantic", # option2
        "attributes_Ambience_intimate", # option2

        "attributes_Ambience_touristy",

        # trendy or classy or casual 
        "attributes_Ambience_trendy",
        "attributes_Ambience_classy",
        "attributes_Ambience_casual",

        # choose one or many from those 
        "Bars_Night",
        "Beauty_Health_Care",
        "Cafes",
        "GYM",
        "Restaurants_Cuisines",
        "Shops"
    ]
]


ds.head()


def create_user_pref_vector(user_pref):
    user_vector = np.zeros(15, dtype=np.float32)
    user_vector[0] = user_pref["min_stars"]
    user_vector[1] = user_pref["price_range"]
    if user_pref["intimate_or_family"] == "family":
        user_vector[2] = 1
    else:
        user_vector[4] = 1
        user_vector[5] = 1
    user_vector[3] = user_pref["attributes_Ambience_touristy"]
    user_vector[6] = user_pref["attributes_Ambience_trendy"]
    user_vector[7] = user_pref["attributes_Ambience_classy"]
    user_vector[8] = user_pref["attributes_Ambience_casual"]

    for cat in user_pref["category"]:
        user_vector[9 + cat] = 1
    return user_vector


user_pref = {
    #"Bars_Night","Beauty_Health_Care","Cafes","GYM","Restaurants_Cuisines","Shops"
    "category": [0,2,4],
    "min_stars": 3.5,
    "price_range": 3,
    "attributes_Ambience_touristy": 0,
    "attributes_Ambience_trendy": 1,
    "attributes_Ambience_classy": 0,
    "attributes_Ambience_casual": 1,
    "intimate_or_family": 'family'
}


v = create_user_pref_vector(user_pref)


v.reshape(1, -1)

def recommend_businesses(user_pref, data, original_df, k=3):
    user_vector = create_user_pref_vector(user_pref)    
    similarities = cosine_similarity(data, user_vector.reshape(1, -1)).flatten()
    top_k_unsorted = np.argpartition(-similarities, k)[:k]
    sorted_indices = top_k_unsorted[np.argsort(similarities[top_k_unsorted])[::-1]]
    recommendations = original_df.iloc[sorted_indices][[
        "name", "stars", "attributes_RestaurantsPriceRange2", "address", "city","attributes_GoodForKids","attributes_Ambience_romantic","attributes_Ambience_intimate","attributes_Ambience_touristy","attributes_Ambience_trendy","attributes_Ambience_classy","attributes_Ambience_casual",
        "Bars_Night", "Beauty_Health_Care", "Cafes", "GYM", "Restaurants_Cuisines", "Shops"
    ]].copy()
    recommendations["similarity"] = similarities[sorted_indices]
    return recommendations

user_pref = {
    #"Bars_Night","Beauty_Health_Care","Cafes","GYM","Restaurants_Cuisines","Shops"
    "category": [0],
    "min_stars": 3.5,
    "price_range": 3,
    "attributes_Ambience_touristy": 1,
    "attributes_Ambience_trendy": 1,
    "attributes_Ambience_classy": 0,
    "attributes_Ambience_casual": 1,
    "intimate_or_family": 'intimate'
}

recommend_businesses(user_pref,ds,data_set)

from sklearn.metrics.pairwise import euclidean_distances

def recommend_businesses_euclidean(user_pref, data, original_df, k=3):
    user_vector = create_user_pref_vector(user_pref)
    
    # Calculate Euclidean distances
    distances = euclidean_distances(data, user_vector.reshape(1, -1)).flatten()
    
    # Find the k smallest distances (most similar)
    top_k_unsorted = np.argpartition(distances, k)[:k]
    sorted_indices = top_k_unsorted[np.argsort(distances[top_k_unsorted])]
    
    # Retrieve and return the top-k most similar businesses
    recommendations = original_df.iloc[sorted_indices][[
        "name", "stars", "attributes_RestaurantsPriceRange2", "address", "city",
        "attributes_GoodForKids", "attributes_Ambience_romantic", "attributes_Ambience_intimate",
        "attributes_Ambience_touristy", "attributes_Ambience_trendy", "attributes_Ambience_classy",
        "attributes_Ambience_casual", "Bars_Night", "Beauty_Health_Care", "Cafes",
        "GYM", "Restaurants_Cuisines", "Shops"
    ]].copy()
    
    recommendations["euclidean_distance"] = distances[sorted_indices]
    recommendations["similarity_score"] = 1 / (1 + recommendations["euclidean_distance"])
    recommendations["similarity_percent"] = (recommendations["similarity_score"] * 100).round(2).astype(str) + '%'

    
    return recommendations

user_pref = {
    "category": [0],
    "min_stars": 3.5,
    "price_range": 3,
    "attributes_Ambience_touristy": 1,
    "attributes_Ambience_trendy": 1,
    "attributes_Ambience_classy": 0,
    "attributes_Ambience_casual": 1,
    "intimate_or_family": 'intimate'
}

recommendations = recommend_businesses_euclidean(user_pref, ds, data_set)
pd.set_option('display.max_columns', None)
pd.set_option('display.max_rows', None)
pd.set_option('display.width', None)
pd.set_option('display.max_colwidth', None)
print(recommendations)


from sklearn.metrics.pairwise import manhattan_distances

def recommend_businesses_manhattan(user_pref, data, original_df, k=3):
    user_vector = create_user_pref_vector(user_pref)
    
    
    distances = manhattan_distances(data, user_vector.reshape(1, -1)).flatten()
    
    
    top_k_unsorted = np.argpartition(distances, k)[:k]
    sorted_indices = top_k_unsorted[np.argsort(distances[top_k_unsorted])]
    
    
    recommendations = original_df.iloc[sorted_indices][[
        "name", "stars", "attributes_RestaurantsPriceRange2", "address", "city",
        "attributes_GoodForKids", "attributes_Ambience_romantic", "attributes_Ambience_intimate",
        "attributes_Ambience_touristy", "attributes_Ambience_trendy", "attributes_Ambience_classy",
        "attributes_Ambience_casual", "Bars_Night", "Beauty_Health_Care", "Cafes",
        "GYM", "Restaurants_Cuisines", "Shops"
    ]].copy()
    
    
    recommendations["manhattan_distance"] = distances[sorted_indices]
    recommendations["similarity_score"] = 1 / (1 + recommendations["manhattan_distance"])
    recommendations["similarity_percent"] = (recommendations["similarity_score"] * 100).round(2).astype(str) + '%'
    
    return recommendations

user_pref = {
    "category": [0, 2, 4],
    "min_stars": 3.5,
    "price_range": 3,
    "attributes_Ambience_touristy": 0,
    "attributes_Ambience_trendy": 1,
    "attributes_Ambience_classy": 0,
    "attributes_Ambience_casual": 1,
    "intimate_or_family": 'family'
}

recommendations = recommend_businesses_manhattan(user_pref, ds, data_set)
print(recommendations)

touristy_count = data_set['attributes_Ambience_touristy'].sum()
print(f"Total touristy locations in dataset: {touristy_count}")





