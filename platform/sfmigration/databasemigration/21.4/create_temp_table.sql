SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

  IF EXISTS (SELECT * FROM sys.objects
WHERE object_id = OBJECT_ID('$(DestinationDBSchema).[ml_package_versions_temp]'))
BEGIN
  SET NOEXEC ON;
END

CREATE TABLE $(DestinationDBSchema).[ml_package_versions_temp](
	[id] [uniqueidentifier] NOT NULL,
	[tenant_id] [varchar](36) NOT NULL,
	[account_id] [varchar](36) NOT NULL,
	[organization_id] [varchar](36) NOT NULL,
	[version] [int] NOT NULL,
	[ml_package_language] [varchar](32) NOT NULL,
	[processor_type] [varchar](32) NOT NULL,
	[status] [varchar](32) NOT NULL,
	[change_log] [nvarchar](2048) NULL,
	[output_description] [nvarchar](2048) NULL,
	[input_description] [nvarchar](2048) NULL,
	[content_uri] [varchar](2048) NULL,
	[staging_uri] [varchar](2048) NULL,
	[tags] [nvarchar](255) NULL,
	[author] [nvarchar](255) NULL,
	[created_on] [numeric](18, 0) NULL,
	[modified_on] [numeric](18, 0) NULL,
	[created_by] [nvarchar](50) NULL,
	[modified_by] [nvarchar](50) NULL,
	[ml_package_id] [uniqueidentifier] NOT NULL,
	[is_public] [bit] NOT NULL,
	[activity_detail] [varchar](2048) NULL,
	[activity_documentation] [varchar](2048) NULL,
	[activity_version] [varchar](32) NULL,
	[cpu] [decimal](5, 2) NULL,
	[memory] [decimal](5, 2) NULL,
	[gpu] [decimal](5, 2) NULL,
	[retrainable] [bit] NOT NULL,
	[training_version] [int] NOT NULL,
	[project_id] [varchar](36) NULL,
	[settings] [varchar](max) NULL,
	[source_package_version_id] [varchar](36) NULL,
	[config] [varchar](max) NULL,
	[image_path] [varchar](2048) NULL,
	[used_by_active_pipeline_count] [int] NOT NULL,
	[source_package_version] [int] NOT NULL,
	[source_package_training_version] [int] NOT NULL,
	[language_version] [int] NOT NULL,
	[min_aifabric_version] [varchar](36) NULL,
	[settings_file_json] [nvarchar](max) NULL,
 CONSTRAINT [PK_ml_package_versions_temp] PRIMARY KEY CLUSTERED
(
	[id] ASC
)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

ALTER TABLE $(DestinationDBSchema).[ml_package_versions_temp] ADD  CONSTRAINT [DF_ml_package_versions_temp_is_public]  DEFAULT ((0)) FOR [is_public]
GO

ALTER TABLE $(DestinationDBSchema).[ml_package_versions_temp] ADD  CONSTRAINT [DF_ml_package_versions_temp_cpu]  DEFAULT ((0)) FOR [cpu]
GO

ALTER TABLE $(DestinationDBSchema).[ml_package_versions_temp] ADD  CONSTRAINT [DF_ml_package_versions_temp_memory]  DEFAULT ((0)) FOR [memory]
GO

ALTER TABLE $(DestinationDBSchema).[ml_package_versions_temp] ADD  CONSTRAINT [DF_ml_package_versions_temp_gpu]  DEFAULT ((0)) FOR [gpu]
GO

ALTER TABLE $(DestinationDBSchema).[ml_package_versions_temp] ADD  CONSTRAINT [DF_ml_package_versions_temp_retrainable]  DEFAULT ((0)) FOR [retrainable]
GO

ALTER TABLE $(DestinationDBSchema).[ml_package_versions_temp] ADD  CONSTRAINT [DF_ml_package_versions_temp_training_version]  DEFAULT ((0)) FOR [training_version]
GO

ALTER TABLE $(DestinationDBSchema).[ml_package_versions_temp] ADD  CONSTRAINT [DF_ml_package_versions_temp_used_by_active_pipeline_count]  DEFAULT ((0)) FOR [used_by_active_pipeline_count]
GO

ALTER TABLE $(DestinationDBSchema).[ml_package_versions_temp] ADD  CONSTRAINT [DF_ml_package_versions_temp_source_package_version]  DEFAULT ((0)) FOR [source_package_version]
GO

ALTER TABLE $(DestinationDBSchema).[ml_package_versions_temp] ADD  CONSTRAINT [DF_ml_package_versions_temp_source_package_training_version]  DEFAULT ((0)) FOR [source_package_training_version]
GO

ALTER TABLE $(DestinationDBSchema).[ml_package_versions_temp] ADD  CONSTRAINT [DF_ml_package_versions_temp_language_version]  DEFAULT ((0)) FOR [language_version]
GO

SET NOEXEC OFF;
GO
