## user management questions from [requirements](https://apps.nrs.gov.bc.ca/int/confluence/pages/viewpage.action?pageId=77498717)

### collars
* Will a new table for collars be required? ex. a user wants to 'register/deregister' a collar, where will this live?

### user vs collar management 
* It seems different roles serve different purposes. The owner and administrator role have user and collar management abilities. 
* Perhaps the admin has two separate views: one for user management where they can add / remove users and perform other admin tasks. and another view for collar management where they can assign a collar to an owner.
* The owner only has access to the collar management view, where they can grant view permissions to an admin or observer.
  * should registering/deregistering a collar happen in the same view?
* The owner role is confusing. Does it only exist in the context of being an owner of certain collars? ie does it not exist as a system wide role type? 
* From the requirements:
  > "[Administrator] does not have the ability to view GPS collar information, however, unless granted by the “Owner”
  * An admin assigns a collar to an owner, and then that owner has to assign view permissions back to the admin. Does that make sense? Since a user can have multiple roles, what's preventing the admin from assigning owner status of a collar to themself? 


  ### required api calls (not db specific)
  * register / deregister a collar
  * change vendor-specific polling interval
  * > abililty to control data at a geographic level - ie points and polygons
  * 

  ### data model questions
  * is the vendor_merge_view a good enough representation of the data, or do critter and device specific tables need to be added?
  * where does collar and animal data come from?