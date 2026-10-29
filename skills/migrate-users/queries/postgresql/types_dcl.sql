-- Extracts custom composite, enum, domain, range, and multirange type privileges
-- (USAGE) and ownership from pg_type.
-- Excludes implicit table row types, generated arrays, and system accounts.

WITH
  raw_type_acls AS (
    SELECT
      n.nspname AS schema_name,
      t.typname AS type_name,
      r_owner.rolname AS type_owner,
      CASE t.typtype
        WHEN 'c' THEN 'COMPOSITE'
        WHEN 'e' THEN 'ENUM'
        WHEN 'd' THEN 'DOMAIN'
        WHEN 'r' THEN 'RANGE'
        WHEN 'm' THEN 'MULTIRANGE'
        ELSE NULL
        END AS type_category,
      CASE WHEN acl.grantee = 0 THEN 'PUBLIC' ELSE r_grantee.rolname END AS grantee,
      r_grantor.rolname AS grantor,
      acl.privilege_type,
      acl.is_grantable
    FROM pg_type AS t
    INNER JOIN pg_namespace AS n
      ON n.oid = t.typnamespace
    INNER JOIN pg_roles AS r_owner
      ON r_owner.oid = t.typowner
    CROSS JOIN LATERAL aclexplode(COALESCE(t.typacl, acldefault('T', t.typowner))) AS acl
    INNER JOIN pg_roles AS r_grantor
      ON r_grantor.oid = acl.grantor
    LEFT JOIN pg_roles AS r_grantee
      ON r_grantee.oid = acl.grantee
    WHERE
      n.nspname NOT IN ('pg_catalog', 'information_schema')
      AND n.nspname NOT LIKE 'pg\_toast%'
      AND n.nspname NOT LIKE 'pg\_temp%'
      AND t.typtype IN ('c', 'e', 'd', 'r', 'm')
      AND t.typelem = 0
      AND (
        t.typtype != 'c'
        OR EXISTS(SELECT 1 FROM pg_class AS c WHERE c.oid = t.typrelid AND c.relkind = 'c'))
      AND acl.grantee != t.typowner
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
FROM raw_type_acls AS a;
