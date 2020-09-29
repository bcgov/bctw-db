/*
  assumptions / checks for all queries
  * user being assigned isnt expired / deleted

*/

/*  an administrator wants to assign a user to 'owner' status 
  assumptions/checks:
  * user assigning is an admin
  * user being assigned isnt an admin


*/

/* view telemetry data 
  * is/will all telemetry data for a collar be obtained from the merged view?
  assumptions: 
  * user is type owner or observer
  *
*/
WITH user_collar_ids AS 
(
  SELECT collar_id FROM user_collar_access uca
  JOIN user_role_xref ur ON
  uca.user_id = ur.user_id
  WHERE uca.user_id = :userid
  AND ur.role_id IN (:role_ids_for_owner_and_observer) -- probably need to join user_role_type for role_type codes
)
SELECT * FROM vendor_merge_view vmv
WHERE vmv.device_id IN (SELECT * FROM user_collar_ids);
