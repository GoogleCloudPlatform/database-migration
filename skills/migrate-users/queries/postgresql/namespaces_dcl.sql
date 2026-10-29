-- Extracts schema-level privileges (USAGE, CREATE) and schema ownership for all
-- non-system schemas in the current database from pg_namespace.
-- Excludes cloud provider infrastructure and database engine system accounts.

WITH
  raw_schema_acls AS (
    SELECT
      n.nspname AS schema_name,
      r_owner.rolname AS schema_owner,
      CASE WHEN acl.grantee = 0 THEN 'PUBLIC' ELSE r_grantee.rolname END AS grantee,
      r_grantor.rolname AS grantor,
      acl.privilege_type,
      acl.is_grantable
    FROM pg_namespace AS n
    INNER JOIN pg_roles AS r_owner
      ON r_owner.oid = n.nspowner
    CROSS JOIN LATERAL aclexplode(COALESCE(n.nspacl, acldefault('n', n.nspowner))) AS acl
    INNER JOIN pg_roles AS r_grantor
      ON r_grantor.oid = acl.grantor
    LEFT JOIN pg_roles AS r_grantee
      ON r_grantee.oid = acl.grantee
    WHERE
      n.nspname NOT IN ('pg_catalog', 'information_schema')
      AND n.nspname NOT LIKE 'pg\_toast%'
      AND n.nspname NOT LIKE 'pg\_temp%'
      AND acl.grantee != n.nspowner
      AND (acl.grantee = 0 OR r_grantee.rolname IS NOT NULL)
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
FROM raw_schema_acls AS a;
