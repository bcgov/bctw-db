/*
  Create and document the onboarding table.
  This will fill two purposes:
    1. Power the admin table for granting and denying access to BCTW
    2. The source of truth for allowing users into the site.
*/

drop table if exists bctw.onboarding;
create table bctw.onboarding (
	onboarding_id integer primary key,
  idir varchar(50),
  bceid varchar(50),
  email varchar(200),
  given_name varchar(200),
  family_name varchar(200),
  full_name varchar(600),
  request_date date,
  request_access varchar(14), -- This get's restricted
  access_status varchar(8), -- This also get's restricted
  access_status_date date
);

-- Create index
CREATE index onboarding_id_idx on bctw.onboarding (onboarding_id);

alter table bctw.onboarding add constraint "enforce_access"
  check (request_access = any (array['administrator','manager','editor','observer']));

-- This needs to sync the access value with then bctw.user table
alter table bctw.onboarding add constraint "enforce_status"
  check (access_status = any (array['pending','denied','granted']));

/*
 Comments
*/
comment on table bctw.onboarding is
  'Store all BC Telemetry Warehouse access requests and adjustments';
comment on column bctw.onboarding.idir is 'IDIR user name';
comment on column bctw.onboarding.bceid is 'BCeID user name';
comment on column bctw.onboarding.email is 'Email address';
comment on column bctw.onboarding.given_name is 'User given/first name';
comment on column bctw.onboarding.family_name is 'User family/last name';
comment on column bctw.onboarding.full_name is
  'User full name. This may include multiple middle names';
comment on column bctw.onboarding.request_date is 'Date the user initially requested access';
comment on column bctw.onboarding.request_access is
  'The level of access the user has requested. The column is restricted to one of the following; administrator, manager, editor & observer';
comment on column bctw.onboarding.access_status is 'Status the user access request is in. The column is restricted to one of the following; pending, denied & granted';
comment on column bctw.onboarding.access_status_date is 'Date the status was set';