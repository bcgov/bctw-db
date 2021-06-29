
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

ALTER TABLE bctw.user ADD CONSTRAINT "enforce_access" CHECK (access = ANY (ARRAY['pending', 'denied', 'granted']));
