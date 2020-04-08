# Update Statements

UPDATE public.vendor_data_merge_with_long_lat as vdm
   SET mort_date_gmt = to_timestamp(lotex."   Mortality Date & Time [GMT]"),
	   mort_date_local = to_timestamp(lotex."   Mortality Date & Time [Local]"),
	   cancel_date_gmt = to_timestamp(lotex."      Cancel Date & Time [GMT]"),
	   cancel_date_local = to_timestamp(lotex."      Cancel Date & Time [Local]")
  FROM public.sample_lotex_mrt_0081267 as lotex
 WHERE lotex." Device ID" = vdm.collar_id
   AND vendor = 'Lotex';

UPDATE public.vendor_data_merge_with_long_lat as vdm
   SET mort_date_gmt = to_timestamp(lotex."   Mortality Date & Time [GMT]"),
	   mort_date_local = to_timestamp(lotex."   Mortality Date & Time [Local]"),
	   cancel_date_gmt = to_timestamp(lotex."      Cancel Date & Time [GMT]"),
	   cancel_date_local = to_timestamp(lotex."      Cancel Date & Time [Local]")
  FROM public.sample_lotex_mrt_0101835 as lotex
 WHERE lotex." Device ID" = vdm.collar_id
   AND vendor = 'Lotex';

   /*AND vdm.local_timestamp = (SELECT MAX(local_timestamp) 
						        FROM public.vendor_data_merge
						       WHERE " Device ID" = vdm.collar_id 
						         AND vendor ='lotex')*/