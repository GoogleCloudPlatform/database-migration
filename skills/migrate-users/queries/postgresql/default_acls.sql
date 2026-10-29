-- Extracts default object privileges configured via ALTER DEFAULT PRIVILEGES across
-- tables, sequences, functions, types, and schemas from pg_default_acl.
-- Excludes cloud provider infrastructure and database engine system accounts.

WITH
  raw_default_acls AS (
    SELECT
      r_owner.rolname AS owner_role,
      n.nspname AS schema_name,
      CASE d.defaclobjtype
        WHEN 'r' THEN 'TABLES'
        WHEN 'S' THEN 'SEQUENCES'
        WHEN 'f' THEN 'FUNCTIONS'
        WHEN 'T' THEN 'TYPES'
        WHEN 'n' THEN 'SCHEMAS'
        WHEN 'L' THEN 'LARGE OBJECTS'
        ELSE NULL
        END AS object_type,
      CASE WHEN acl.grantee = 0 THEN 'PUBLIC' ELSE r_grantee.rolname END AS grantee,
      r_grantor.rolname AS grantor,
      acl.privilege_type,
      acl.is_grantable
    FROM pg_default_acl AS d
    INNER JOIN pg_roles AS r_owner
      ON r_owner.oid = d.defaclrole
    LEFT JOIN pg_namespace AS n
      ON n.oid = d.defaclnamespace
    CROSS JOIN LATERAL aclexplode(d.defaclacl) AS acl
    INNER JOIN pg_roles AS r_grantor
      ON r_grantor.oid = acl.grantor
    LEFT JOIN pg_roles AS r_grantee
      ON r_grantee.oid = acl.grantee
    WHERE
      (
        n.nspname IS NULL
        OR (
          n.nspname NOT IN ('pg_catalog', 'information_schema')
          AND n.nspname NOT LIKE 'pg\_toast%'
          AND n.nspname NOT LIKE 'pg\_temp%'))
      AND acl.grantee != d.defaclrole
      AND (acl.grantee = 0 OR r_grantee.rolname IS NOT NULL)
      AND r_owner.rolname NOT IN (
        'cloudsqladmin', 'cloudsqlsuperuser', 'alloydbadmin', 'rdsadmin', 'azure_pg_admin',
        'azure_superuser', 'azuresu')
      AND r_owner.rolname NOT LIKE 'pg\_%'
      AND r_owner.rolname NOT LIKE 'cloudsql%'
      AND r_owner.rolname NOT LIKE 'alloydb%'
      AND r_owner.rolname NOT LIKE 'rds\_%'
      AND r_owner.rolname NOT LIKE 'awsdms\_%'
      AND CASE
        WHEN acl.grantee = 0 THEN 'PUBLIC'
        ELSE r_grantee.rolname
        END NOT IN (
          'postgres', 'cloudsqladmin', 'cloudsqlsuperuser', 'alloydbadmin', 'rdsadmin',
          'azure_pg_admin', 'azure_superuser', 'azuresu')
      AND CASE WHEN acl.grantee = 0 THEN 'PUBLIC' ELSE r_grantee.rolname END NOT LIKE 'pg\_%'
      AND CASE WHEN acl.grantee = 0 THEN 'PUBLIC' ELSE r_grantee.rolname END NOT LIKE 'cloudsql%'
      AND CASE WHEN acl.grantee = 0 THEN 'PUBLIC' ELSE r_grantee.rolname END NOT LIKE 'alloydb%'
      AND CASE WHEN acl.grantee = 0 THEN 'PUBLIC' ELSE r_grantee.rolname END NOT LIKE 'rds\_%'
      AND CASE WHEN acl.grantee = 0 THEN 'PUBLIC' ELSE r_grantee.rolname END NOT LIKE 'awsdms\_%'
  )
SELECT row_to_json(a) AS privilege
FROM raw_default_acls AS a;
