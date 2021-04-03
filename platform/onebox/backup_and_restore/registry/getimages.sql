set nocount on;
select distinct mpi.image_uri from ml_package_images mpi inner join ml_skill_versions msv on msv.ml_package_version_id = mpi.version_id and  msv.processor = mpi.processor
where msv.status in ('UPDATING', 'COMPLETED', 'VALIDATING_DEPLOYMENT') and mpi.status = 'ACTIVE';