-- Preserve legacy Cloudinary reports; new intents explicitly identify their provider.
ALTER TABLE catalog.report_uploads ADD COLUMN storage_provider varchar(50) NOT NULL
    DEFAULT 'CLOUDINARY' CHECK (storage_provider IN ('CLOUDINARY', 'FIREBASE'));
ALTER TABLE catalog.media_assets DROP CONSTRAINT media_assets_storage_provider_check;
ALTER TABLE catalog.media_assets ADD CONSTRAINT media_assets_storage_provider_check
    CHECK (storage_provider IN ('S3', 'CLOUDINARY', 'FIREBASE'));
