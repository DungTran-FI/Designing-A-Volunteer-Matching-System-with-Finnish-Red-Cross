# import all necessary modules
import psycopg2
from psycopg2 import Error
from sqlalchemy import create_engine
import matplotlib.pyplot as plt
import seaborn as sns
import pandas as pd
from pathlib import Path
import textwrap
import nltk
from nltk.corpus import stopwords
from nltk.tokenize import word_tokenize
import re
nltk.download('punkt')
nltk.download('stopwords')
import warnings

warnings.filterwarnings('ignore', category=UserWarning)

def main():
    DATADIR = str(Path(__file__).parent)  # for relative path
    print(DATADIR)
    database = "group_20_2024"
    user = "group_20_2024"
    password = "Z8hiCxRFEWdY"
    host = "dbcourse.cs.aalto.fi"
    port = "5432"
    # use connect function to establish the connection
    try:
        # Connect the postgres database from your local machine using psycopg2
        connection = psycopg2.connect(
            database=database, user=user, password=password, host=host, port=port
        )
        connection.autocommit = True

        # Create a cursor to perform database operations
        cursor = connection.cursor()
        # Print PostgreSQL details
        print("PostgreSQL server information")
        print(connection.get_dsn_parameters(), "\n")
        # Executing a SQL query
        cursor.execute("SELECT version();")
        # Fetch result
        record = cursor.fetchone()
        print("You are connected to - ", record, "\n")

        # Connect to db using SQLAlchemy create_engine
        DIALECT = "postgresql+psycopg2://"
        db_uri = "%s:%s@%s/%s" % (user, password, host, database)
        print(DIALECT + db_uri)
        engine = create_engine(DIALECT + db_uri)
        psql_conn = engine.connect()
    except (Exception, Error) as error:
        print("Error while connecting to PostgreSQL", error)
    #finally:
        #if connection:
            #psql_conn.close()
            # cursor.close()
            #connection.close()
            #print("PostgreSQL connection is closed")

    # Reading Excel file
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

    ### Analysis
    #### q1
    volunteer_count_by_city_query = """
                                SELECT 
                                    c.name AS city_name,
                                    COUNT(DISTINCT vr.volunteer_id) AS volunteer_count
                                FROM 
                                    city c
                                JOIN 
                                    volunteer_range vr ON c.id = vr.city_id
                                GROUP BY 
                                    c.name
                                order by volunteer_count desc;
                                """
    volunteer_count_by_city_df = pd.read_sql_query(volunteer_count_by_city_query, psql_conn)
    # Create a figure and axis object
    fig, ax = plt.subplots(figsize=(12, 6))

    # Plot the number of rainy days per month for the current location
    volunteer_count_by_city_df.plot(x='city_name', y='volunteer_count', kind='barh', ax=ax)

    # Set the plot title and axis labels
    ax.set_title(f'Number of volunteers available by city')
    ax.set_xlabel('City')
    ax.set_ylabel('Number of volunteer')

    # Adjust the spacing and display the plot
    plt.tight_layout()
    plt.show()

    volunteer_application_count_by_city_query = """
                                SELECT 
                                    c.name AS city_name,
                                    COUNT(DISTINCT va.volunteer_id) AS volunteer_application_count
                                FROM 
                                    city c
                                JOIN 
                                    request_location rl ON c.id = rl.city_id
                                JOIN 
                                    volunteer_application va ON rl.request_id = va.request_id
                                GROUP BY 
                                    c.name
                                order by volunteer_application_count desc;
                                    """
    volunteer_application_count_by_city_df = pd.read_sql_query(volunteer_application_count_by_city_query, psql_conn)
    # Create a figure and axis object
    fig, ax = plt.subplots(figsize=(12, 6))

    # Plot the number of rainy days per month for the current location
    volunteer_application_count_by_city_df.plot(x='city_name', y='volunteer_application_count', kind='barh', ax=ax)

    # Set the plot title and axis labels
    ax.set_title(f'Number of volunteer applications by city')
    ax.set_xlabel('City')
    ax.set_ylabel('Number of volunteer applications')
    # Adjust the spacing and display the plot
    plt.tight_layout()
    plt.show()

    volunteer_apply_to_request_by_city_query = """
                                WITH volunteer_counts AS (
                                    -- Number of volunteers available by city
                                    SELECT 
                                        c.name AS city_name,
                                        COUNT(DISTINCT vr.volunteer_id) AS volunteer_count
                                    FROM 
                                        city c
                                    JOIN 
                                        volunteer_range vr ON c.id = vr.city_id
                                    GROUP BY 
                                        c.name
                                ),
                                application_counts AS (
                                    -- Number of volunteers that applied for a request in that city
                                    SELECT 
                                        c.name AS city_name,
                                        COUNT(DISTINCT va.volunteer_id) AS volunteer_application_count
                                    FROM 
                                        city c
                                    JOIN 
                                        request_location rl ON c.id = rl.city_id
                                    JOIN 
                                        volunteer_application va ON rl.request_id = va.request_id
                                    GROUP BY 
                                        c.name
                                )
                                -- Combine the results
                                SELECT 
                                    COALESCE(vc.city_name, ac.city_name) AS city_name,
                                    COALESCE(vc.volunteer_count, 0) AS volunteer_count,
                                    COALESCE(ac.volunteer_application_count, 0) AS volunteer_application_count
                                FROM 
                                    volunteer_counts vc
                                FULL OUTER JOIN 
                                    application_counts ac ON vc.city_name = ac.city_name
                                ORDER BY 
                                    volunteer_count DESC, volunteer_application_count DESC;
                                """
    volunteer_apply_to_request_by_city_df = pd.read_sql_query(volunteer_apply_to_request_by_city_query, psql_conn)

    # Melt the DataFrame for easier plotting with seaborn
    melted_df = volunteer_apply_to_request_by_city_df.melt(id_vars='city_name', var_name='Type', value_name='Count')

    # Create the bar plot
    plt.figure(figsize=(12, 6))
    sns.barplot(x='city_name', y='Count', hue='Type', data=melted_df)

    # Adding titles and labels
    plt.title('Number of Volunteer available vs. Number of Volunteer Applications per City')
    plt.xlabel('City')
    plt.ylabel('Count')
    plt.legend(title='Type')
    plt.grid(True)

    # Display the plot
    plt.show()

    #### q2
    ##### data pre-processing
    # normalize interest name in dataframe interest_df and interest_assignment_df
    interest_df['name'] = interest_df['name'].apply(lambda x: ' '.join(re.findall(r'[A-Z][a-z]*', x)).lower())
    interest_assignment_df['interest_name'] = interest_assignment_df['interest_name'].apply(
        lambda x: ' '.join(re.findall(r'[A-Z][a-z]*', x)).lower())

    # function to remove ' needed' from the end of the string
    def remove_needed(s):
        if s.endswith(" needed"):
            s = s[:-7]
        return s
    # remove ' needed' from the end of the string in column title of request dataframe
    request_df['title'] = request_df['title'].apply(remove_needed)

    # select only volunteer with valid application
    volunteer_valid = pd.merge(volunteer_df, volunteer_application_df, left_on='id', right_on='volunteer_id',
                               how='inner')
    volunteer_valid = volunteer_valid[volunteer_valid['is_valid'] == True]

    # Function to measure similarity between two sentences using cosine similarity

    def calculate_similarity(X, Y):
        # tokenization
        X_list = word_tokenize(X)
        Y_list = word_tokenize(Y)

        # sw contains the list of stopwords
        sw = stopwords.words('english')
        l1 = [];
        l2 = []

        # remove stop words from the string
        X_set = {w for w in X_list if not w in sw}
        Y_set = {w for w in Y_list if not w in sw}

        # form a set containing keywords of both strings
        rvector = X_set.union(Y_set)
        for w in rvector:
            if w in X_set:
                l1.append(1)  # create a vector
            else:
                l1.append(0)
            if w in Y_set:
                l2.append(1)
            else:
                l2.append(0)
        c = 0

        # cosine formula
        for i in range(len(rvector)):
            c += l1[i] * l2[i]
        return c / float((sum(l1) * sum(l2)) ** 0.5)

    def calculate_travel_score(volunteer_city, request_city, willing_to_travel_minutes, city_range, scale=20):
        willing_to_travel = willing_to_travel_minutes > 10
        willing_to_travel_long = willing_to_travel_minutes > 120
        if volunteer_city == request_city:
            return scale
        if request_city in city_range:
            if willing_to_travel:
                return scale
            return scale / 2
        if willing_to_travel:
            return scale / 2 if willing_to_travel_long else 4
        return 0

    # Calculate scores
    def calculate_matching_scores():
        results = []

        for index, request in request_df.iterrows():
            matching_interest = 'none'
            # we can tweak the initial value to set the threshold for detecting a match
            max_seen_interest_match = 0.49
            request_title = request['title']
            for _, interest in interest_df.iterrows():
                interest_match = calculate_similarity(interest['name'], request_title)
                # print(f"Matching '{interest['name']}' and '{request_title}'. Match is {interest_match}")
                if interest_match > max_seen_interest_match:
                    max_seen_interest_match = interest_match
                    matching_interest = interest['name']

            request_id = request['id']
            request_city_id = request_location_df[request_location_df['request_id'] == request_id]['city_id'].values[0]
            request_skills = request_skill_df[request_skill_df['request_id'] == request_id]['skill_name'].tolist()
            num_request_skills = len(request_skills)

            applicable_volunteers = volunteer_valid[volunteer_valid['request_id'] == request_id]
            for _, volunteer in applicable_volunteers.iterrows():
                volunteer_id = volunteer['volunteer_id']
                volunteer_skills = skill_assignment_df[skill_assignment_df['volunteer_id'] == volunteer_id][
                    'skill_name'].tolist()
                volunteer_city_id = volunteer['city_id']
                volunteer_travel_readiness = volunteer['travel_readiness']
                volunteer_interests = interest_assignment_df[interest_assignment_df['volunteer_id'] == volunteer_id][
                    'interest_name'].tolist()
                volunteer_range = volunteer_range_df[volunteer_range_df['volunteer_id'] == volunteer_id][
                    'city_id'].tolist()

                # Skill Matches
                skill_matches = sum(1 for skill in request_skills if skill in volunteer_skills)
                skill_score = 0 if num_request_skills == 0 else (skill_matches / num_request_skills) * 40

                # Travel Readiness
                travel_readiness_score = calculate_travel_score(volunteer_city_id, request_city_id,
                                                                volunteer_travel_readiness, volunteer_range)

                # Volunteer Range (need to include all city in city range, not only city of volunteer)
                volunteer_range_score = 20 if volunteer_city_id == request_city_id else 0

                # Interest Matches
                interest_score = 20 if matching_interest in volunteer_interests else 0

                # Total Score
                max_score = 40 + 20 + 20
                total_score = (skill_score + travel_readiness_score + interest_score) / max_score

                results.append({
                    'request_id': request_id,
                    'volunteer_id': volunteer_id,
                    'total_score': total_score
                })

        return pd.DataFrame(results)

    # Suggest top 5 candidates for each request
    def suggest_top_candidates(score_df):
        top_candidates = {}

        for request_id in score_df['request_id'].unique():
            top_candidates_for_request = score_df[score_df['request_id'] == request_id].nlargest(5, 'total_score')
            top_candidates[request_id] = top_candidates_for_request

        return top_candidates

    # Calculate scores and get top candidates
    score_df = calculate_matching_scores()
    top_candidates = suggest_top_candidates(score_df)

    # Display top 5 candidates for each request
    for request_id, candidates in top_candidates.items():
        print(f"Request ID {request_id} Top 5 Candidates:")
        for _, candidate in candidates.iterrows():
            print(
                f"  Volunteer ID: {candidate['volunteer_id']} Matching_percentage: {candidate['total_score'] * 100:.2f} %")

    #### q3
    # Dataframe to find the number of valid request per month
    request_to_check_valid = request_df[['id', 'start_date', 'end_date']]

    # Function to determine valid months
    def get_valid_months(row):
        start_month = row['start_date'].month
        end_month = row['end_date'].month
        if start_month == end_month:
            return [start_month]
        elif start_month < end_month:
            return list(range(start_month, end_month + 1))
        else:
            return list(range(start_month, 13)) + list(range(1, end_month + 1))

    # Apply the function to get valid months for each row
    request_to_check_valid.loc[:, 'valid_months'] = request_to_check_valid.apply(get_valid_months, axis=1)

    # Create a new DataFrame to store the results
    valid_requests_per_month = []

    for _, row in request_to_check_valid.iterrows():
        for month in row['valid_months']:
            valid_requests_per_month.append({'id': row['id'], 'month': month})

    # Convert the list to a DataFrame
    valid_requests_per_month_df = pd.DataFrame(valid_requests_per_month)

    # print(valid_requests_per_month_df)

    # Group by month and count the number of requests
    requests_count_per_month = valid_requests_per_month_df.groupby('month').size().reset_index(
        name='number_of_valid_request')

    # Sort the DataFrame by 'number_of_valid_request' in descending order
    requests_count_per_month_sorted = requests_count_per_month.sort_values(by='number_of_valid_request',
                                                                           ascending=False)
    # Create a figure and axis object
    fig, ax = plt.subplots(figsize=(12, 6))

    # Plot the number of rainy days per month for the current location
    requests_count_per_month_sorted.plot(x='month', y='number_of_valid_request', kind='bar', ax=ax)

    # Set the plot title and axis labels
    ax.set_title(f'Number of valid request per month')
    ax.set_xlabel('Month')
    ax.set_ylabel('Number of valid request')

    # Adjust the spacing and display the plot
    plt.tight_layout()
    plt.show()

    # Dataframe to find the valid volunteer by month
    volunteer_valid = volunteer_application_df[['id', 'modified', 'is_valid']]

    # Filter the DataFrame to include only valid applications
    valid_volunteer = volunteer_valid[volunteer_valid['is_valid']]

    # Extract year and month from the modified column
    valid_volunteer.loc[:, 'month'] = valid_volunteer['modified'].dt.month

    # Group by month and count the number of valid applications per month
    valid_volunteer_per_month = valid_volunteer.groupby('month').size().reset_index(
        name='number_of_valid_volunteer_applications')

    valid_volunteer_per_month_sorted = valid_volunteer_per_month.sort_values(
        by='number_of_valid_volunteer_applications', ascending=False)

    # Create a figure and axis object
    fig, ax = plt.subplots(figsize=(12, 6))

    # Plot the number of rainy days per month for the current location
    valid_volunteer_per_month_sorted.plot(x='month', y='number_of_valid_volunteer_applications', kind='bar', ax=ax)

    # Set the plot title and axis labels
    ax.set_title(f'Number of valid volunteer application per month')
    ax.set_xlabel('Month')
    ax.set_ylabel('Number of valid volunteer applications')

    # Adjust the spacing and display the plot
    plt.tight_layout()
    plt.show()

    # Left join on the common column 'month'
    request_vs_volunteer_per_month = pd.merge(requests_count_per_month, valid_volunteer_per_month, on='month',
                                              how='left')
    # The difference between the requests and volunteers for each month
    request_vs_volunteer_per_month['deviation'] = request_vs_volunteer_per_month[
                                                      'number_of_valid_volunteer_applications'] - \
                                                  request_vs_volunteer_per_month['number_of_valid_request']
    request_vs_volunteer_deviation_per_month_sorted = request_vs_volunteer_per_month[
        ['month', 'deviation']].sort_values(by='deviation', ascending=False)

    # Calculate the average deviation
    request_average_deviation = request_vs_volunteer_deviation_per_month_sorted['deviation'].mean()

    # Create a figure and axis object
    fig, ax = plt.subplots(figsize=(12, 6))

    # Plot the number of rainy days per month for the current location
    request_vs_volunteer_deviation_per_month_sorted.plot(x='month', y='deviation', kind='bar', ax=ax)

    # Plot the average line
    plt.axhline(y=request_average_deviation, color='r', linestyle='--', label='Average Deviation')

    # Set the plot title and axis labels
    ax.set_title(f'Number of deviation between request volunteer applications')
    ax.set_xlabel('Month')
    ax.set_ylabel('Number of deviation between request volunteer applications')

    # Adjust the spacing and display the plot
    plt.tight_layout()
    plt.show()

    # Overview of Valid Requests vs. Valid Volunteer Applications per Month
    request_vs_volunteer_per_month.drop(columns=['deviation'], inplace=True)
    # print(request_vs_volunteer_per_month)
    # Melt the DataFrame for easier plotting with seaborn
    melted_df = request_vs_volunteer_per_month.melt(id_vars='month', var_name='Type', value_name='Count')

    # Create the bar plot
    plt.figure(figsize=(12, 6))
    sns.barplot(x='month', y='Count', hue='Type', data=melted_df)

    # Adding titles and labels
    plt.title('Number of Valid Requests vs. Valid Volunteer Applications per Month')
    plt.xlabel('Month')
    plt.ylabel('Count')
    plt.legend(title='Type')
    plt.grid(True)

    # Display the plot
    plt.show()

    # inspect any correlation between the time of the year and number of requests and volunteers
    corr_point = request_vs_volunteer_per_month.select_dtypes("number").corr()
    plt.figure(figsize=(12, 6))
    sns.heatmap(corr_point, annot=True, cmap='BuPu', fmt=".2f")
    plt.title("Correlation Heatmap")
    plt.show()

    #### q4
    ##### Free choice analysis: Identifying High-Demand, Low-Supply Skills
    skill_demand_and_supply_trend_query = """
                                                    WITH skill_demand AS (
                                                            SELECT skill_name,
                                                                   COUNT(1) AS number_of_skilled_volunteer_demand
                                                            FROM request_skill
                                                            GROUP BY skill_name
                                                        ),
                                                        skill_supply AS (
                                                            SELECT skill_name, 
                                                                   COUNT(DISTINCT volunteer_id) 
                                                                   AS number_of_skilled_volunteer_supply
                                                            FROM skill_assignment
                                                            GROUP BY skill_name
                                                        )
                                                            SELECT sd.skill_name,
                                                                   sd.number_of_skilled_volunteer_demand,
                                                                   ss.number_of_skilled_volunteer_supply,
                                                                   sd.number_of_skilled_volunteer_demand - ss.number_of_skilled_volunteer_supply as deviation
                                                            FROM skill_demand sd
                                                            LEFT JOIN skill_supply ss ON sd.skill_name = ss.skill_name
                                                            ORDER BY deviation DESC;

                                                    """
    skill_demand_and_supply_trend_query_df = pd.read_sql_query(skill_demand_and_supply_trend_query, psql_conn)

    # Plot the overal trend
    # Melt the DataFrame for easier plotting with seaborn
    melted_df = skill_demand_and_supply_trend_query_df.melt(id_vars='skill_name', var_name='Type', value_name='Count')

    # Create the stacked bar plot
    sns.set_theme(style='darkgrid', rc={'figure.dpi': 147}, font_scale=0.7)
    fig, ax = plt.subplots(figsize=(12, 6))
    sns.barplot(x='skill_name', y='Count', hue='Type', data=melted_df)
    # Adding titles and labels
    ax.set_title('Number of Volunteer skill demand vs. Number of Volunteer skill supply per Skill')
    plt.xlabel('Skill name', fontsize=10)

    # Use helping function to wrapping the overlapping text labels on the x-axis at a given width
    def wrap_labels(ax, width, break_long_words=False):
        labels = []
        for label in ax.get_xticklabels():
            text = label.get_text()
            labels.append(textwrap.fill(text, width=width,
                                        break_long_words=break_long_words))
        ax.set_xticklabels(labels, rotation=0)

    wrap_labels(ax, 10)
    ax.figure
    # Display the plot
    plt.show()

    # Plot the deviation trend
    skill_demand_and_supply_deviation_query = """
    WITH skill_demand AS (
            SELECT skill_name,
                   COUNT(1) AS number_of_skilled_volunteer_demand
            FROM request_skill
            GROUP BY skill_name
        ),
        skill_supply AS (
            SELECT skill_name, 
                   COUNT(DISTINCT volunteer_id) 
                   AS number_of_skilled_volunteer_supply
            FROM skill_assignment
            GROUP BY skill_name
        )
            SELECT sd.skill_name,
                   sd.number_of_skilled_volunteer_demand - ss.number_of_skilled_volunteer_supply as deviation
            FROM skill_demand sd
            LEFT JOIN skill_supply ss ON sd.skill_name = ss.skill_name
            ORDER BY deviation DESC;

                                                            """
    skill_demand_and_supply_deviation_query_df = pd.read_sql_query(skill_demand_and_supply_deviation_query, psql_conn)

    # The difference between the requests and volunteers for each month
    skill_demand_and_supply_deviation_query_df_sorted = skill_demand_and_supply_deviation_query_df[
        ['skill_name', 'deviation']].sort_values(by='deviation', ascending=False)

    # Calculate the average deviation
    skill_average_deviation = skill_demand_and_supply_deviation_query_df_sorted['deviation'].mean()

    # Create a figure and axis object
    fig, ax = plt.subplots(figsize=(12, 6))

    # Plot the number of rainy days per month for the current location
    skill_demand_and_supply_deviation_query_df_sorted.plot(x='skill_name', y='deviation', kind='bar', ax=ax)

    # Plot the average line
    plt.axhline(y=skill_average_deviation, color='r', linestyle='--', label='Skill Average Deviation')
    wrap_labels(ax, 10)
    ax.figure

    # Set the plot title and axis labels
    ax.set_title(f'Number of deviation between skill demand vs skill supply')
    ax.set_xlabel('Skill name')
    ax.set_ylabel('Number of deviation between skill demand vs skill supply')
    # Display the plot
    plt.show()
main()
