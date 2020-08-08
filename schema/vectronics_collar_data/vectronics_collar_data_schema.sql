/**************************************************/
/*************vectronics_collar_data***************/
/**************************************************/
DROP TABLE IF EXISTS vectronics_collar_data;

CREATE TABLE vectronics_collar_data
(
    idposition integer unique not null,
    idcollar integer not null,
    acquisitiontime timestamp without time zone,
    scts timestamp without time zone,
    origincode text COLLATE pg_catalog."default",
    ecefx double precision,
    ecefy double precision,
    ecefz double precision,
    latitude double precision,
    longitude double precision,
    height double precision,
    dop double precision,
    idfixtype integer,
    positionerror double precision,
    satcount integer,
    ch01satid integer,
    ch01satcnr integer,
    ch02satid integer,
    ch02satcnr integer,
    ch03satid integer,
    ch03satcnr integer,
    ch04satid integer,
    ch04satcnr integer,
    ch05satid integer,
    ch05satcnr integer,
    ch06satid integer,
    ch06satcnr integer,
    ch07satid integer,
    ch07satcnr integer,
    ch08satid integer,
    ch08satcnr integer,
    ch09satid integer,
    ch09satcnr integer,
    ch10satid integer,
    ch10satcnr integer,
    ch11satid integer,
    ch11satcnr integer,
    ch12satid integer,
    ch12satcnr integer,
    idmortalitystatus integer,
    activity integer,
    mainvoltage double precision,
    backupvoltage double precision,
    temperature double precision,
    transformedx double precision,
    transformedy double precision
);
  
-- Create a geometry column with a spatial index
alter table vectronics_collar_data add column geom geometry(Point,4326);
create index vectronics_collar_data_gist on vectronics_collar_data using gist ("geom");

