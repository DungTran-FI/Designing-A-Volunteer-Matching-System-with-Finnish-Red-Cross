/* Additional data processing: 
 * As 'request' and 'volunteer_application' has ID as Serial, we need to resynchronize the sequence with the following command:
 * This command sets the sequence to the maximum current value in the id column, ensuring the next id generated will be unique.
 */

/*SELECT setval('volunteer_application_id_seq', (SELECT MAX(id) FROM volunteer_application));*/
/*SELECT setval('request_id_seq', (SELECT MAX(id) FROM request));*/



-- A - BASIC

-- A.1 For each request, include the starting date and the end date in the title.

      /* Note: Format start_date, end_date into YY-MM-DD (exclude time)*/

/*UPDATE request 
SET title = title || ' from ' || TO_CHAR(start_date, 'YYYY-MM-DD HH24:MI:SS') || ' to ' || TO_CHAR(end_date, 'YYYY-MM-DD HH24:MI:SS');
*/

SELECT id,
       title,
       beneficiary_id, 
       number_of_volunteers, 
       priority_value, 
       start_date,
       end_date,
       register_by_date
FROM request;




-- A.2 For each request, find volunteers whose skill assignments match the requesting skills. 
--     List these volunteers from those with the most matching skills to those with the least (even 0 matching skills). 
--     Only consider volunteers who applied to the request and have a valid application. 

-- Select the request ID, volunteer ID, volunteer name, and count of matching skills
SELECT
    r.ID AS request_ID,  -- ID of the request
    v.ID AS volunteer_ID,  -- ID of the volunteer
    v.name AS volunteer_name,  -- Name of the volunteer
    COUNT(rs.skill_name) AS matching_skills_count  -- Count of matching skills between volunteer and request
FROM
    request r
-- Join with volunteer_application to get applications related to requests
JOIN
    volunteer_application va ON r.ID = va.request_id
-- Join with volunteer to get volunteer details
JOIN
    volunteer v ON va.volunteer_id = v.id
-- Left join with skill_assignment to include all skill assignments of volunteers
LEFT JOIN
    skill_assignment sa ON v.id = sa.volunteer_id
-- Left join with request_skill to match volunteer skills with request skills
-- Use LEFT JOIN to include all volunteers, even if they don't have matching skills
LEFT JOIN
    request_skill rs ON r.id = rs.request_id AND sa.skill_name = rs.skill_name
-- Only consider volunteers with valid applications (here is_valid = 1 because we have changed True --> 1, False --> 0 in data processing step)
WHERE
    va.is_valid = 1
-- Group by request ID, volunteer ID, and volunteer name to aggregate the count of matching skills
GROUP BY
    r.ID, v.ID, v.name
-- Order by request ID, number of matching skills in descending order, and volunteer ID
ORDER BY
    r.ID, matching_skills_count DESC, v.ID;



-- A.3 For each request, show the missing number of volunteers needed per skill (minimum needed of that skill). Assume a volunteer fulfills the need for all the skills they possess.
 
-- This CTE, named required_skills, extracts the required skills for each request.
   
 WITH required_skills AS (
    SELECT
        rs.request_id,
        rs.skill_name,
        rs.min_need
    FROM
        request_skill rs
), 
-- The valid_volunteers computes the number of  volunteers whose application is valid available for each skill in each request. It counts the distinct number of volunteers for each skill associated with each request 
valid_volunteers AS (
    SELECT
        a.request_id,
        sa.skill_name,
        COUNT(DISTINCT sa.volunteer_id) AS volunteer_count
    FROM
        volunteer_application a
    JOIN
        skill_assignment sa ON a.volunteer_id = sa.volunteer_id
    JOIN
        request_skill rs ON sa.skill_name = rs.skill_name AND a.request_id = rs.request_id
    WHERE
        a.is_valid = 1
    GROUP BY
        a.request_id,
        sa.skill_name
),
-- missing_volunteers calculates the shortage of volunteers for each skill in each request. It performs a LEFT JOIN between the 
-- required_skills and valid_volunteers to ensure all required skills are included, even if no volunteers are available for some skills. 
-- It computes the difference between the min_need and the number of available volunteers, handles cases where no volunteers are found, treating those as zero.
missing_volunteers AS (
    SELECT
        rs.request_id,
        rs.skill_name,
        rs.min_need - COALESCE(vv.volunteer_count, 0) AS missing_volunteers
    FROM
        required_skills rs
    LEFT JOIN
        valid_volunteers vv ON rs.request_id = vv.request_id AND rs.skill_name = vv.skill_name
)
-- The final query selects data from the request table and the missing_volunteers.
-- It joins these tables on the request_ID to include the request's title alongside the skill name and the number of missing volunteers.
-- The results are ordered by request_ID and skill_name to organize the output neatly by request and skill.
SELECT
    r.id AS request_id,
    r.title AS request_title,
    mv.skill_name,
    mv.missing_volunteers
FROM
    Request r
JOIN
    missing_volunteers mv ON r.id = mv.request_id
ORDER BY
    r.ID, mv.skill_name;
    

   
-- A.4 Sort requests and the beneficiaries who made them by the highest number of priority (request’s priority value) and the closest 'register by date'.

-- This clause specifies the columns to be retrieved from the request and beneficiary tables.
SELECT
    R.ID AS request_id,
    R.title,
    R.priority_value,
    R.register_by_date,
    B.ID AS beneficiary_id,
    B.name AS beneficiary_name,
    B.city_ID
-- This specifies the main table (request) from which data is being selected. It is aliased as R for easy reference. 
FROM
    request R
-- This performs an inner join between the request table (R) and the beneficiary table (B).
JOIN
    beneficiary B ON R.beneficiary_id = B.id
WHERE r.register_by_date >= CURRENT_TIMESTAMP 
--Orders the requests by their priority value in descending order, meaning requests with higher priority values appear first. 
-- Orders the requests with the same priority value by their registration deadline in ascending order, meaning those with earlier deadlines come first among requests with the same priority.   
ORDER BY
    R.priority_value DESC,
    R.register_by_date ASC;

   
   
-- A.5 For each volunteer, list requests that are within their volunteer range and 
-- match at least 2 of their skills (also include requests that don’t require any skills).

-- This clause selects specific columns to be included in the result set
SELECT
    v.id AS volunteer_id,
    v.name AS volunteer_Name,
    r.id AS request_id,
    COUNT(DISTINCT sa.skill_name) AS matching_skills_count
-- The FROM clause specifies the main table Volunteer (v alias) from which to start the query.
-- Several JOIN operations connect related tables. First Join: volunteer v and volunteer_range vr. Second Join: volunteer_range vr and request_location rl. 
-- Third Join: request_location rl and request r. Fourth Join: request r and request_skill rs. Fifth Join: volunteer v and skill_assignment sa
FROM
    volunteer v
JOIN
    volunteer_range  vr ON v.id = vr.volunteer_id
JOIN
    request_location rl ON vr.city_id = rl.city_id
JOIN
    request r ON rl.request_id = r.id
LEFT JOIN
    request_skill rs ON r.id = rs.request_id
LEFT JOIN
    skill_assignment sa ON v.id = sa.volunteer_id AND rs.skill_name = sa.skill_name
--Groups the results by the volunteer’s ID and name, and the request’s ID. 
-- This ensures that each row in the output represents a unique combination of a volunteer and a request, along with the count of matching skills.
GROUP BY
    v.id, v.name, r.id
-- Filters the grouped results to include only those combinations where:
-- The volunteer matches at least two distinct skills required by the request (COUNT(DISTINCT sa.skill_name) >= 2).
-- Or, the request has no specific skill requirements (COUNT(rs.skill_name) = 0).
HAVING
    COUNT(DISTINCT sa.skill_name) >= 2
    OR COUNT(rs.skill_name) = 0;


-- A.6 For each volunteer, list all the requests where the title matches their area of interest and are still available to register.
   
-- This clause specifies the columns to be included in the result set   
SELECT v.id AS volunteer_id,
       v.name AS volunteer_name,
       r.id AS request_id,
       r.title AS request_title,
       r.register_by_date 
-- FROM Clause: Specifies the base table volunteer (v alias) as the starting point for the query.
FROM volunteer v
JOIN interest_assignment ia ON v.id = ia.volunteer_id
JOIN request r ON LOWER(r.title) LIKE CONCAT('%', LOWER(ia.interest_name), '%')
LEFT JOIN volunteer_application a ON r.id = a.request_id AND a.volunteer_id = v.id
-- Ensures that only requests with a registration deadline on or after the current date are included.
WHERE r.register_by_date >= CURRENT_TIMESTAMP
-- Filters out requests for which the volunteer has already applied.
AND a.id IS null
-- Orders the results by volunteer ID in ascending order, meaning volunteers are sorted from lowest to highest ID.
-- Within each volunteer's entries, further orders the requests by the registration deadline in ascending order.
ORDER BY v.id ASC, r.register_by_date ASC; 
   
   
-- A.7 List the request ID and the volunteers who applied to them (name and email) but are not within the location range of the request. 
-- Order volunteers by readiness to travel.  

-- This clause specifies the columns to be included in the result set
SELECT 
    R.id AS request_id,
    V.id as volunteer_id,
    V.name AS volunteer_name,
    V.email AS volunteer_email,
    V.travel_readiness
FROM 
    volunteer_application A
JOIN 
    request R ON A.request_id = R.id
JOIN 
    volunteer V ON A.volunteer_id = V.id
JOIN 
    request_location RL ON R.id = RL.request_id
JOIN 
    volunteer_range VR ON V.id = VR.volunteer_id
WHERE 
    A.is_valid = 1 -- Consider only valid applications
    -- Ensures that the query only includes volunteers whose volunteer_range does not include the cities where the request is located.
    AND NOT EXISTS (
        SELECT 
            1 
        FROM 
            volunteer_range
        WHERE 
            volunteer_id = V.id 
            AND city_id IN (SELECT city_id FROM Request_location WHERE request_id = R.id)
    )
GROUP BY 
    R.id, V.id
ORDER BY 
    V.travel_readiness ASC;

   
-- A.8 Order the skills overall (from all requests) in the most prioritized to least prioritized (average the importance value).

SELECT skill_name,
       CAST(AVG(value) AS DECIMAL(10, 2)) AS avg_importance
FROM request_skill
GROUP BY skill_name
ORDER BY avg_importance DESC;
   
-- A.9
-- A.9.a Count the number of requests for each city

SELECT rl.city_id, city."name", COUNT(distinct request_id) as number_of_requests_received
FROM request_location rl
JOIN city on city.id = rl.city_id 
GROUP BY rl.city_id, city."name" 
ORDER BY number_of_requests_received DESC;

--A.9.b For for each city, list the requesting skills from those receiving the highest number of requests to those receiving the lowest number of requests. 
   
SELECT rl.city_id, c."name", rs.skill_name, COUNT(distinct rl.request_id) AS number_of_requests_received
FROM request_location rl 
JOIN request_skill rs ON rs.request_id = rl.request_id 
JOIN city c on rl.city_id = c.id 
GROUP BY rl.city_id, c."name", rs.skill_name
ORDER BY rl.city_id, number_of_requests_received DESC;

-- First, get all city-skill combinations using a cross join 
WITH city_skills AS (
    SELECT 
        c.id AS city_id, 
        c.name AS city_name, 
        s.name AS skill_name
    FROM 
        city c
    cross JOIN 
        skill s
),
-- Then, join the city-skill combinations with the requests:
requests_per_skill AS (
    SELECT 
        rl.city_id, 
        rs.skill_name, 
        COUNT(DISTINCT rl.request_id) AS number_of_requests_received
    FROM 
        request_location rl 
    JOIN 
        request_skill rs ON rs.request_id = rl.request_id 
    GROUP BY 
        rl.city_id, 
        rs.skill_name
)
-- Finally, left join the city-skills combinations with the requests_per_skill data (using this method is to make sure that the result will include all skills even if there are no requests for a particular skill in that city.)
SELECT 
    cs.city_id, 
    cs.city_name, 
    cs.skill_name, 
    COALESCE(rps.number_of_requests_received, 0) AS number_of_requests_received
FROM 
    city_skills cs
LEFT JOIN 
    requests_per_skill rps ON cs.city_id = rps.city_id AND cs.skill_name = rps.skill_name
ORDER BY 
    cs.city_id, 
    number_of_requests_received DESC; 
   
   
 -- A.10 List requests that need more volunteers before registration deadlines.
 
SELECT r.ID, 
       r.title, 
       r.number_of_volunteers, 
       COUNT(a.ID) AS current_num_volunteers
FROM Request r
-- Joins the request table with the volunteer_application table to link requests with their volunteer applications.
LEFT JOIN volunteer_application a 
       ON r.ID = a.request_ID AND a.is_valid = 1
-- Filters the requests to include only those where the registration deadline (register_by_date) is on or after the current date (CURRENT_DATE).
WHERE r.register_by_date >= CURRENT_TIMESTAMP
-- Groups the results by the unique identifier of the request (r.id), its title (r.title), and the number of volunteers needed (r.number_of_volunteers).
GROUP BY r.ID, r.title, r.number_of_volunteers
-- Filters the groups (requests) to include only those where the count of valid applications (COUNT(a.ID)) is less than the total number of volunteers needed 
HAVING COUNT(a.ID) < r.number_of_volunteers
-- Orders the results by the difference between the number of volunteers needed and the current number of valid applications, in descending order.
ORDER BY (r.number_of_volunteers - COUNT(a.ID)) DESC;
  

-- A.11 Calculate the average age of volunteers and number of volunteers in each city based on their address
   
WITH VolunteerAge AS (
    SELECT
        v.city_id,
        EXTRACT(YEAR FROM CURRENT_DATE) - EXTRACT(YEAR FROM v.birthdate) AS age -- Calculate age
    FROM
        Volunteer v),    
CityVolunteers AS (
    SELECT
        c.id AS city_id,
        c.name AS city_name,
        COUNT(va.age) AS volunteer_count, -- Count of volunteers in each city
        COALESCE(AVG(va.age), 0) AS avg_age -- Calculate average age, default to 0 if no volunteers
    FROM
        City c
    LEFT JOIN
        VolunteerAge va ON c.id = va.city_id -- Left join to include cities with no volunteers
    GROUP BY
        c.id, c.name -- Group by city ID and name
)
SELECT
    cv.city_id,
    cv.city_name,
    cv.volunteer_count,
    CAST(cv.avg_age AS DECIMAL(10, 2)) AS avg_age -- Cast average age to decimal with 2 decimal places
FROM
    CityVolunteers cv
ORDER BY
    cv.avg_age DESC, -- Order by average age in descending order
    cv.volunteer_count DESC; -- Order by volunteer count in descending order as a tie breaker
    

-- A.12 Determine the most active volunteers by counting the number of valid applications they have submitted for requests. 
-- Order the list from the most active volunteers to the least active. 

-- Select the volunteer ID, name, and count of valid applications for each volunteer 
SELECT 
v.id AS volunteer_id,  
v.name AS volunteer_name,  
COUNT(va.id) AS valid_applications_count -- Count of valid applications 
FROM 
volunteer_application va  
JOIN 
volunteer v ON va.volunteer_id = v.id -- Join with the volunteer table on volunteer ID 
WHERE 
va.is_valid = 1 -- Only consider valid applications 
GROUP BY 
v.id, v.name -- Group results by volunteer ID and name 
ORDER BY 
valid_applications_count DESC; -- Order by the count of valid applications in descending order 


-- B - ADVANCED

-- a.1) Create a view that lists next to each beneficiary the average number of volunteers that applied, the average age that applied, and the average
-- number of volunteers they need across all of their requests.
CREATE VIEW BeneficiaryStats AS
WITH DistinctVolunteerAges AS (
    SELECT 
        r.beneficiary_ID,
        v.id AS volunteer_id,
        CAST(AVG(EXTRACT(YEAR FROM CURRENT_DATE) - EXTRACT(YEAR FROM v.birthdate)) AS DECIMAL(10, 2)) AS volunteer_age
    FROM 
        Request r
    JOIN 
        volunteer_application a ON r.ID = a.request_ID
    JOIN 
        Volunteer v ON a.volunteer_ID = v.ID
    WHERE 
        a.is_valid = 1
    GROUP BY 
        r.beneficiary_ID, v.id, v.birthdate
),
AppliedStats AS (
    SELECT 
        r.beneficiary_ID,
        COUNT(DISTINCT a.volunteer_ID) AS applied_volunteers,
        CAST(AVG(dva.volunteer_age) AS DECIMAL(10,2)) AS applied_avg_age
    FROM 
        Request r
    JOIN 
        volunteer_application a ON r.ID = a.request_ID
    LEFT JOIN 
        DistinctVolunteerAges dva ON r.beneficiary_ID = dva.beneficiary_ID
    WHERE 
        a.is_valid = 1
    GROUP BY 
        r.beneficiary_ID
),
RequestCountPerBeneficiary AS (
    -- Count the total number of requests for each beneficiary
    SELECT 
        beneficiary_ID,
        COUNT(ID) AS total_requests
    FROM 
        Request
    GROUP BY 
        beneficiary_ID
),
AverageVolunteersPerRequest AS (
    -- Calculate the average number of volunteers applied per request for each beneficiary
    SELECT
        as1.beneficiary_ID,
        CAST(COUNT(DISTINCT as1.volunteer_id) AS DECIMAL(10, 2))/ 
        CAST(rcpb.total_requests AS DECIMAL(10, 2)) AS avg_applied_volunteers_per_request
    FROM
        (SELECT 
            r.beneficiary_ID, 
            a.volunteer_ID
        FROM 
            Request r
        JOIN 
            volunteer_application a ON r.ID = a.request_ID
        WHERE 
            a.is_valid = 1
        GROUP BY 
            r.beneficiary_ID, a.volunteer_ID) AS as1  -- subquery to count distinct volunteers per beneficiary
    JOIN 
        RequestCountPerBeneficiary rcpb ON as1.beneficiary_ID = rcpb.beneficiary_ID
    GROUP BY
        as1.beneficiary_ID, rcpb.total_requests
),
NeededStats AS (
    SELECT 
        beneficiary_ID,
        CAST(AVG(number_of_volunteers) AS DECIMAL(10,2)) AS avg_needed_volunteers
    FROM 
        Request
    GROUP BY 
        beneficiary_ID
)
SELECT 
    b.id AS beneficiary_id,
    b.name AS beneficiary_name,
    COALESCE(applied_stats.applied_volunteers, 0) AS num_applied_volunteers,
    COALESCE(applied_stats.applied_avg_age, 0) AS avg_applied_age,
    COALESCE(needed_stats.avg_needed_volunteers, 0) AS avg_needed_volunteers,
    COALESCE(avg_volunteers.avg_applied_volunteers_per_request, 0) AS avg_num_applied_volunteers_per_request
FROM 
    Beneficiary b
LEFT JOIN 
    DistinctVolunteerAges dva ON b.id = dva.beneficiary_ID
LEFT JOIN 
    AppliedStats applied_stats ON b.id = applied_stats.beneficiary_ID
LEFT JOIN 
    NeededStats needed_stats ON b.id = needed_stats.beneficiary_ID
LEFT JOIN 
    AverageVolunteersPerRequest avg_volunteers ON b.id = avg_volunteers.beneficiary_ID  -- Join the new CTE
GROUP BY 
    b.id, b.name, applied_stats.applied_volunteers, applied_stats.applied_avg_age, needed_stats.avg_needed_volunteers, avg_volunteers.avg_applied_volunteers_per_request
ORDER BY 
    b.id;
   
   
-- a.2) Create a view that For each request, find all nearest volunteers based on the distance between their volunteer_range and request_location (in km) of those volunteers applied to . 
--      Only consider distance larger than 0 . 

CREATE VIEW Distance AS
WITH VolunteerDistance AS (
    SELECT 
        v.ID AS volunteer_id,
        r.ID AS request_id,
        v.name AS volunteer_name,
        c_volunteer.name AS volunteer_city, 
        c_request.name AS request_city,
        CAST(
            6371 * acos(
                cos(radians(c_volunteer.latitude)) * cos(radians(c_request.latitude)) *
                cos(radians(c_request.longitude) - radians(c_volunteer.longitude)) +
                sin(radians(c_volunteer.latitude)) * sin(radians(c_request.latitude))
            ) AS INTEGER
        ) AS distance_km,
        DENSE_RANK() OVER (
            PARTITION BY r.ID 
            ORDER BY 
                6371 * acos(
                    cos(radians(c_volunteer.latitude)) * cos(radians(c_request.latitude)) *
                    cos(radians(c_request.longitude) - radians(c_volunteer.longitude)) +
                    sin(radians(c_volunteer.latitude)) * sin(radians(c_request.latitude))
                ) ASC
        ) AS nearest_volunteer_rank
    FROM 
        volunteer_range vr
    INNER JOIN 
        Volunteer v ON vr.volunteer_ID = v.ID
    INNER JOIN 
        City c_volunteer ON vr.city_ID = c_volunteer.ID
    INNER JOIN 
        volunteer_application a ON v.ID = a.volunteer_ID
    INNER JOIN 
        Request r ON a.request_ID = r.ID
    INNER JOIN 
        Request_location rl ON r.ID = rl.request_ID
    INNER JOIN 
        City c_request ON rl.city_ID = c_request.ID
    WHERE 
        a.is_valid = 1
        AND 6371 * acos(
                cos(radians(c_volunteer.latitude)) * cos(radians(c_request.latitude)) *
                cos(radians(c_request.longitude) - radians(c_volunteer.longitude)) +
                sin(radians(c_volunteer.latitude)) * sin(radians(c_request.latitude))
            ) > 0
)
SELECT 
    volunteer_id,
    volunteer_name,
    request_id,
    volunteer_city,
    request_city,
    distance_km
FROM 
    VolunteerDistance
--WHERE 
    --nearest_volunteer_rank = 1;

    
    

-- b.1) Create a check constraint for the volunteer table with a function that 
-- validates a volunteer ID when a new volunteer is inserted. The ID is valid if they satisfies:  
-- Length = 11 characters
-- The 7th character (separator) is one of the following: +, -, A, B, C, D, E, F, X, Y, W, V, U
-- The correct control character is used 

CREATE OR REPLACE FUNCTION calculate_control_character(volunteer_id text)
  RETURNS text
  LANGUAGE sql IMMUTABLE PARALLEL SAFE STRICT
AS $$
SELECT ('[0:30]={0,1,2,3,4,5,6,7,8,9,A,B,C,D,E,F,H,J,K,L,M,N,P,R,S,T,U,V,W,X,Y}'::text[])
       [(left($1, 6) || substring($1, 8, 3))::int % 31];
$$;


ALTER TABLE volunteer
ADD CONSTRAINT chk_validvolunteerid CHECK (
   length(id) = 11
   AND substring(id, 7, 1) = ANY ('{+,-,A,B,C,D,E,F,X,Y,W,V,U}')
   AND right(id, 1) = calculate_control_character(id)
);
 

-- b.2) Create a trigger that updates the number of volunteers for a request whenever the minimum need for any of its skill requirements is changed. 
-- The total number of volunteers needed for each request is calculated as the sum of unskilled volunteers (those without any skill requirements) and the minimum need for each required skill.

-- Create a function:
CREATE OR REPLACE FUNCTION update_number_of_volunteers()
RETURNS TRIGGER AS $$
DECLARE
    original_total_minimal_need INT;
    new_total_minimal_need INT;
    original_volunteers_needed INT;
BEGIN
    -- Calculate the original total minimal need for the request:
    SELECT old.min_need INTO original_total_minimal_need
    FROM request_skill
    WHERE request_id = OLD.request_id;

    -- Calculate the new total minimal need for the request:
    SELECT new.min_need INTO new_total_minimal_need
    FROM request_skill
    WHERE request_id = NEW.request_id;

    -- Get the current total number of volunteers needed for the request:
    SELECT number_of_volunteers INTO original_volunteers_needed
    FROM request
    WHERE id = OLD.request_id;

    -- Update the request with the new total number of volunteers needed
    -- Total unskilled volunteers needed = Old (Original) number of volunteers needed - Old (Original) total minimal need:
    UPDATE request
    SET number_of_volunteers = original_volunteers_needed - original_total_minimal_need + new_total_minimal_need
    WHERE id = NEW.request_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- Create a trigger:
CREATE TRIGGER update_number_of_volunteers_trigger
AFTER INSERT OR UPDATE OF min_need ON request_skill
FOR EACH ROW
EXECUTE FUNCTION update_number_of_volunteers();


-- Test the trigger:

/* Update the minimal_need for a 'Event Hosting' skill of Request 1 in the request_skill table. 
 * Currently, min_need of this skill = 3, number of volunteers needed for Request 1 is 14.
 * Now we will update min_need to 4 */
SELECT *
FROM request r 
WHERE id = 1;

SELECT * FROM request_skill rs 
WHERE request_id = 1;

UPDATE request_skill
SET min_need = 4
WHERE request_ID = 1 AND skill_name = 'Event Hosting';

-- Check if the trigger has updated the request table
SELECT * FROM request WHERE ID = 1;



-- c.1) Create a transaction that will read valid applications for a request.
   
-- Create 'Volunteer_assignment' table to track:
CREATE TABLE IF NOT EXISTS volunteer_assignment (
    request_id INT,
    volunteer_id VARCHAR(11),
    is_accepted BOOLEAN DEFAULT FALSE,
    PRIMARY KEY (request_id, volunteer_id)
);

-- Create a function to assign volunteers:

CREATE OR REPLACE FUNCTION assign_volunteer(req_id INT) RETURNS VOID AS $$
DECLARE
    total_volunteers INT;
    current_date DATE := CURRENT_DATE;
    register_date DATE;
    min_volunteer_required INT;
    volunteer RECORD;  -- Record variable to hold volunteer details
    req_skill RECORD;  -- Record variable to hold requesting skill details
BEGIN
    -- Step 1: Ensure the request_id exists in the request table
    IF NOT EXISTS (SELECT 1 FROM request WHERE id = req_id) THEN
        RAISE EXCEPTION 'Request ID % does not exist in the request table.', req_id;
    END IF;

    -- Get request registration date and minimum number of volunteers needed
    SELECT register_by_date, number_of_volunteers
    INTO register_date, min_volunteer_required
    FROM request
    WHERE id = req_id;

    -- Begin transaction block
    BEGIN
        -- Step 2: Assign volunteers with skills based on skill importance (skill value)
        -- Retrieve all requesting skills of 1 request and loop each skill based on its importance
        FOR req_skill IN (
            SELECT skill_name, min_need
            FROM request_skill
            WHERE request_id = req_id
            ORDER BY value DESC
        ) LOOP
        -- Step 3: Retrieve all volunteers applying for this request (valid application only) with their matching skills
            FOR volunteer IN (
                SELECT v.id
                FROM volunteer v
                JOIN volunteer_application va ON v.id = va.volunteer_id
                JOIN skill_assignment sa ON v.id = sa.volunteer_id
                WHERE va.request_id = req_id
                -- Condition 1: Valid application only (is_valid was converted to 0 (= invalid, FALSE) and 1 ( = valid, TRUE))
                AND va.is_valid = 1
                -- Condition 2: Their skills must match with the requesting skill 
                AND sa.skill_name = req_skill.skill_name  
                -- Condition 3: Check and make sure a volunteer is not already assigned to a specific request before assigning them again
                AND NOT EXISTS (
                    SELECT 1  -- if the volunteer is already assigned, this query will return 1 and 'NOT EXISTS' return False
                    FROM volunteer_assignment as va
                    WHERE va.request_id = req_id
                    AND volunteer_id = v.id
                )
                LIMIT req_skill.min_need -- ends when the minimum volunteers needed for that skill is met
            ) LOOP
                -- Insert the volunteer assignment into the 'volunteer_assignment' table
                INSERT INTO volunteer_assignment (request_id, volunteer_id, is_accepted)
                VALUES (req_id, volunteer.id, TRUE)
                -- If the assignment already exists, change is_accepted = True
                ON CONFLICT (request_id, volunteer_id) DO UPDATE SET is_accepted = TRUE;
            END LOOP;
        END LOOP;

        -- Step 4: Assign remaining applied volunteers (in general, not skill-based)
        -- Reason: Even after assigning volunteers with specific skills, a request might need additional volunteers to meet its overall volunteer requirements
        -- These remaining volunteers can help in tasks that don't require specific skills but still contribute to the overall effort
        FOR volunteer IN (
            SELECT v.id
            FROM volunteer v
            JOIN volunteer_application va ON v.id = va.volunteer_id
            WHERE va.request_id = req_id
            AND va.is_valid = 1
            AND NOT EXISTS (
                SELECT 1
                FROM volunteer_assignment 
                WHERE request_id = req_id
                AND volunteer_id = v.id
            )
        ) LOOP
            INSERT INTO volunteer_assignment (request_id, volunteer_id, is_accepted)
            VALUES (req_id, volunteer.id, TRUE)
            ON CONFLICT (request_id, volunteer_id) DO UPDATE SET is_accepted = TRUE;
        END LOOP;

        -- Step 5: Calculate the total number of assigned volunteers
        SELECT COUNT(*)
        INTO total_volunteers  -- store this info in the variable 'total_volunteers'
        FROM volunteer_assignment as va
        WHERE va.request_id = req_id
        AND is_accepted = TRUE;

        -- Step 6: Check conditions for committing or rolling back the transaction:
       
       		-- Scenario 1: The registration deadline is not past AND minimum volunteer requirement is not met
        IF current_date <= register_date AND total_volunteers < min_volunteer_required then
        -- Raise Exception to roll back the whole transaction:
        RAISE EXCEPTION 'Transaction rolled back: The minimum volunteer requirement is not met and the deadline is not past.';
    	END IF;

    		-- Scenario 2: The registration deadline is past AND minimum volunteer requirement is not met
    	IF current_date > register_date AND total_volunteers < min_volunteer_required THEN
        	/* Optionally extend the registration date or accept the volunteers.
        	 * Option 1:
        	 * UPDATE request
        	 * SET register_date = current_date + INTERVAL '7 days'
        	 * WHERE id = assign_volunteer.request_id;
        	 * Option 2: Here we accept volunteers as it is, hence we just raise Notice and commit */
        RAISE NOTICE 'Registration date is past and minimum volunteer requirement is not met, but proceeding.';
    	END IF;
    end;
END;
$$ LANGUAGE plpgsql;  

-- Test the function:

/* First, we tested with the request_id that does not exists in 'Request' table. 
 * Currently, we have only 382 requests.
 */

SELECT count(id) AS total_number_of_requests
FROM request r;

-- Now if we enter id = 383, the transaction should be rolled back with the error meessage:
DO $$ 
BEGIN 
    PERFORM assign_volunteer(383); 
END $$;
   
/* Scenario 1: The registration deadline is not past AND minimum volunteer requirement is not met.
 * We tested with Request 1 */

SELECT * FROM request r  WHERE r.id = 1;   
   
-- Number of applied volunteers (valid application only):
SELECT request_id, COUNT(volunteer_id) AS number_of_applied_volunteers
FROM volunteer_application 
WHERE request_id = 1 AND is_valid = 1
GROUP BY request_id; 

/* Request 1: Its 'register_by_date' (deadline) is not past, and only 7 volunteers applied ( < min_need = 14). 
 * Hence the transaction should be rolled back.
 */

DO $$ 
BEGIN 
    PERFORM assign_volunteer(1); 
END $$;

-- Re-check Volunteer_assignment table:
SELECT * FROM volunteer_assignment va;



/* Scenario 2 The registration deadline is past AND minimum volunteer requirement is not met.
 * We tested with Request ID 210. */

SELECT * FROM request r WHERE r.id = 210;

-- Number of applied volunteers (valid application only):
SELECT request_id, COUNT(volunteer_id) AS number_of_applied_volunteers
FROM volunteer_application 
WHERE request_id = 210 and is_valid = 1
GROUP BY request_id;


/* Deadline is past, and only 2 volunteers applied, which is lower than number of volunteers needed (28). 
However, the transaction should commit as we accept the number of volunteers as they are */
DO $$ 
BEGIN 
    PERFORM assign_volunteer(210); 
END $$;

-- Re-check Volunteer_assignment table:
SELECT * FROM volunteer_assignment va WHERE request_id = 210;



/* Scenario 3 the register_by_date is not past or the minimun number of volunteers is meet.
 * We tested with Request ID 63. */

SELECT * FROM request r WHERE r.id = 63;


-- Number of applied volunteers (valid application only):
SELECT request_id, COUNT(volunteer_id) AS number_of_applied_volunteers
FROM volunteer_application 
WHERE request_id = 63 and is_valid = 1
GROUP BY request_id;

/* Deadline is past (01.01.2023) but the minimum number of volunteers is meet (there are totally 6 volunteers applied while the minimum number of volunteers required is 4). 
 * Hence, the transaction should commit */
DO $$ 
BEGIN 
    PERFORM assign_volunteer(63); 
END $$;

-- Re-check Volunteer_assignment table:
SELECT *  FROM volunteer_assignment va WHERE request_id = 63;


--c.2) Transaction to notify applicants one week before deadline

-- Step 1: Create the 'notifications' table:
CREATE TABLE IF NOT EXISTS notifications (
    ID SERIAL PRIMARY KEY,
    volunteer_ID VARCHAR(11),
    volunteer_email text,
    request_ID INT,
    register_by_date DATE,
    message TEXT,
    noti_send_date DATE DEFAULT CURRENT_DATE
);


-- Step 2: Create the function to notify volunteers:
CREATE OR REPLACE FUNCTION notify_volunteers_before_registration() RETURNS VOID AS $$
DECLARE
    req RECORD; -- Record variable to hold applied request details
    app RECORD; -- Record variable to hold volunteer's application details
    notification_message TEXT;
BEGIN
    -- Loop through requests that have a register_by_date 7 days from now
    FOR req IN
        SELECT id, register_by_date
        FROM request
        WHERE DATE(register_by_date) = CURRENT_DATE + INTERVAL '7 days'
    LOOP
        -- Loop through valid applications for the current request
        FOR app IN
            SELECT volunteer_id, email
            FROM volunteer_application va
            JOIN volunteer v on v.id = va.volunteer_id --join 'Volunteer' table to acquire his/her email
            WHERE request_id = req.id AND is_valid = 1
        LOOP
            -- Create the notification message including the request ID and registration date
	        notification_message := 'Reminder: The registration deadline for request ID ' || req.id || ' is on ' || TO_CHAR(req.register_by_date, 'DD.MM.YY') || '.';

            -- Insert the notification into the notifications table
            INSERT INTO notifications (volunteer_id, volunteer_email, request_id, message, register_by_date)
            VALUES (app.volunteer_id, app.email, req.id, notification_message, req.register_by_date);
        END LOOP;
    END LOOP;
END;
$$ LANGUAGE plpgsql;


-- Test the function: Today is 02.06.2024 - so all volunteers applying for requests having 'register_by_date' = 09.06.2024 must be notified.

DO $$ 
BEGIN 
    PERFORM notify_volunteers_before_registration(); 
END $$;

-- Result:
SELECT * FROM notifications;



/* Additional trigger 1: create the trigger to ensure that volunteers can send up to 20 applications (only counting valid application or applications 
 */

-- Create a function:
CREATE OR REPLACE FUNCTION check_application_limit() RETURNS TRIGGER AS $$
DECLARE
    application_count INT;
BEGIN
    -- Count ONLY the number of valid applications by the volunteer and applications for requests that are not overdue/ register by date is not past (register_by_date >= current date):
    SELECT COUNT(*)
    INTO application_count
    FROM volunteer_application va
    JOIN request r ON va.request_id = r.id
    WHERE va.volunteer_id = NEW.volunteer_id
    AND va.is_valid = 1 AND r.register_by_date >= CURRENT_DATE;

    -- Raise an exception if the volunteer has already applied to 20 or more valid/future requests
    IF application_count >= 20 THEN
        RAISE EXCEPTION 'Volunteer % has already applied to 20 valid or open requests.', NEW.volunteer_id;
    END IF;

    -- Allow the insertion if the count is less than 20
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create a trigger:
CREATE TRIGGER application_limit_trigger
BEFORE INSERT ON volunteer_application
FOR EACH ROW
EXECUTE FUNCTION check_application_limit();

-- Test the trigger:
-- Show all volunteers with their open applications (valid application and with request that is not overdue). Note: CURRENT_DATE = 08.06.2024 (=the date this test was run)
SELECT va.volunteer_id, COUNT(*) as number_of_open_application
    FROM volunteer_application va
    JOIN request r ON va.request_id = r.id
    WHERE va.is_valid = 1 AND r.register_by_date >= CURRENT_TIMESTAMP
   	group by va.volunteer_id
  	order by number_of_open_application DESC;

-- Since the volunteer id '120198-990S' is having 10 open applications (the highest), we will insert 10 more test applications.
/* However, to avoid messing up the original dataset, first we add 10 more request (id = 383, 384, .. 392 as currently, the original dataset only has 382 requests.
 * Why we did so? Because we set the trigger that 1 volunteer cannot apply for the same request if currently he/she has a valid application (see Additional Trigger 2)
 * We set their register_by_date in the future, so that their deadline are not past (i.e. 2024-12-31) and all applications submitted to these request is considered as 'open'
 */
INSERT INTO request (id, beneficiary_id, title, number_of_volunteers, priority_value, start_date,
    end_date, register_by_date) VALUES
   (383, 1, 'test', 20, 1, '2025-01-01', '2025-01-04', '2024-12-31'),
   (384, 1, 'test2', 20, 1, '2025-01-01', '2025-01-04', '2024-12-31'),
   (385, 1, 'test3', 20, 1, '2025-01-01', '2025-01-04', '2024-12-31'),
   (386, 1, 'test4', 20, 1, '2025-01-01', '2025-01-04', '2024-12-31'),
   (387, 1, 'test5', 20, 1, '2025-01-01', '2025-01-04', '2024-12-31'),
   (388, 1, 'test6', 20, 1, '2025-01-01', '2025-01-04', '2024-12-31'),
   (389, 1, 'test7', 20, 1, '2025-01-01', '2025-01-04', '2024-12-31'),
   (390, 1, 'test8', 20, 1, '2025-01-01', '2025-01-04', '2024-12-31'),
   (391, 1, 'test9', 20, 1, '2025-01-01', '2025-01-04', '2024-12-31'),
   (392,1, 'test10', 20, 1, '2025-01-01', '2025-01-04', '2024-12-31')
  ;
 
 -- Re-check if these requests are added:
SELECT * FROM request 
ORDER BY id desc;

-- Now, the volunteer id '120198-990S' apply for these 9 newly-created request:
INSERT INTO volunteer_application (request_id, volunteer_id, modified, is_valid) VALUES 
(383, '120198-990S', '2024-06-03', 1),
(384, '120198-990S', '2024-06-03', 1),
(385, '120198-990S', '2024-06-03', 1),
(386, '120198-990S', '2024-06-03', 1),
(387, '120198-990S', '2024-06-03', 1),
(388, '120198-990S', '2024-06-03', 1),
(389, '120198-990S', '2024-06-03', 1),
(390, '120198-990S', '2024-06-03', 1),
(391, '120198-990S', '2024-06-03', 1),
(392, '120198-990S', '2024-06-03', 1)
;

-- Re-check if all aplications are added:
SELECT * FROM volunteer_application
ORDER BY id desc;

-- Re-check if volunteer ID '120198-990S' has now 20 'pending' application:
SELECT va.volunteer_id, COUNT(*) as number_of_open_application
    FROM volunteer_application va
    JOIN request r ON va.request_id = r.id
    WHERE va.is_valid = 1 AND r.register_by_date >= CURRENT_TIMESTAMP and va.volunteer_id = '120198-990S'
   	group by va.volunteer_id;
 
   
-- Now, if this volunteer add 1 more application for any requests (ex: request ID = 1), the trigger should be activated:
INSERT INTO volunteer_application (request_id, volunteer_id, modified, is_valid) VALUES 
(1, '120198-990S', '2024-06-03', 1);  
   
   
-- Note: here we did not consider the scenario, where the volunteer set the application as 'invalid' (in_valid = False), because in that sense, the application will not be counted. 



/* Additional trigger 2: To ensure that a volunteer cannot apply to the same request if they currently have one valid application to the same request, we can create a trigger that checks this condition before inserting a new application record. 
 * If the condition is not met, the trigger will raise an exception.
 */

-- Create a function:
CREATE OR REPLACE FUNCTION check_duplicate_application() RETURNS TRIGGER AS $$
BEGIN
    -- Check if there is any valid application for the same request by the same volunteer
    IF EXISTS (
        SELECT 1
        FROM volunteer_application
        WHERE request_id = NEW.request_id
          AND volunteer_id = NEW.volunteer_id
          AND is_valid = 1
    ) THEN
        RAISE EXCEPTION 'A valid application for this request already exists by the same volunteer.';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

   
-- Create a trigger:
CREATE TRIGGER before_application_insert
BEFORE INSERT ON volunteer_application
FOR EACH ROW
EXECUTE FUNCTION check_duplicate_application();  
   

-- Test the trigger:
/* To avoid messing up the original dataset, we use the new request (id = 383 as created before).
 * Now for this request, volunteer with ID = '120198-990S' now submit 2 valid applications.
 * The trigger should be activated.
 */

-- First application (is_valid = 1 indicates the application is valid):
INSERT INTO volunteer_application (request_id, volunteer_id, modified, is_valid)
VALUES (383, '120198-990S', '2024-06-03', 1);


-- Second application:
INSERT INTO volunteer_application (request_id, volunteer_id)
VALUES (383, '120198-990S');

-- Once done with both testing, we delete these test tuples, return to the original dataset:

DELETE FROM volunteer_application
WHERE request_id > 382;

DELETE FROM request 
WHERE id > 382;

SELECT setval('volunteer_application_id_seq', (SELECT MAX(id) FROM volunteer_application));
SELECT setval('request_id_seq', (SELECT MAX(id) FROM request));
   
 
   