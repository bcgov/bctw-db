DROP TABLE IF EXISTS user;
DROP TABLE IF EXISTS user_role_type;
DROP TABLE IF EXISTS user_role_xref;

CREATE TABLE user
(
  user_id     uuid PRIMARY KEY DEFAULT uuid_generate_v1(),
  idir        VARCHAR,
  bceid       VARCHAR,
  email       VARCHAR,
  expire_date TIMESTAMP,
  deleted     BOOLEAN,
  deleted_at  TIMESTAMP
)


CREATE TABLE user_role_type
(
  role_id     PRIMARY KEY DEFAULT uuid_generate_v1(),
  role_type   VARCHAR,
  description VARCHAR,
)
COMMENT ON TABLE user_role_type is 'User Role Type is a code table for role types. Current role types are Administrator, Owner, Observer';


CREATE TABLE user_role_xref 
(
  user_id uuid REFERENCES user(user_id),
  role_id uuid REFERENCES user_role_type(role_id),
  PRIMARY KEY (user_id, role_id)
)
COMMENT ON TABLE user_role_xref is 'Table that associates a user with a role type. A user can have multiple roles';


CREATE TABLE user_collar_access 
(
  -- id            PRIMARY KEY DEFAULT uuid_generate_v1(),
  user_id       uuid,
  -- role_id       uuid,
  collar_id     INTEGER,
  collar_vendor VARCHAR,
  expire_date   TIMESTAMP,
  deleted       BOOLEAN,
  deleted_at    TIMESTAMP
  PRIMARY KEY (user_id, collar_id, collar_vendor)
)
COMMENT ON TABLE user_collar_access is 
'User Collar Access is a table for defining which and how a user can interact with a collar.';
--  A collar can only be assigned to one user of the Owner type at a time.