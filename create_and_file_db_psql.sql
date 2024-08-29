DROP TABLE IF EXISTS volunteer_application;
DROP TABLE IF EXISTS request_location;
DROP TABLE IF EXISTS request_skill;
DROP TABLE IF EXISTS request;
DROP TABLE IF EXISTS beneficiary;
DROP TABLE IF EXISTS interest_assignment;
DROP TABLE IF EXISTS interest;
DROP TABLE IF EXISTS skill_assignment;
DROP TABLE IF EXISTS skill;
DROP TABLE IF EXISTS volunteer_range;
DROP TABLE IF EXISTS volunteer;
DROP TABLE IF EXISTS city;

CREATE TABLE city (
    id INT PRIMARY KEY CHECK (id > 0),
    name VARCHAR(100) NOT NULL,
    latitude FLOAT,
    longitude FLOAT
);

CREATE TABLE volunteer (
    id VARCHAR(11) PRIMARY KEY,
    birthdate DATE NOT NULL,
    city_id INT,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL,
    address VARCHAR(200) NOT NULL,
    travel_readiness INT NOT NULL,
    FOREIGN KEY (city_id) REFERENCES city(id)
);

CREATE TABLE volunteer_range (
    volunteer_id VARCHAR(11),
    city_id INT,
    PRIMARY KEY (volunteer_id, city_id),
    FOREIGN KEY (volunteer_id) REFERENCES volunteer(id),
    FOREIGN KEY (city_id) REFERENCES city(id)
);

CREATE TABLE skill (
    name VARCHAR(100) PRIMARY KEY,
    description TEXT NOT NULL
);

CREATE TABLE skill_assignment (
    volunteer_id VARCHAR(11),
    skill_name VARCHAR(100),
    PRIMARY KEY (volunteer_id, skill_name),
    FOREIGN KEY (volunteer_id) REFERENCES volunteer(id),
    FOREIGN KEY (skill_name) REFERENCES skill(name)
);

CREATE TABLE interest (
    name VARCHAR(100) PRIMARY KEY
);

CREATE TABLE interest_assignment (
    volunteer_id VARCHAR(11),
    interest_name VARCHAR(100),
    PRIMARY KEY (volunteer_id, interest_name),
    FOREIGN KEY (volunteer_id) REFERENCES volunteer(id),
    FOREIGN KEY (interest_name) REFERENCES interest(name)
);

CREATE TABLE beneficiary (
    id INT PRIMARY KEY CHECK (id > 0),
    name VARCHAR(100) NOT NULL,
    address VARCHAR(200) NOT NULL,
    city_id INT,
    FOREIGN KEY (city_id) REFERENCES city(id)
);

CREATE TABLE request (
    id SERIAL PRIMARY KEY,
    beneficiary_id INT,
    title VARCHAR(200),
    number_of_volunteers INT CHECK (number_of_volunteers >= 1),
    priority_value INT CHECK (priority_value >= 0 AND priority_value <= 5) NOT NULL,
    start_date TIMESTAMP NOT NULL,
    end_date TIMESTAMP NOT NULL,
    register_by_date TIMESTAMP NOT NULL,
    FOREIGN KEY (beneficiary_id) REFERENCES beneficiary(id)
);

CREATE TABLE request_skill (
    request_id INT,
    skill_name VARCHAR(100),
    min_need INT CHECK (min_need >= 1) NOT NULL,
    value INT CHECK (value >= 0 AND value <= 5) NOT NULL,
    PRIMARY KEY (request_id, skill_name),
    FOREIGN KEY (request_id) REFERENCES request(id),
    FOREIGN KEY (skill_name) REFERENCES skill(name)
);

CREATE TABLE request_location (
    request_id INT,
    city_id INT,
    PRIMARY KEY (request_id, city_id),
    FOREIGN KEY (request_id) REFERENCES request(id),
    FOREIGN KEY (city_id) REFERENCES city(id)
);

CREATE TABLE volunteer_application (
    id SERIAL PRIMARY KEY,
    request_id INT,
    volunteer_id VARCHAR(11),
    modified TIMESTAMP,
    is_valid INT NOT NULL CHECK (is_valid = 1 OR is_valid = 0),
    FOREIGN KEY (request_id) REFERENCES request(id),
    FOREIGN KEY (volunteer_id) REFERENCES volunteer(id)
);
