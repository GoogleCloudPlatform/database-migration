-- Extracts function and stored procedure execution privileges (EXECUTE), argument
-- signatures for overloading resolution, and ownership from pg_proc.
-- Excludes non-callable trigger functions, cloud provider, and system accounts.

WITH
  raw_routine_acls AS (
    SELECT
      n.nspname AS schema_name,
      p.proname AS routine_name,
      r_owner.rolname AS routine_owner,
      pg_get_function_identity_arguments(p.oid) AS routine_signature,
      'ROUTINE' AS routine_type,
      CASE WHEN acl.grantee = 0 THEN 'PUBLIC' ELSE r_grantee.rolname END AS grantee,
      r_grantor.rolname AS grantor,
      acl.privilege_type,
      acl.is_grantable
    FROM pg_proc AS p
    INNER JOIN pg_namespace AS n
      ON n.oid = p.pronamespace
    INNER JOIN pg_roles AS r_owner
      ON r_owner.oid = p.proowner
    CROSS JOIN LATERAL aclexplode(COALESCE(p.proacl, acldefault('f', p.proowner))) AS acl
    INNER JOIN pg_roles AS r_grantor
      ON r_grantor.oid = acl.grantor
    LEFT JOIN pg_roles AS r_grantee
      ON r_grantee.oid = acl.grantee
    WHERE
      n.nspname NOT IN ('pg_catalog', 'information_schema')
      AND n.nspname NOT LIKE 'pg\_toast%'
      AND n.nspname NOT LIKE 'pg\_temp%'
      AND p.prorettype NOT IN ('trigger'::regtype, 'event_trigger'::regtype)
      AND acl.grantee != p.proowner
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
FROM raw_routine_acls AS a;
