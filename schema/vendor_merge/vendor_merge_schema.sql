--  create or replace view vendor_merge as
--  select
  --  geom "geom",
  --  recdatetime "date_recorded",
  --  deviceid "device_id",
  --  'lotek' "device_vendor"
--  from
  --  lotek_collar_data

--  union

--  select
  --  geom "geom",
  --  scts "date_recorded",
  --  idcollar "device_id",
  --  'vectronics' "device_vendor"
--  from
  --  vectronics_collar_data
  --  ;

--  select
  --  max(recdatetime) "Most recent record",
  --  deviceid "device id"
--  from
  --  lotek_collar_data
--  group by
  --  deviceid
--  ;





-- Currently set to output json
-- create or replace view vendor_merge as
with pings as (
  select
    geom "geom",
    recdatetime "date_recorded",
    deviceid "device_id",
    'Lotek' "device_vendor"
  from
    lotek_collar_data
  where
    recdatetime > (current_date - INTERVAL '2 months') and
    st_isValid(geom)

  union

  select
    geom "geom",
    scts "date_recorded",
    idcollar "device_id",
    'Vectronics' "device_vendor"
  from
    vectronics_collar_data
  where
    scts > (current_date - INTERVAL '2 months') and
    st_isValid(geom)
),

ping_plus as (
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
    p.geom "geom",
    ROW_NUMBER() OVER (ORDER BY 1) as id
  from
    pings p,
    caribou_critter c
  where
    p.device_id = c.device_id and
    p.device_vendor = c.collar_make
)

SELECT jsonb_build_object(
    'type',       'Feature',
    'id',         id,
    'geometry',   ST_AsGeoJSON(geom)::jsonb,
    'properties', to_jsonb(row) - 'id'  - 'geom'
) FROM (SELECT * FROM ping_plus) row;


-- This works but we lose key names
--  select row_to_json(fc)
   --  FROM ( SELECT 'FeatureCollection' As type, array_to_json(array_agg(f)) As features
   --  FROM (
    --  SELECT 'Feature' As type,
      --  ST_AsGeoJSON(lg.geom)::json As geometry,
      --  row_to_json((
        --  species,
        --  animal_status
      --  )) As properties
     --  FROM vendor_merge As lg
     --  limit 1
  --  ) As f )  As fc
--  ;


/*
-- This query is much slower because there's two joins instead of one
create or replace view vendor_merge as
select
  c.species "species",
  c.caribou_population_unit "population_unit",
  c.animal_id "animal_id",
  c.animal_status "animal_status",
  c.life_stage "live_stage",
  c.calf_at_heel "calf_at_heel",
  c.radio_frequency "radio_frequency",
  c.satellite_network "satellite_network",
  p.geom "geom",
  p.recdatetime "date_recorded",
  p.deviceid "device_id",
  'Lotek' "device_vendor"
from
  lotek_collar_data p,
  caribou_critter c
where
  p.deviceid = c.device_id and
  c.collar_make = 'Lotek'

union

select
  c.species "species",
  c.caribou_population_unit "population_unit",
  c.animal_id "animal_id",
  c.animal_status "animal_status",
  c.life_stage "live_stage",
  c.calf_at_heel "calf_at_heel",
  c.radio_frequency "radio_frequency",
  c.satellite_network "satellite_network",
  p.geom "geom",
  p.scts "date_recorded",
  p.idcollar "device_id",
  'Vectronics' "device_vendor"
from
  vectronics_collar_data p,
  caribou_critter c
where
  p.idcollar = c.device_id and
  c.collar_make = 'Vectronics'
;
*/
