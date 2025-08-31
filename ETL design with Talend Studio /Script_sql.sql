CREATE TABLE TIME
        (	DATE_ID INTEGER,
    DAY INTEGER NOT NULL,
	MONTH INTEGER NOT NULL,
	YEAR INTEGER NOT NULL,
	PRIMARY KEY (DATE_ID));


CREATE TABLE AIRCRAFT
        (	AIRCRAFT_ID INTEGER,
	MODEL VARCHAR(30),
	MANUFACTURER VARCHAR(30),
	PRIMARY KEY (AIRCRAFT_ID));


CREATE TABLE MAINTENANCE
        (	MAINANTANCE_CODE INTEGER,
	AIRCRAFT_ID INTEGER,
	TOTAL_DURATION INTEGER,
	SCHEDULED NUMBER(1), -- boolean
	DATE_ID INTEGER,
	PRIMARY KEY (MAINANTANCE_CODE),
	FOREIGN KEY (AIRCRAFT_ID) REFERENCES AIRCRAFT (AIRCRAFT_ID),
	FOREIGN KEY (DATE_ID) REFERENCES TIME (DATE_ID)
	);


CREATE TABLE REPORTERS
        (	REPORTER_ID INTEGER,
      REPORTER_TYPE CHAR(30),
	AIRPORT CHAR(30),
	PRIMARY KEY (REPORTER_ID));


-- ---------------- --
-- FACT TABLES
-- ---------------- --


CREATE TABLE FLIGHTS
        (	FLIGHT_ID INTEGER,
	AIRCRAFT_ID INTEGER,
	TOTAL_DURATION INTEGER,
	DELAYED NUMBER(1),
	TIME_DELAYED INTEGER,
	CANCELLED  NUMBER(1),
	DATE_ID INTEGER,
	PRIMARY KEY (FLIGHT_ID),
	FOREIGN KEY (AIRCRAFT_ID) REFERENCES AIRCRAFT (AIRCRAFT_ID),
	FOREIGN KEY (DATE_ID) REFERENCES TIME (DATE_ID)
	);


CREATE TABLE LOGBOOK
        (	LOGBOOK_ID INTEGER,
	REPORTER_ID INTEGER,
	AIRCRAFT_ID INTEGER,
	DATE_ID INTEGER,
	PRIMARY KEY (LOGBOOK_ID),
	FOREIGN KEY (AIRCRAFT_ID) REFERENCES AIRCRAFT (AIRCRAFT_ID),
	FOREIGN KEY (DATE_ID) REFERENCES TIME (DATE_ID),
	FOREIGN KEY (REPORTER_ID) references REPORTERS (REPORTER_ID)
	);


-- ---------------- --
-- MATERIALIZED VIEWS
-- ---------------- --
-- DROP MATERIALIZED VIEW IF EXISTS "AircraftUtilization";
CREATE MATERIALIZED VIEW Aircraftmv
BUILD IMMEDIATE 
ENABLE QUERY REWRITE AS
        (	SELECT  a.aircraft_ID,
                    a.model,
                    a.manufacturer,
                    t.DAY,
                    t.month,
                    t.year,
                    count(f.flight_id) AS take_offs,
                    sum(f.total_duration) AS totalflight_hours,
                    sum (case when f.cancelled = 1 then 1 else 0 end) as total_cancelled_flights,
                    sum (case when f.delayed = 1 then 1 else 0 end) as Total_delayed_flights,
                    sum(f.time_delayed) as Total_time_delayed,
                    sum(case when m.scheduled = 1 then m.total_duration else 0 end) AS HoursOutService_Scheduled,
                    sum(case when m.scheduled = 0 then m.total_duration else 0 end) AS HoursOutService_Unscheduled
FROM Flights f, Aircraft a, Time t, Maintenance m
WHERE a.aircraft_ID = f.aircraft_ID AND t.date_ID = f.date_ID AND a.aircraft_ID= m.aircraft_ID
GROUP BY a.aircraft_ID, a.model, a.manufacturer, t.DAY, t.month, t.year
);
	


-- ---------------- --
-- QUERIES
-- ---------------- --


--a) Give me FH and TO per aircraft (also per model) per day (also per month and per year). 


SELECT aircraft_ID,
       model,
       day,
       month,
       year,
       totalflight_hours AS FH,
       take_offs AS TO
FROM AIRCRAFTMV 
GROUP BY aircraft_ID, model, day, month, year
ORDER BY aircraft_ID, model,day, month, year;


-- b) b) Give me ADIS, ADOS, ADOSS, ADOSU, DYR, CNR, TDR, ADD per aircraft (also per model) per month (also per year).
SELECT AIRCRAFT_ID,
	HOURSOUTSERVICE_SCHEDULED+HOURSOUTSERVICE_UNSCHEDULED AS ADOS,
	30 - HOURSOUTSERVICE_SCHEDULED+HOURSOUTSERVICE_UNSCHEDULED AS ADIS,
	HOURSOUTSERVICE_SCHEDULED AS ADOSS,
	HOURSOUTSERVICE_UNSCHEDULED AS ADOSU, 
	TOTAL_TIME_DELAYED/TAKE_OFFS AS DYR, 
	TOTAL_DELAYED_FLIGHTS / 30 AS ADD,
	TOTAL_CANCELLED_FLIGHTS / TAKE_OFFS AS CNR, 
	100 - (TOTAL_TIME_DELAYED + TOTAL_CANCELLED_FLIGHTS)/TAKE_OFFS AS TDR
FROM AIRCRAFTMV 
WHERE MONTH = 'MARCH' AND model='11111'
GROUP BY AIRCRAFT_ID; 


-- c) Give me the RRh, RRc, PRRh, PRRc, MRRh and MRRc per aircraft (also per model and manufacturer) per month (also per year).

SELECT a.AIRCRAFT_ID , 
	count(l.LOGBOOK_ID)/a.TOTALFLIGHT_HOURS AS RRh, 
	count(l.LOGBOOK_ID)/a.TAKE_OFFS AS RRc
FROM AIRCRAFTMV a, LOGBOOK l
WHERE a.AIRCRAFT_ID = l.AIRCRAFT_ID 
GROUP BY a.AIRCRAFT_ID, a.TOTALFLIGHT_HOURS, a.TAKE_OFFS;

SELECT a.AIRCRAFT_ID , 
	count(l.LOGBOOK_ID)/a.TOTALFLIGHT_HOURS AS MRRh, 
	count(l.LOGBOOK_ID)/a.TAKE_OFFS AS MRRc
FROM AIRCRAFTMV a, LOGBOOK l, REPORTERS r , TIME t 
WHERE a.AIRCRAFT_ID = l.AIRCRAFT_ID
	AND l.REPORTER_ID = r.REPORTER_ID 
	AND r.REPORTER_TYPE = 'MAINTENANCE'
	AND t.MONTH = 'MARCH'
GROUP BY a.AIRCRAFT_ID , a.TOTALFLIGHT_HOURS, a.TAKE_OFFS;
	
-- d) Give me the MRRh and MRRc per airport of the reporting person per aircraft (also per model).


SELECT a.AIRCRAFT_ID , 
	count(l.LOGBOOK_ID)/a.TOTALFLIGHT_HOURS AS MRRh, 
	count(l.LOGBOOK_ID)/a.TAKE_OFFS AS MRRc
FROM AIRCRAFTMV a, LOGBOOK l, REPORTERS r 
WHERE a.AIRCRAFT_ID = l.AIRCRAFT_ID
	AND l.REPORTER_ID = r.REPORTER_ID 
	AND r.AIRPORT = 'bcn'
GROUP BY a.AIRCRAFT_ID , a.TOTALFLIGHT_HOURS, a.TAKE_OFFS;








