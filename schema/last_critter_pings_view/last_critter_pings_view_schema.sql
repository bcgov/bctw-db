drop materialized view last_critter_pings_view;

create materialized view last_critter_pings_view as
select distinct on (device_id)
  geojson
from
  vendor_merge
order by
  device_id,
  date_recorded desc
;
