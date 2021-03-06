drop materialized view if exists vendor_merge_view;

create materialized view vendor_merge_view as
with pings as (
  select
    geom "geom",
    recdatetime "date_recorded",
    deviceid "device_id",
    'Lotek' "device_vendor"
  from
    lotek_collar_data
  where
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
    st_isValid(geom)
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
  p.geom "geom",
  ROW_NUMBER() OVER (ORDER BY 1) as vendor_merge_id,
  jsonb_build_object(
    'type',       'Feature',
    'id',         ROW_NUMBER() OVER (ORDER BY 1),
    'geometry',   ST_AsGeoJSON(p.geom)::jsonb,
    'properties', jsonb_build_object(
       'species',c.species,
       'population_unit',  c.caribou_population_unit,
       'animal_id',  c.animal_id,
       'animal_status',  c.animal_status,
       'live_stage',  c.life_stage,
       'calf_at_heel',  c.calf_at_heel,
       'radio_frequency',  c.radio_frequency,
       'satellite_network',  c.satellite_network,
       'device_id',  p.device_id,
       'date_recorded',  p.date_recorded,
       'device_vendor',  p.device_vendor
    )
  ) "geojson"
from
  pings p,
  caribou_critter c
where
  p.device_id = c.device_id and
  p.device_vendor = c.collar_make
;

comment on materialized view vendor_merge_view is 'Materialized view containing data merged from multiple vendor tables. Additional animal information is then merged to collar information. GeoJSON formatting is expensive so it is prepared and stored in a separate column.';

create index vendor_merge_gist on vendor_merge_view using gist ("geom");
create index vendor_merge_idx on vendor_merge_view(vendor_merge_id);
create index vendor_merge_idx2 on vendor_merge_view(date_recorded);
create index vendor_merge_idx3 on vendor_merge_view(animal_id);

COMMENT ON COLUMN vendor_merge_view.animal_status IS 'Animal Status is the vital status of the animal';
COMMENT ON COLUMN vendor_merge_view.geom IS 'Geom is a JSON object that contains spacial, collar, and animal data. An animal_id may have multiple rows with different spacial data.';
-- COMMENT ON COLUMN vendor_merge_view.live_stage IS '';
-- COMMENT ON COLUMN vendor_merge_view.population_unit IS '';
