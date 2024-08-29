
import psycopg2
from psycopg2 import Error
from sqlalchemy import create_engine, text
import pandas as pd
import numpy as np
from pathlib import Path
import re

def run_sql_from_file(sql_file, psql_conn):
    sql_command = ""
    for line in sql_file:
        # if line.startswith('VALUES'):
        # Ignore commented lines
        if not line.startswith("--") and line.strip("\n"):
            # Append line to the command string, prefix with space
            sql_command += " " + line.strip("\n")
            # sql_command = ' ' + sql_command + line.strip('\n')
        # If the command string ends with ';', it is a full statement
        if sql_command.endswith(";"):
            # Try to execute statement and commit it
            try:
                # print("running " + sql_command+".")
                psql_conn.execute(text(sql_command))
                # psql_conn.commit()
            # Assert in case of error
            except:
                print("Error at command:" + sql_command + ".")
                ret_ = False
            # Finally, clear command string
            finally:
                sql_command = ""
                ret_ = True
    return ret_


def main():
    DATADIR = str(Path(__file__).parent)  # for relative path
    print(DATADIR)

    # Group 20 credentials:
    database = "group_20_2024"
    user = "group_20_2024"
    password = "Z8hiCxRFEWdY"
    host = "dbcourse.cs.aalto.fi"
    # port = "5432"

    # The below variable is to create a new database (if not yet created). Here since we already had 'group_20_2024' database created, we just need to connect to this database:
    # new_database = "group_20_2024"

    # use connect function to establish the connection
    try:
        # Connect the postgres database from our local machine using psycopg2
        connection = psycopg2.connect(
            database=database, user=user, password=password, host=host #port=port
        )
        connection.autocommit = True

        # Create a cursor to perform database operations
        cursor = connection.cursor()

        # Create a 'Group 20_2024' database by SQL query:
        # cursor.execute(f'DROP DATABASE IF EXISTS {new_database};')
        # cursor.execute(f'CREATE DATABASE {new_database};')

        # Print PostgreSQL details:
        print("PostgreSQL server information")
        print(connection.get_dsn_parameters(), "\n")
        # Executing a SQL query
        cursor.execute("SELECT version();")
        # Fetch result
        record = cursor.fetchone()
        print("You are connected to - ", record, "\n")

        # Step 1: Create an engine to the database:
        DIALECT = "postgresql+psycopg2://"

        # if a new database need to be created, use:
        # db_uri = "%s:%s@%s/%s" % (user, password, host, new_database)

        # in this case, since we already had 'group_20_2024' database created, we just connect to this database:
        db_uri = "%s:%s@%s/%s" % (user, password, host, database)
        print(DIALECT + db_uri)
        engine = create_engine(DIALECT + db_uri)
        sql_file1 = open(DATADIR + "/create_and_file_db_psql.sql")
        psql_conn = engine.connect()

        # Step 2: Read SQL file for CREATE TABLE

        # run statements to create tables
        run_sql_from_file(sql_file1, psql_conn)

    except (Exception, Error) as error:
        print("Error while connecting to PostgreSQL", error)


    # Reading Excel file:

    # Read all sheets into a dictionary of DataFrames
    file_path = "data.xlsx"
    all_sheets = pd.read_excel(file_path, sheet_name=None)

    # Split file into 12 dataframes
    city_df = all_sheets['city']
    volunteer_df = all_sheets['volunteer']
    volunteer_range_df = all_sheets['volunteer_range']
    skill_df = all_sheets['skill']
    skill_assignment_df = all_sheets['skill_assignment']
    interest_df = all_sheets['interest']
    interest_assignment_df = all_sheets['interest_assignment']
    beneficiary_df = all_sheets['beneficiary']
    request_df = all_sheets['request']
    request_skill_df = all_sheets['request_skill']
    request_location_df = all_sheets['request_location']
    volunteer_application_df = all_sheets['volunteer_application']

    # Data cleaning:

    # 1. Split geolocation into latitude and longitude:
        # Step 1: split latitude, longitude by the symbol "/":
    city_df[['latitude', 'longitude']] = city_df['geolocation'].str.split('/', expand=True)
        # Step 2: define data type of these columns as float:
    city_df[['latitude', 'longitude']] = city_df[['latitude', 'longitude']].astype(float)
        # Step 3: Remove 'geolocation' column:
    city_df.drop(columns=['geolocation'], inplace=True)

    # 2. Modify skill & interest names by adding blank spaces between words:
    skill_df['name'] = skill_df['name'].apply(lambda x: ' '.join(re.findall(r'[A-Z][a-z]*', x)))

    skill_assignment_df['skill_name'] = skill_assignment_df['skill_name'].apply(
        lambda x: ' '.join(re.findall(r'[A-Z][a-z]*', x)))

    request_skill_df['skill_name'] = request_skill_df['skill_name'].apply(
        lambda x: ' '.join(re.findall(r'[A-Z][a-z]*', x)))

    interest_df['name'] = interest_df['name'].apply(lambda x: ' '.join(re.findall(r'[A-Z][a-z]*', x)))

    interest_assignment_df['interest_name'] = interest_assignment_df['interest_name'].apply(
        lambda x: ' '.join(re.findall(r'[A-Z][a-z]*', x)))

    # 3. Convert is_valid = True/False to 0,1 so that it can be imported to SQL:
    volunteer_application_df['is_valid'] = volunteer_application_df['is_valid'].apply(lambda x: 1 if x else 0)


    # From DataFrame to SQL table:
    city_sqltbl = 'city'
    volunteer_sqltbl = 'volunteer'
    volunteer_range_sqltbl = 'volunteer_range'
    skill_sqltbl = 'skill'
    skill_assignment_sqltbl = 'skill_assignment'
    interest_sqltbl = 'interest'
    interest_assignment_sqltbl = 'interest_assignment'
    beneficiary_sqltbl = 'beneficiary'
    request_sqltbl = 'request'
    request_skill_sqltbl = 'request_skill'
    request_location_sqltbl = 'request_location'
    volunteer_application_sqltbl = 'volunteer_application'

    city_df.to_sql(city_sqltbl, con=psql_conn, if_exists="append", index=False)
    volunteer_df.to_sql(volunteer_sqltbl, con=psql_conn, if_exists="append", index=False)
    volunteer_range_df.to_sql(volunteer_range_sqltbl, con=psql_conn, if_exists="append", index=False)
    skill_df.to_sql(skill_sqltbl, con=psql_conn, if_exists="append", index=False)
    skill_assignment_df.to_sql(skill_assignment_sqltbl, con=psql_conn, if_exists="append", index=False)
    interest_df.to_sql(interest_sqltbl, con=psql_conn, if_exists="append", index=False)
    interest_assignment_df.to_sql(interest_assignment_sqltbl, con=psql_conn, if_exists="append", index=False)
    beneficiary_df.to_sql(beneficiary_sqltbl, con=psql_conn, if_exists="append", index=False)
    request_df.to_sql(request_sqltbl, con=psql_conn, if_exists="append", index=False)
    request_skill_df.to_sql(request_skill_sqltbl, con=psql_conn, if_exists="append", index=False)
    request_location_df.to_sql(request_location_sqltbl, con=psql_conn, if_exists="append", index=False)
    volunteer_application_df.to_sql(volunteer_application_sqltbl, con=psql_conn, if_exists="append", index=False)

    psql_conn.commit()
    psql_conn.close()

    print("PostgreSQL connection is closed")

main()
