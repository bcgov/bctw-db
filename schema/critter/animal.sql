
-- DROP TABLE IF EXISTS animal;

create  TABLE bctw.animal (
  animal_id VARCHAR(20) PRIMARY KEY,
  animal_status VARCHAR(100),
  calf_at_heel VARCHAR(10),
  capture_date DATE,
  capture_date_month INTEGER,
  capture_date_year INTEGER,
  capture_utm_zone INTEGER,
  capture_utm_easting INTEGER,
  capture_utm_northing INTEGER,
  ecotype VARCHAR(100),
  population_unit VARCHAR(80),
  ear_tag_left VARCHAR(50),
  ear_tag_right VARCHAR(50),
  life_stage VARCHAR(10),
  management_area VARCHAR(80),
  mortality_date DATE,
  mortality_utm_zone INTEGER,
  mortality_utm_easting INTEGER,
  mortality_utm_northing INTEGER,
  project VARCHAR(200),
  re_capture BOOLEAN,
  region VARCHAR(80),
  regional_contact VARCHAR(80),
  release_date DATE,
  sex VARCHAR(10),
  species VARCHAR(80),
  trans_location BOOLEAN,
  wlh_id VARCHAR(50),
  nickname VARCHAR(100)
);

CREATE index animal_id_idx on bctw.animal (animal_id);

COMMENT ON TABLE animal IS '';
COMMENT ON COLUMN animal.population_unit IS 'Name of the caribou population (herd)';
COMMENT ON COLUMN animal.ecotype IS 'Ecotype which categorizes caribou populations (herds) based on ecological conditions and behavioral adaptations';
COMMENT ON COLUMN animal.capture_date IS 'Date animal was captured';
COMMENT ON COLUMN animal.re_capture IS 'Has the animal been recaptured?';
COMMENT ON COLUMN animal.wlh_id IS 'A unique identifier assigned to an individual, independent of possible changes in mark method used. This field is mandatory if there is telemetry data for the individual. Format "xx-xxxx" is a 2 digit code for the year the biological sample kit was created for the capture event, followed by the numberic idnetifier of that indiviudal (eg, 18-1384)';
COMMENT ON COLUMN animal.mortality_date IS 'Date animal died';
COMMENT ON COLUMN animal.regional_contact IS 'Name of project coordinator - VC: should be an IDIR (or the logged-in ID)';
COMMENT ON COLUMN animal.animal_id IS 'Primary key. An identifier assigned to the animal by the project coordinator, independent of possible changes in mark method used. This field is mandatory if there is telemetry data for the animal. Field often contains text and numbers.';
COMMENT ON COLUMN animal.release_date IS 'Date the animal was released following capture. Generally, an animal is captured, collared and released at the same location on the same date. However, translocated animals will have a capture date that differs from the release date, with the release date corresponding to release at the new destination, be it a hard release into caribou habitat or a soft release into a temporary holding pen.';
COMMENT ON COLUMN animal.sex IS 'Animal gender';
COMMENT ON COLUMN animal.trans_location IS 'Identifies whether the animal is a translocation. TRUE = Animal is being captured for translocation and will be released at a new destination';

-- inserting unique animals from vendor_merge_view
/*
insert into animal (animal_id, animal_status, calf_at_heel, species, population_unit)
select distinct on (animal_id) animal_id, animal_status, calf_at_heel, species, population_unit from vendor_merge_view vmv
where animal_id is not null
order by animal_id;
*/

-- ex insert associating user with some animals
/*
with some_animals as 
(select a.animal_id from animal a limit 5),
ii as (select 'b7d2b2cc-0743-11eb-9785-0a58ac3382e5'::uuid as userid, current_date as effective_date, animal_id from some_animals)
insert into user_animal_assignment 
select userid, animal_id, effective_date from ii;
*/

-- getting only critters from merge view that user has access to
-- todo: check user_animal_assignment effective dates
with 
  userid as (select user_id from bctw.user where bctw.user.idir = 'jcraven'),
  ids as (select animal_id from user_animal_assignment uaa where uaa.user_id = (select * from userid))
select * from vendor_merge_view vmv where vmv.animal_id = any(select * from ids);

-- get a list of animals with their collar id
select a.*, c.device_id 
from animal a
join collar_animal_assignment caa on a.animal_id = caa.animal_id 
join collar c on caa.device_id = c.device_id 

/*
workflow for adding an animal -
  * user inputs animal data:
      - insert to animal table
      - row inserted to user_animal_assignment table.
  * user can then:
    * link the animal to an existing device 
    * or upload data for a new vectronics device
      - insert new data to to collar table
    * in either case:
      - insert to collar_animal_assignment table
*/

/* add animal 
  params: 
    animal row
    optional collar id
*/
create or replace function bctw.add_animal(stridir text, animaljson json, deviceid integer)
 returns json 
 language plpgsql
as $function$
declare 
userid uuid;
ar record;
today date := (select current_date);
enddate date := (select 'infinity'::date);
begin
	userid := (select user_id from bctw.user u where u.idir = stridir);
	-- create an animal row from the json
	select t.* into ar from (select * from json_populate_record(null::bctw.animal, animaljson)) t;
	
	insert into animal (animal_id, wlh_id, animal_status, nickname)
	values (ar.animal_id, ar.wlh_id, ar.animal_status, ar.nickname)
	on conflict (animal_id)
	do nothing; -- todo: upsert instead
	
	insert into user_animal_assignment (user_id, animal_id, effective_date, end_date)
		values (userid, ar.animal_id, today, enddate);

	if deviceid is not null
	then
			-- check the collar exists
			if not exists (select 1 from bctw.collar c where c.device_id = deviceid) 
				then raise exception 'this device id does not exist %', deviceid;
			end if; 
			-- check this collar isn't already assigned
			if exists (select 1 from collar_animal_assignment ca
				where ca.device_id = deviceid
				and daterange(today, enddate, '[]') && daterange(ca.effective_date, ca.end_date, '[]'))
				then raise exception 'collar % is already assigned to another critter', deviceid;
			end if;
		insert into collar_animal_assignment (animal_id, device_id, effective_date, end_date)
		values (ar.animal_id, deviceid, today, enddate);
	end if;

	return (select row_to_json(t) from (
		select a.animal_id, a.nickname, a.wlh_id, a.animal_status , caa.device_id from animal a 
 		left join collar_animal_assignment caa ON a.animal_id = caa.animal_id 
		where a.animal_id  = ar.animal_id
	) t);
end;
$function$
;