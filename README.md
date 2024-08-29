# Designing a Volunteer Matching System (VMS) with the Finnish Red Cross (FRC)

Welcome to the **Volunteer Matching System (VMS)** project! This project is part of the "Databases for Data Science" course at Aalto University and is designed to demonstrate advanced database design and SQL skills. The goal is to develop a relational database to match Red Cross Volunteer Capacity (supply) with Local Multidimensional Vulnerabilities and Crises (demand).

## Table of Contents

- [Project Overview](#project-overview)
- [Purpose & Objectives](#purpose--objectives)
- [Synthetic Dataset](#synthetic-dataset)
- [Tasks](#tasks)
- [Database Design](#database-design)
  - [Part 1: UML and Relational Model](#part-1-uml-and-relational-model)
  - [Part 2: SQL Implementation](#part-2-sql-implementation)
- [Finnish Red Cross](#finnish-red-cross)
- [Disclaimer - Group Contribution](#disclaimer)


## Project Overview

The **Volunteer Matching System (VMS)** aims to create a database that efficiently matches volunteer resources with the needs arising from local crises. The system includes managing volunteer profiles, tracking requests, and optimizing volunteer-to-request matches.

## Purpose & Objectives

The primary objectives of this project are:
1. **Database Design:** Develop a comprehensive relational schema to model volunteers, requests, and their interactions.
2. **SQL Implementation:** Write SQL queries to manage and analyze data, including advanced features such as views, triggers, and functions.
3. **Data Analysis:** Use data to gain insights into volunteer and request dynamics, including trends and matching effectiveness.

## Synthetic Dataset

This project uses a **synthetic dataset** to simulate real-world scenarios. The synthetic data provides a controlled environment to test and validate the database design and SQL queries, ensuring that the system performs as expected before applying it to real data.

## Tasks

1. **Part 1: UML and Relational Model**
   - Create a UML diagram for the VMS database.
   - Convert the UML diagram to a relational schema.
   - Normalize the database and address any anomalies.

2. **Part 2: SQL Implementation**
   - Implement [SQL queries](Queries.sql) based on the synthetic data. 
   - Develop views, triggers, and functions as specified.
   - Perform data analysis and generate meaningful insights.

### Addition

- **Predictive Analytics:** Apply machine learning techniques to enhance the system's functionality.
- **Advanced Queries and Analysis:** Extend the database with complex queries and analytical features.

## Database Design

### Part 1: UML and Relational Model

- **Beneficiaries:** Unique IDs, names, addresses, and requests with details such as urgency and skill requirements.
- **Volunteers:** Unique IDs, names, skills, and availability.
- **Applications:** Track volunteer applications, validity, and modification details.
- **Volunteer Ranges and Cities:** Manage geographic distribution of volunteers.

### Part 2: SQL Implementation

- **Queries:** Manage and analyze volunteer and request data using SQL.
- **Advanced Features:** Implement views, triggers, and functions to enhance database functionality.
- **Data Analysis:** Visualize and analyze trends in volunteer availability and request fulfillment.

## Finnish Red Cross

The Finnish Red Cross is a major NGO in Finland focused on humanitarian aid. This project supports their mission by improving volunteer management through an effective database system.

For more information, refer to the [Finnish Red Cross / Suomen Punainen Risti website](https://www.redcross.fi/become-a-volunteer/?_gl=1*xmfpbl*_up*MQ..*_ga*MTA3NzMyMjgxLjE3MjI4NjUyOTI.*_ga_FMVLRNR4HM*MTcyMjg2NTI5MS4xLjAuMTcyMjg2NTI5MS4wLjAuMA..&gclid=Cj0KCQjw8MG1BhCoARIsAHxSiQmhio6MkeJXUGnz6DpHNzLAp39_tJ-SYiANoQmIi_Kt09lDjCd7V6QaAqcMEALw_wcB).

## Disclaimer
This project was developed as a group assignment for the "Databases for Data Science" course at Aalto University. While the design, implementation, and analysis aspects of the project were collaboratively completed by the team, each individual contributed to specific parts of the project.

The work presented here includes contributions from all team members, and the final deliverables reflect a collective effort. When showcasing this project in a personal portfolio, it is important to acknowledge that it was a group effort. The skills demonstrated and the results achieved are representative of the collaborative work undertaken by the team as a whole.
