CREATE SCHEMA IF NOT EXISTS "public";

CREATE TABLE "account_drive_bindings" (
    "account_key" VARCHAR(64) NOT NULL,
    "app_root_folder_id" VARCHAR(256) NOT NULL,
    "app_root_folder_name" VARCHAR(256),
    "schema_version" INTEGER NOT NULL DEFAULT 1,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "account_drive_bindings_pkey" PRIMARY KEY ("account_key")
);
