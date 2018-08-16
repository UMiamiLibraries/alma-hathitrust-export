#!/usr/bin/python
import pandas as pd
file = 'miami.edu_serials_2018-0702.tsv'
df = pd.read_csv(file)
df = df.drop_duplicates()
df.to_csv(file, sep='\t') 
