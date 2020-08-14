
create or replace view vendor_merge as
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
