create or replace view vendor_merge as
select
  geom "geom",
  recdatetime "date_recorded",
  deviceid "device_id",
  'lotek' "device_vendor"
from
  lotek_collar_data

union

select
  geom "geom",
  scts "date_recorded",
  idcollar "device_id",
  'vectronics' "device_vendor"
from
  vectronics_collar_data
  ;

select
  max(recdatetime) "Most recent record",
  deviceid "device id"
from
  lotek_collar_data
group by
  deviceid
;





-- TODO: The indexes are not be used here. Join vendors with collars separate before union
-- This query currently takes 5 seconds. We can do better.
with pings as (
  select
    geom "geom",
    recdatetime "date_recorded",
    deviceid "device_id",
    'lotek' "device_vendor"
  from
    lotek_collar_data

  union

  select
    geom "geom",
    scts "date_recorded",
    idcollar "device_id",
    'vectronics' "device_vendor"
  from
    vectronics_collar_data
)

select
  c.species "species",
  c.caribou_population_unit "population_unit",
  c.animal_id "animal_id",
  c.animal_status "animal_status",
  c.life_stage "live_stage",
  c.calf_at_heel "calf_at_heel",
  c.radio_frequency "radio_frequency",
  c.satellite_network "satellite_network",
  p.device_id "device_id",
  p.date_recorded "date_recorded",
  p.device_vendor "device_vendor",
  p.geom "geom"
from
  pings p,
  caribou_critter c
where
  p.device_id = c.device_id
;

