//////////////////////////////////////////////////////////////////////////////////////////////////////////////
//SETUP OF TEST ENVIRONMENT
create database testsharedatabase;
create schema testshareschema;
create table testsharetable (v variant);
create table testsharetable2 (v variant);

use role securityadmin;
create role testappteamrole;
grant role testappteamrole to role sysadmin;

use role sysadmin;
create warehouse testappteamwarehouse;
grant usage on warehouse testappteamwarehouse to role testappteamrole;
grant role testappteamrole to user ABALDINO;

//////////////////////////////////////////////////////////////////////////////////////////////////////////////
//CREATION OF STORED PROCEDURES -> CREATE SHARE, ADD DATA TO SHARE, REMOVE DATA FROM SHARE

use role accountadmin;

//ALLOWS CREATION OF DATA SHARE BY NON-ACCOUNTADMIN, SHARE ENDS UP OWNED BY ACCOUNTADMIN FOR LISTING PURPOSES
CREATE OR REPLACE PROCEDURE APPTEAM_CREATE_SHARE(new_sharename VARCHAR)
  RETURNS TABLE()
  LANGUAGE SQL
  EXECUTE AS OWNER
  AS  
    DECLARE
      select_statement VARCHAR;
      res RESULTSET;
    BEGIN
      select_statement := 'create share ' || new_sharename;
      res := (EXECUTE IMMEDIATE :select_statement);
      RETURN table(res);
    END;

//ALLOWS ADDITION OF TABLES/VIEWS TO DATA SHARE BY NON-ACCOUNTADMIN, SHARE ENDS UP OWNED BY ACCOUNTADMIN FOR LISTING PURPOSES
CREATE OR REPLACE PROCEDURE APPTEAM_ADD_TO_SHARE(sharename VARCHAR, share_database VARCHAR, share_schema VARCHAR, share_object_type VARCHAR, share_object VARCHAR)
  RETURNS TABLE()
  LANGUAGE SQL
  EXECUTE AS OWNER
  AS  
    DECLARE
      select_statement1 VARCHAR;
      select_statement2 VARCHAR;
      select_statement3 VARCHAR;
      res RESULTSET;
    BEGIN
      select_statement1 := 'grant usage on database ' || share_database || ' to share ' || sharename;
      res:= (EXECUTE IMMEDIATE :select_statement1);
      select_statement2 := 'grant usage on schema ' || share_database || '.' || share_schema || ' to share ' || sharename;
      res:= (EXECUTE IMMEDIATE :select_statement2);
      select_statement3 := 'grant select on ' || share_object_type || ' ' || share_database || '.' || share_schema || '.' || share_object || ' to share ' || sharename;
      res:= (EXECUTE IMMEDIATE :select_statement3);
      RETURN TABLE(res);
    END;

//ALLOWS REMOVAL OF TABLES/VIEWS FROM DATA SHARE BY NON-ACCOUNTADMIN, SHARE ENDS UP OWNED BY ACCOUNTADMIN FOR LISTING PURPOSES
CREATE OR REPLACE PROCEDURE APPTEAM_REMOVE_FROM_SHARE(sharename VARCHAR, share_database VARCHAR, share_schema VARCHAR, share_object_type VARCHAR, share_object VARCHAR)
  RETURNS TABLE()
  LANGUAGE SQL
  EXECUTE AS OWNER
  AS  
    DECLARE
      select_statement1 VARCHAR;
      select_statement2 VARCHAR;
      select_statement3 VARCHAR;
      res RESULTSET;
    BEGIN
      select_statement1 := 'revoke usage on database ' || share_database || ' from share ' || sharename;
      res:= (EXECUTE IMMEDIATE :select_statement1);
      select_statement2 := 'revoke usage on schema ' || share_database || '.' || share_schema || ' from share ' || sharename;
      res:= (EXECUTE IMMEDIATE :select_statement2);
      select_statement3 := 'revoke select on ' || share_object_type || ' ' || share_database || '.' || share_schema || '.' || share_object || ' from share ' || sharename;
      res:= (EXECUTE IMMEDIATE :select_statement3);
      RETURN TABLE(res);
    END;

//////////////////////////////////////////////////////////////////////////////////////////////////////////////
//REQUIRED GRANTS TO ACCESS THE STORED PROCEDURE AS CREATED BY ACCOUNTADMIN
grant usage on database testsharedatabase to role testappteamrole;
grant usage on schema testsharedatabase.testshareschema to role testappteamrole;
GRANT USAGE ON PROCEDURE APPTEAM_CREATE_SHARE(VARCHAR) to ROLE testappteamrole;
GRANT USAGE ON PROCEDURE APPTEAM_ADD_TO_SHARE(VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR) to ROLE testappteamrole;
GRANT USAGE ON PROCEDURE APPTEAM_REMOVE_FROM_SHARE(VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR) to ROLE testappteamrole;

//////////////////////////////////////////////////////////////////////////////////////////////////////////////
//TESTING OF STORED PROCEDURE
use role testappteamrole;

CALL APPTEAM_CREATE_SHARE('newdatashare');

CALL APPTEAM_ADD_TO_SHARE('newdatashare','testsharedatabase','testshareschema','table','testsharetable');
CALL APPTEAM_ADD_TO_SHARE('newdatashare','testsharedatabase','testshareschema','table','testsharetable2');

CALL APPTEAM_REMOVE_FROM_SHARE('newdatashare','testsharedatabase','testshareschema','table','testsharetable');

//////////////////////////////////////////////////////////////////////////////////////////////////////////////
//VIEW RESULTS
use role accountadmin;
show shares;

show grants to share newdatashare;