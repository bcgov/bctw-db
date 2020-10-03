DROP TABLE IF EXISTS user;
DROP TABLE IF EXISTS user_role_type;
DROP TABLE IF EXISTS user_role_xref;
DROP TABLE IF EXISTS user_collar_access;

-- enable uuid_generate functions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE bctw.user
(
  user_id     uuid PRIMARY key DEFAULT uuid_generate_v1(),
  idir        VARCHAR(50),
  bceid       VARCHAR(50),
  email       VARCHAR(50),
  expire_date TIMESTAMP,
  deleted     BOOLEAN,
  deleted_at  TIMESTAMP
);

CREATE TABLE bctw.user_role_type
(
  role_id     uuid PRIMARY key DEFAULT uuid_generate_v1(),
  role_type   VARCHAR(50),
  description VARCHAR(100)
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
  deleted       BOOLEAN,
  deleted_at    TIMESTAMP,
  PRIMARY KEY (user_id, collar_id, collar_vendor)
);
COMMENT ON TABLE user_collar_access is 'User Collar Access is a table for associating a user with critter collars and the collar permissions';

-- todo: trigger on inserting to user_collar_access - ensure a row doesnt exist with collar_access_type 'owner' for this device_id