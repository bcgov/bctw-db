import json
import sys

from psycopg2 import connect, Error

# default table name
table_name = "json_data"

print("\ntable name for JSON data: ", table_name)

# use Python's open() function to load the JSON data
with open('C:/Users/paulp/Desktop/Python_JSON/test.json') as json_data:
    # use load() rather than loads() for JSON files
    record_list = json.load(json_data)

print("\nrecords:", record_list)
print("\nJSON records object type:", type(record_list))  # should return "<class 'list'>"

# concatenate an SQL string
sql_string = 'INSERT INTO {} '.format(table_name)

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

# enclose the column names within parenthesis
sql_string += "(" + ', '.join(columns) + ")\nVALUES "

# enumerate over the record
for i, record_dict in enumerate(record_list):

    # iterate over the values of each record dict object
    values = []
    for col_names, val in record_dict.items():

        # Postgres strings must be enclosed with single quotes
        if type(val) == str:
            # escape apostrophes with two single quotations
            val = val.replace("'", "''")
            val = "'" + val + "'"

        values += [str(val)]

    # join the list of values and enclose record in parenthesis
    sql_string += "(" + ', '.join(values) + "),\n"

# remove the last comma and end statement with a semicolon
sql_string = sql_string[:-2] + ";"

print("\nSQL string:")
print(sql_string)

try:
    # declare a new PostgreSQL connection object
    conn = connect(
        dbname="python_json",
        user="postgres",
        host="127.0.0.1",
        password="Ch3k@v88",
        # attempt to connect for 3 seconds then raise exception
        connect_timeout=3
    )

    cur = conn.cursor()
    print("\ncreate cursor object: ", cur)

except (Exception, Error) as err:
    print("\npsycopg2 connect error: ", err)
    conn = None
    cur = None

# only attempt to execute SQL if cursor is valid
if cur:

    try:
        cur.execute(sql_string)
        conn.commit()

        print('\nfinnish INSERT INTO execution')

    except (Exception, Error) as error:
        print("\nexecute_sql() error: ", error)

    # close the cursor and connection
    cur.close()
    conn.close()