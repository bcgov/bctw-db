DROP TABLE IF EXISTS lotek_collar_data;
  
CREATE TABLE lotek_collar_data
( 
    channelstatus text,
    uploadtimestamp timestamp without time zone,
    latitude double precision,
    longitude double precision,
    altitude double precision,
    ecefx double precision,
    ecefy double precision,
    ecefz double precision,
    rxstatus integer,
    pdop double precision,
    mainv double precision,
    bkupv double precision,
    temperature double precision,
    fixduration integer,
    bhastempvoltage boolean,
    devname text COLLATE pg_catalog."default",
    deltatime double precision,
    fixtype text COLLATE pg_catalog."default",
    cepradius double precision,
    crc double precision,
    deviceid integer,
    recdatetime timestamp without time zone,
    timeid text unique not null
);

-- Create a geometry column with a spatial index
alter table lotek_collar_data add column geom geometry(Point,4326);
create index lotek_collar_data_gist on lotek_collar_data using gist ("geom");

-- Create an index on deviceid so we can avoid duplicates
create index lotek_collar_data_idx on lotek_collar_data(deviceid);
create index lotek_collar_data_idx2 on lotek_collar_data(recdatetime);

