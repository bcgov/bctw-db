--
--PURPOSE:
--Populate dev db with prod data from previous 2 years of collar data.
--While skipping all user-related data
--
--INSTRUCTIONS
--Highlight and right click ONLY the SQL, click Execute, click export from Query,
--click Database from list not CSV, target container to dev db, click proceed.
--
--Skip onboarding--

--Skip permisson_request--

--Skip user--

--Skip user_animal_assignment--

--Skip user_defined_field--

--Skip user_role_xref--

select *
from bctw.animal;

select *
from bctw.api_vectronics_collar_data;

select *
from bctw.api_vectronics_collar_data_bak;

select *
from bctw.ats_collar_data;

select *
from bctw.code;

select *
from bctw.code_category;

select *
from bctw.code_header;

select *
from bctw.collar
WHERE created_at > CURRENT_DATE - interval '24 months';

select *
from bctw.collar_animal_assignment
WHERE created_at > CURRENT_DATE - interval '24 months';

select *
from bctw.collar_vendor_api_credentials;

select *
from bctw.lotek_collar_data
WHERE uploadtimestamp > CURRENT_DATE - interval '24 months';

select *
from bctw.species;

select *
from bctw.telemetry_sensor_alert;

select *
from user_role_type;

select *
from bctw.vectronics_collar_data
WHERE acquisitiontime > CURRENT_DATE - interval '24 months';