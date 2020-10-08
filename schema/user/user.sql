DROP TABLE IF EXISTS user;
DROP TABLE IF EXISTS user_role_type;
DROP TABLE IF EXISTS user_role_xref;
DROP TABLE IF EXISTS user_collar_access;

-- enable uuid_generate functions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- note - may need to change this table name. user is technically a reserved word in psql
-- so referencing this table will require prepending schema name or referencing it in double quotes
-- idirs should be unique to the table?
CREATE TABLE bctw.user
(
  user_id     uuid PRIMARY key DEFAULT uuid_generate_v1(),
  idir        VARCHAR(50) UNIQUE,
  bceid       VARCHAR(50),
  email       VARCHAR(50),
  expire_date TIMESTAMP,
  deleted     BOOLEAN DEFAULT false,
  deleted_at  TIMESTAMP
);

CREATE TABLE bctw.user_role_type
(
  role_id     uuid PRIMARY key DEFAULT uuid_generate_v1(),
  role_type   VARCHAR(50),
  description VARCHAR(200)
);
COMMENT ON TABLE bctw.user_role_type is 'User Role Type is a code table for role types. Current role types are Administrator, Owner, Observer';

CREATE TABLE bctw.user_role_xref 
(
  user_id uuid REFERENCES bctw.user(user_id),
  role_id uuid REFERENCES bctw.user_role_type(role_id),
  PRIMARY KEY (user_id, role_id)
);
COMMENT ON TABLE bctw.user_role_xref is 'Table that associates a user with a role type. A user can have multiple roles';


CREATE TYPE bctw.collar_access_type AS ENUM ('none', 'view', 'manage');
COMMENT ON TYPE bctw.collar_access_type IS 'Used in the user_collar_access table for defining how a user can interact with a collar.';
-- is a 'both' type needed? can a user be able ot manage a collar without being able to view its data?

CREATE TABLE bctw.user_collar_access 
(
  user_id       uuid NOT NULL,
  collar_id     INTEGER NOT NULL,
  collar_access collar_access_type DEFAULT 'none',
  collar_vendor VARCHAR(50) NOT NULL,
  expire_date   TIMESTAMP,
  deleted       BOOLEAN DEFAULT false,
  deleted_at    TIMESTAMP,
  PRIMARY KEY (user_id, collar_id, collar_vendor)
);
COMMENT ON TABLE user_collar_access is 'User Collar Access is a table for associating a user with critter collars and the collar permissions';

-- todo: trigger on inserting to user_collar_access - ensure a row doesnt exist with collar_access_type 'owner' for this device_id

-- DROP FUNCTION get_user_role(text);

CREATE OR REPLACE FUNCTION bctw.get_user_role(strIdir TEXT)
RETURNS text AS $$
DECLARE
	role_type TEXT;
BEGIN
	
	IF NOT exists (SELECT 1 FROM bctw.user u WHERE u.idir = strIdir) 
    THEN RAISE EXCEPTION 'couldnt find user with IDIR %', strIdir;
	END IF;    
	
	SELECT urt.role_type INTO role_type
	FROM user_role_type urt 
	JOIN user_role_xref rx ON urt.role_id = rx.role_id
	JOIN "user" u ON u.user_id = rx.user_id 
	WHERE u.idir  = strIdir;

RETURN role_type;
END;
$$  LANGUAGE plpgsql;

/*
  returns a json array of integers representing collar ids for the supplied user IDIR
*/
-- DROP FUNCTION bctw.get_collars(TEXT);

CREATE OR REPLACE  FUNCTION bctw.get_collars(strIdir TEXT)
RETURNS json AS $$
DECLARE
  collar_ids INT[];
BEGIN
	IF NOT exists (SELECT 1 FROM bctw.user u WHERE u.idir = strIdir) 
	THEN RAISE EXCEPTION 'couldnt find user with IDIR %', strIdir;
	END IF; 

  SELECT ARRAY(   
    SELECT collar_id
    FROM bctw.user_collar_access uca
      JOIN bctw.user u ON u.user_id = uca.user_id
      WHERE u.idir = strIdir
      AND uca.collar_access = any('{manage,view}')
  ) INTO collar_ids;

RETURN array_to_json(collar_ids);

END;
$$  LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION bctw.add_user(userJson json, roleType TEXT)
 RETURNS boolean
 LANGUAGE plpgsql
AS $$
DECLARE 
newid uuid := uuid_generate_v4();
BEGIN
	
	IF NOT exists (SELECT 1 FROM bctw.user_role_type WHERE role_type = roleType)
		THEN RAISE EXCEPTION '% is not a valid role type', roleType;
	END IF;
	
	WITH user_record AS
	(SELECT idir, bceid, email FROM json_populate_record(null::bctw.user, userJson))
	INSERT INTO  bctw.user (user_id, idir, bceid, email)
    	SELECT newid, ur.idir, ur.bceid, ur.email FROM user_record ur;

  INSERT INTO user_role_xref (user_id, role_id)
  VALUES (newid, (SELECT role_id FROM bctw.user_role_type urt WHERE urt.role_type = roleType));
	RETURN true;
END;
$$