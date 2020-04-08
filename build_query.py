from psycopg2 import Error
from database import CursorFromConnectionFromPool
import sys


def build_query(table_name, json_dict):
    print("\ntable name for JSON data: ", table_name)

    print("\nJSON records object type:", type(json_dict))  # should return "<class 'list'>"

    # concatenate an SQL string
    sql_string = 'INSERT INTO {} '.format(table_name)

    # if record list then get column names from first key
    if type(json_dict) == list:
        first_record = json_dict[0]

        # get the column names from the first record
        columns = list(first_record.keys())
        print("\ncolumns name: ", columns)

    # if just one dict obj or nested JSON dict
    else:
        print("Needs to be an array of JSON objects")
        sys.exit

    # enclose the column names within parenthesis
    sql_string += "(" + ', '.join(columns) + ")\nVALUES "

    # enumerate of the record
    for i, record_dict in enumerate(json_dict):

        # iterate over the values of each record dict object
        values = []
        null_val = 'NULL'
        for col_names, val in record_dict.items():

            # Postgres strings must be enclosed with single quotes
            if type(val) == str:
                # escape apostrophes with two single quotations
                val = val.replace("'", "''")
                val = "'" + val + "'"
            elif val is None:
                val = null_val

            values += [str(val)]

        # join the list of values and enclose record in parenthesis
        sql_string += "(" + ', '.join(values) + "),\n"

    # remove the last comma and end statement with a semicolon
    sql_string = sql_string[:-2] + ";"

    print("\nSQL string")
    print(sql_string)

    with CursorFromConnectionFromPool() as cursor:
        # only attempt to execute SQL if cursor is valid
        if cursor:

            try:
                cursor.execute(sql_string)

            except(Exception, Error) as error:
                print("\nexecute_sql() error: ", error)
