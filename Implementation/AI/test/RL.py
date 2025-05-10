# this would be applying RL without clustring

import pandas as pd
import os

#get path of the curr project
print(os.getcwd())



df = pd.read_csv('DataSet/lateset Dataset Main/pre_processed_df.csv')
print(df.head())