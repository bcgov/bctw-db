/*

*/
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

/*

*/
-- drop function bctw.add_user(json, text);

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