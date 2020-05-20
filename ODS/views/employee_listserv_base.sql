REM Radford University
REM
REM EMPLOYEE_LISTSERV_BASE.sql
REM Base view for all active employees on the current day.
REM 
REM 1. MW 2019/07/08
REM    Initial
REM
REM 2. MW 2019/08/15
REM    Change current term logic to 28 days prior to start date
REM    Remove student workers and adjuncts not currently teaching
REM
REM 3. MW 2019/09/12
REM    Add supervisor uid which pulls from reports to field in NBBPOSN.
REM
REM 4. MW 2020/01/21
REM    Add all adjuncts with an active contract.
REM
REM 5. MW 2020/05/20
REM AUDIT TRAIL END
REM
PROMPT * BEGIN SCRIPT...
SET DEFINE OFF;
CREATE OR REPLACE VIEW RADFORD.EMPLOYEE_LISTSERV_BASE AS
WITH t_teaching AS
 (SELECT DISTINCT person_uid,
                  CASE
                    WHEN SYSDATE BETWEEN stvterm_start_date - 28 AND
                         stvterm_end_date THEN
                     'CURRENT'
                    ELSE
                     CASE
                       WHEN substr(stvterm_code, 5, 1) = '3' THEN
                        'UPCOMING SUMMER'
                       ELSE
                        DECODE(substr(stvterm_code, 5, 2), 10, 'UPCOMING FALL',
                               20, 'UPCOMING SPRING', 15, 'UPCOMING WINTER', '05',
                               'UPCOMING AUGUST')
                     END
                  END AS term_group
    FROM instructional_assignment i
    JOIN stvterm s
      ON i.academic_period = s.stvterm_code AND
         s.stvterm_end_date > SYSDATE AND
         s.stvterm_code NOT LIKE '00%'),
t_supervisor AS
 (SELECT nbrjobs_posn AS super_posn,
         nbrjobs_pidm AS super_pidm,
         row_number() over(PARTITION BY nbrjobs_posn ORDER BY nbrjobs_effective_date DESC) AS seq
    FROM nbrjobs a
   WHERE nbrjobs_status = 'A')
SELECT DISTINCT e.PERSON_UID,
                b.last_name,
                b.first_name,
                i.internet_address EMAIL,
                e.EMPLOYEE_CLASS,
                CASE
                  WHEN e.employee_class IN ('AT', 'AV', 'A1', 'A2') THEN
                   'AP_FACULTY'
                  WHEN e.employee_class IN
                       ('ET', 'EV', 'NT', 'NV', 'PT', 'PV') THEN
                   'CLASSIFIED_STAFF'
                  WHEN (e.employee_class IN ('1T', '1V', '9T', '9V') OR
                       ((e.position_title LIKE '%Dean%' AND
                       e.position_title NOT LIKE '%Assoc%') AND
                       (e.position_title LIKE '%Dean%' AND
                       e.position_title NOT LIKE 'Exec%'))) THEN
                   'TR_FACULTY'
                  WHEN e.EMPLOYEE_CLASS = '9Z' THEN
                   'ADJUNCT_FACULTY'
                  WHEN e.EMPLOYEE_CLASS LIKE 'W%' THEN
                   'WAGE'
                  WHEN e.EMPLOYEE_CLASS LIKE 'S%' THEN
                   'STUDENT'
                  WHEN e.EMPLOYEE_CLASS LIKE 'R%' THEN
                   'RETIREE'
                END AS CLASS_GROUP,
                NVL(e.CAMPUS, 'MC') AS CAMPUS,
                NVL(t.term_group, 'N/A') AS TEACHING_TERM,
                v.super_pidm AS SUPERVISOR_UID
  FROM employee e
  JOIN employee_position ep
    ON e.PERSON_UID = ep.PERSON_UID AND
       ep.POSITION_STATUS = 'A' AND
       ep.effective_date <= SYSDATE AND
       ep.position_begin_date <= SYSDATE AND
       (ep.position_end_date > SYSDATE OR ep.position_end_date IS NULL)
  LEFT JOIN goradid g
    ON e.PERSON_UID = g.goradid_pidm AND
       g.goradid_adid_code = 'STAT'
  JOIN person_detail b
    ON e.PERSON_UID = b.person_uid
  JOIN internet_address i
    ON e.PERSON_UID = i.ENTITY_UID AND
       i.INTERNET_ADDRESS_STATUS = 'A' AND
       i.INTERNET_ADDRESS_TYPE = 'RU'
  LEFT JOIN t_teaching t
    ON e.PERSON_UID = t.person_uid
  LEFT JOIN (SELECT * FROM TWGRROLE WHERE TWGRROLE_ROLE = 'RU_IDMBRB') r
    ON e.person_uid = r.TWGRROLE_PIDM
  LEFT JOIN nbbposn p
    ON e.position = p.nbbposn_posn
  LEFT JOIN t_supervisor v
    ON p.nbbposn_posn_reports = v.super_posn AND
       v.seq = 1
 WHERE e.employee_status = 'A' AND
       e.current_hire_date <= SYSDATE AND
       (e.full_or_part_time_ind IN ('F', 'P') OR e.EMPLOYEE_CLASS = 'R1') AND
       r.TWGRROLE_ROLE IS NULL AND
       e.EMPLOYEE_CLASS NOT IN ('S1', 'S2', 'S3', '9Z') --AND
       --NOT (t.term_group <> 'CURRENT' AND e.EMPLOYEE_CLASS = '9Z')
UNION
SELECT DISTINCT e.PERSON_UID,
                b.last_name,
                b.first_name,
                i.internet_address EMAIL,
                e.EMPLOYEE_CLASS,
                CASE
                  WHEN e.employee_class IN ('AT', 'AV', 'A1', 'A2') THEN
                   'AP_FACULTY'
                  WHEN e.employee_class IN ('ET', 'EV', 'NT', 'NV', 'PT', 'PV') THEN
                   'CLASSIFIED_STAFF'
                  WHEN (e.employee_class IN ('1T', '1V', '9T', '9V') OR
                       ((e.position_title LIKE '%Dean%' AND
                       e.position_title NOT LIKE '%Assoc%') AND
                       (e.position_title LIKE '%Dean%' AND
                       e.position_title NOT LIKE 'Exec%'))) THEN
                   'TR_FACULTY'
                  WHEN e.EMPLOYEE_CLASS = '9Z' THEN
                   'ADJUNCT_FACULTY'
                  WHEN e.EMPLOYEE_CLASS LIKE 'W%' THEN
                   'WAGE'
                  WHEN e.EMPLOYEE_CLASS LIKE 'S%' THEN
                   'STUDENT'
                  WHEN e.EMPLOYEE_CLASS LIKE 'R%' THEN
                   'RETIREE'
                END AS CLASS_GROUP,
                NVL(e.CAMPUS, 'MC') AS CAMPUS,
                NVL(t.term_group, 'N/A') AS TEACHING_TERM,
                v.super_pidm AS SUPERVISOR_UID
  FROM employee e
  LEFT JOIN goradid g
    ON e.PERSON_UID = g.goradid_pidm AND
 g.goradid_adid_code = 'STAT'
  JOIN person_detail b
    ON e.PERSON_UID = b.person_uid
  JOIN internet_address i
    ON e.PERSON_UID = i.ENTITY_UID AND
 i.INTERNET_ADDRESS_STATUS = 'A' AND
 i.INTERNET_ADDRESS_TYPE = 'RU'
  LEFT JOIN t_teaching t
    ON e.PERSON_UID = t.person_uid
  LEFT JOIN (SELECT * FROM TWGRROLE WHERE TWGRROLE_ROLE = 'RU_IDMBRB') r
    ON e.person_uid = r.TWGRROLE_PIDM
  LEFT JOIN nbbposn p
    ON e.position = p.nbbposn_posn
  LEFT JOIN t_supervisor v
    ON p.nbbposn_posn_reports = v.super_posn AND
 v.seq = 1
 WHERE e.employee_status = 'A' AND
 e.current_hire_date <= SYSDATE AND
 r.TWGRROLE_ROLE IS NULL AND
 e.EMPLOYEE_CLASS = '9Z';
SHOW ERRORS VIEW EMPLOYEE_LISTSERV_BASE
CREATE OR REPLACE PUBLIC SYNONYM EMPLOYEE_LISTSERV_BASE FOR RADFORD.EMPLOYEE_LISTSERV_BASE;
GRANT SELECT ON EMPLOYEE_LISTSERV_BASE to RU_ACCTMGMT;
PROMPT * SCRIPT END EMPLOYEE_LISTSERV_BASE