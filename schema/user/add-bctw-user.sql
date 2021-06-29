
update beekeepers set active = 't' where beekeeper_id = 28;
update beekeepers set active = 't' where beekeeper_id = 29;

insert into bctw.user (
  idir,
  email,
  firstname,
  lastname
) values (
  'bauger',
  'brett.auger@gov.bc.ca',
  'Brett',
  'Auger'
);

-- Create new 'access' column
alter table bctw.user add column access varchar(8);
comment on column bctw.user.access is 'Status of user onboarding. They have passed through keycloak then must request special access to the application. Limited to: pending, denied or granted';
ALTER TABLE bctw.user ADD CONSTRAINT "enforce_access" CHECK (access = ANY (ARRAY['pending', 'denied', 'granted']));

-- Insert access data
update bctw.user set access = 'granted';

