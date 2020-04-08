INSERT INTO public.vendor_data_merge_dump
select * from public.vendor_data_merge where vendor = 'Lotex'
and mort_date_gmt is not null
and mort_date_local is not null
and cancel_date_gmt is not null
and cancel_date_local is not null
limit 5;

INSERT INTO public.vendor_data_merge_dump
select * from public.vendor_data_merge where vendor = 'Lotex'
and collar_id = 101891
limit 5;

INSERT INTO public.vendor_data_merge_dump
select * from public.vendor_data_merge where vendor = 'ATS'
limit 5;

INSERT INTO public.vendor_data_merge_dump
select * from public.vendor_data_merge where vendor = 'Vectronics'
and collar_id = 15024
limit 5;

INSERT INTO public.vendor_data_merge_dump
select * from public.vendor_data_merge where vendor = 'Vectronics'
and collar_id = 16263
limit 5;

update public.vendor_data_merge_dump
set longitude = -82.02531, -- longitude
	latitude = 46.37147, -- Latitude
	geometry = ST_MakePoint(-82.02531,46.37147); --geometry

update public.vendor_data_merge_dump 
set easting = 0.0, -- hide
    northing = 0.0 -- hide
where vendor = 'Vectronics'; 	

insert into public.collar_metadata_cariboo_dump select * from public.collar_metadata_cariboo limit 5;
insert into public.collar_metadata_field_validation_dump select * from public.collar_metadata_field_validation limit 5;
insert into public.collar_metadata_kootenay_dump select * from public.collar_metadata_kootenay limit 5;
insert into public.collar_metadata_monthly_summary_dump select * from public.collar_metadata_monthly_summary limit 5;
insert into public.collar_metadata_omineca_dump select * from public.collar_metadata_omineca limit 5;
insert into public.collar_metadata_peace_dump select * from public.collar_metadata_peace limit 5;
insert into public.collar_metadata_skeena_dump select * from public.collar_metadata_skeena limit 5;
insert into public.collar_metadata_thompson_dump select * from public.collar_metadata_thompson limit 5;
insert into public.duplicate_animal_ids_tb_dump select * from public.duplicate_animal_ids_tb limit 5;

insert into public.sample_ats_dump select * from public.sample_ats limit 5;
update public.sample_ats_dump set "Longitude" = -82.02531, "Latitude" = 46.37147;

insert into public.sample_gpsplusx_collar_15024_dump select * from public.sample_gpsplusx_collar_15024 limit 5;
update public.sample_gpsplusx_collar_15024_dump set "Longitude [°]" = -82.02531, "Latitude [°]" = 46.37147;

insert into public.sample_gpsplusx_collar_16263_dump select * from public.sample_gpsplusx_collar_16263 limit 5;
update public.sample_gpsplusx_collar_16263_dump set "Longitude [°]" = -82.02531, "Latitude [°]" = 46.37147;

insert into public.sample_lotex_gps_0081267_dump select * from public.sample_lotex_gps_0081267 limit 5;
update public.sample_lotex_gps_0081267_dump set "   Longitude" = -82.02531, "    Latitude" = 46.37147;

insert into public.sample_lotex_gps_0101891_dump select * from public.sample_lotex_gps_0101891 limit 5;
update public.sample_lotex_gps_0101891_dumpset set "   Longitude" = -82.02531, "    Latitude" = 46.37147;

insert into public.sample_lotex_mrt_0081267_dump select * from public.sample_lotex_mrt_0081267 limit 5;
update public.sample_lotex_mrt_0081267_dump set  "   Longitude" = -82.02531, "    Latitude" = 46.37147;

insert into public.sample_lotex_mrt_0101835_dump select * from public.sample_lotex_mrt_0101835 limit 5;
update public.sample_lotex_mrt_0101835_dump set  "   Longitude" = -82.02531, "    Latitude" = 46.37147;

-- Hide all geographic information
update public.collar_metadata_cariboo_dump 
set "Capture UTM Zone" = 0.0,
    "Capture UTM Easting" = 0.0,
	"Capture UTM Northing" = 0.0;

update public.collar_metadata_kootenay_dump
set "Capture UTM Zone" = 0.0,
    "Capture UTM Easting" = 0.0,
	"Capture UTM Northing" = 0.0;
	
update public.collar_metadata_omineca
set "Capture UTM Zone" = 0.0,
    "Capture UTM Easting" = 0.0,
	"Capture UTM Northing" = 0.0;

update public.collar_metadata_peace_dump
set "Capture UTM Zone" = 0.0,
    "Capture UTM Easting" = 0.0,
	"Capture UTM Northing" = 0.0;

update public.collar_metadata_skeena_dump
set "Capture UTM Zone" = 0.0,
    "Capture UTM Easting" = 0.0,
	"Capture UTM Northing" = 0.0;
	
update public.collar_metadata_thompson_dump
set "Capture UTM Zone" = 0.0,
    "Capture UTM Easting" = 0.0,
	"Capture UTM Northing" = 0.0;	
	
update public.collar_metadata_monthly_summary_dump
set "Capture UTM Zone" = 0.0,
    "Capture UTM Easting" = 0.0,
	"Capture UTM Northing" = 0.0;