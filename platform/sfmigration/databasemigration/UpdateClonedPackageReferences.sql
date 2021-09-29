-- update cloned packages source package id

UPDATE mpc
SET  mpc.source_package_id = mpo.id
FROM $(DestinationDBSchema).ml_packages mpc
JOIN $(DestinationDBSchema).ml_packages mpo ON (mpc.source_package_name = mpo.name and mpo.is_public=1
and mpc.source_package_name is not null);


-- update cloned packages source package version id
UPDATE mpvc
SET  mpvc.source_package_version_id = mpvo.id
FROM $(DestinationDBSchema).ml_package_versions mpvc ,
$(DestinationDBSchema).ml_package_versions mpvo
JOIN $(DestinationDBSchema).ml_packages mpo on mpo.id = mpvo.ml_package_id
JOIN $(DestinationDBSchema).ml_packages mpc on mpc.source_package_name = mpo.name
where mpc.source_package_name is not null 
and mpo.is_public = 1
and mpvc.version = mpvo.version
and mpc.last_uploaded_version = mpvo.version
and mpvc.source_package_version_id is not null;

-- update cloned packages source package version id in case the source package does not exist
update mpvc set 
mpvc.source_package_version_id= mpvo.id,
mpvc.source_package_version=mpvo.version
from $(DestinationDBSchema).ml_package_versions mpvc
join $(DestinationDBSchema).ml_packages mpc
on mpc.id = mpvc.ml_package_id
join (   SELECT *
  FROM $(DestinationDBSchema).ml_package_versions AS mpv1
  WHERE version = 
	(	SELECT MAX([version]) AS maxVersion
		FROM $(DestinationDBSchema).ml_package_versions AS mpv2 
		WHERE mpv1.ml_package_id = mpv2.ml_package_id
		and mpv2.source_package_version_id is null
	) ) mpvo
on mpc.source_package_id = mpvo.ml_package_id
where mpvc.source_package_version_id is not null
and mpvc.source_package_version_id not in 
(select id from $(DestinationDBSchema).ml_package_versions);
