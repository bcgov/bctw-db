#Queries for Cariboo sample data

--cariboo, kootenay, omineca, peace, skeena thompson
SELECT * FROM public.collar_metadata_cariboo

--field validation
SELECT * FROM public.collar_metadata_field_validation

--duplicate animal IDs
SELECT * FROM public.duplicate_animal_ids_tb

--ATS sample data
SELECT * FROM public.sample_ats

--Vectronic sample data
SELECT * FROM public.sample_gpsplusx_collar_15024

--Lotex sample data
SELECT * FROM public.sample_lotex_mrt_0081267