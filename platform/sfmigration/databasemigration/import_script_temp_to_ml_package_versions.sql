INSERT INTO $(DestinationDBSchema).[ml_package_versions] ([id],[tenant_id],[account_id],[organization_id],[version],[ml_package_language],[processor_type],[status],[change_log],[output_description],[input_description],[content_uri],[staging_uri],[tags],[author],[created_on],[modified_on],[created_by],[modified_by],[ml_package_id],[is_public],[activity_detail],[activity_documentation],[activity_version],[cpu],[memory],[gpu],[retrainable],[training_version],[project_id],[settings],[source_package_version_id],[config],[image_path],[source_package_version],[source_package_training_version],[language_version],[min_aifabric_version]) SELECT [id],[tenant_id],[account_id],[organization_id],[version],[ml_package_language],[processor_type],[status],[change_log],[output_description],[input_description],[content_uri],[staging_uri],[tags],[author],[created_on],[modified_on],[created_by],[modified_by],[ml_package_id],[is_public],[activity_detail],[activity_documentation],[activity_version],[cpu],[memory],[gpu],[retrainable],[training_version],[project_id],[settings],[source_package_version_id],[config],[image_path],[source_package_version],[source_package_training_version],[language_version],[min_aifabric_version]  FROM $(DestinationDBSchema).[ml_package_versions_temp] where tenant_id='$(DestinationTenantId)';