import json
import sys

from psycopg2 import connect, Error

# default table name
table_name = "json_data"

print("\ntable name for JSON data: ", table_name)

# use Python's open() function to load the JSON data
with open('C:/Users/paulp/Desktop/Cariboo Project/Caribou Data/Caribou/Json/GCPB_CARIBOU_POPULATION_SP.geojson') as json_data:
    # use load() rather than loads() for JSON files
    record_list = json.load(json_data)

print("\nrecords:", record_list)
print("\nJSON records object type:", type(record_list))  # should return "<class 'list'>"

# if record list then get column names from first key
if type(record_list) == list:
    first_record = record_list[0]

    # get the column names from the first record
    columns = list(first_record.keys())
    print("\ncolumns name: ", columns)

# if just one dict obj or nested JSON dict
else:
    print("Needs to be an array of JSON objects")
    sys.exit()
