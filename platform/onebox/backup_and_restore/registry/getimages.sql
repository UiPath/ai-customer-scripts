set nocount on;
select distinct mpi.image_uri from aifabric.ml_package_images mpi inner join aifabric.ml_skill_versions msv on msv.ml_package_version_id = mpi.version_id and  msv.processor = mpi.processor
where msv.status in ('UPDATING', 'COMPLETED', 'VALIDATING_DEPLOYMENT') and mpi.status = 'ACTIVE';