CREATE INDEX latest_transmission_idx ON bctw.latest_transmissions USING btree (collar_id);
CREATE INDEX lotek_collar_data_gist ON bctw.lotek_collar_data USING gist (geom);
CREATE INDEX lotek_collar_data_idx ON bctw.lotek_collar_data USING btree (deviceid);
CREATE INDEX lotek_collar_data_idx2 ON bctw.lotek_collar_data USING btree (recdatetime);
CREATE INDEX vectronics_collar_data_gist ON bctw.vectronics_collar_data USING gist (geom);
CREATE INDEX vendor_merge_critterless_gist ON bctw.vendor_merge_view_no_critter USING gist (geom);
CREATE INDEX vendor_merge_critterless_idx ON bctw.vendor_merge_view_no_critter USING btree (vendor_merge_id);
CREATE INDEX vendor_merge_critterless_idx2 ON bctw.vendor_merge_view_no_critter USING btree (date_recorded);