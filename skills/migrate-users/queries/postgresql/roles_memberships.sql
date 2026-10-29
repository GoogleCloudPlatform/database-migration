-- Extracts cluster-wide database users, role attributes, configuration settings,
-- and role membership hierarchies from pg_roles and pg_auth_members.
-- Excludes cloud provider infrastructure and database engine system accounts.

WITH
  filtered_roles AS (
    SELECT
      r.oid,
      r.rolname,
      r.rolsuper,
      r.rolinherit,
      r.rolcreaterole,
      r.rolcreatedb,
      r.rolcanlogin,
      r.rolreplication,
      r.rolbypassrls,
      r.rolconnlimit,
      r.rolconfig,
      NULL::text AS rolpassword,
      r.rolvaliduntil
    FROM pg_roles AS r
    WHERE
      r.rolname NOT IN (
        'postgres', 'cloudsqladmin', 'cloudsqlsuperuser', 'alloydbadmin', 'rdsadmin',
        'azure_pg_admin', 'azure_superuser', 'azuresu', 'PUBLIC')
      AND r.rolname NOT LIKE 'pg\_%'
      AND r.rolname NOT LIKE 'cloudsql%'
      AND r.rolname NOT LIKE 'alloydb%'
      AND r.rolname NOT LIKE 'rds\_%'
      AND r.rolname NOT LIKE 'awsdms\_%'
  ),
  raw_roles AS (
    SELECT
      rolname,
      rolsuper,
      rolinherit,
      rolcreaterole,
      rolcreatedb,
      rolcanlogin,
      rolreplication,
      rolbypassrls,
      rolconnlimit,
      rolconfig,
      rolpassword,
      rolvaliduntil
    FROM filtered_roles
  ),
  -- PG16+ can store multiple pg_auth_members rows per (role, member) pair, one
  -- per grantor. Collapse them to one row; admin_option is true if any grant
  -- carries it. On PG15 and earlier (role, member) is unique, so this is a no-op.
  raw_memberships AS (
    SELECT
      r_role.rolname AS role_name,
      r_member.rolname AS member_name,
      bool_or(am.admin_option) AS admin_option
    FROM pg_auth_members AS am
    INNER JOIN pg_roles AS r_role
      ON r_role.oid = am.roleid
    INNER JOIN filtered_roles AS r_member
      ON r_member.oid = am.member
    WHERE
      r_role.rolname NOT IN (
        'postgres', 'cloudsqladmin', 'cloudsqlsuperuser', 'alloydbadmin', 'rdsadmin',
        'azure_pg_admin', 'azure_superuser', 'azuresu', 'PUBLIC')
      -- Keep IAM authentication groups so IAM users can be identified and mapped.
      AND (
        r_role.rolname NOT LIKE 'cloudsql%'
        OR r_role.rolname IN ('cloudsqliamuser', 'cloudsqliamserviceaccount'))
      AND (r_role.rolname NOT LIKE 'alloydb%' OR r_role.rolname = 'alloydbiamuser')
      AND r_role.rolname NOT LIKE 'rds\_%'
      AND r_role.rolname NOT LIKE 'awsdms\_%'
    GROUP BY r_role.rolname, r_member.rolname
  )
SELECT
  json_build_object(
    'roles',
    COALESCE(
      (SELECT json_agg(row_to_json(r)) FROM raw_roles AS r), '[]'::json),
    'memberships',
    COALESCE(
      (SELECT json_agg(row_to_json(m)) FROM raw_memberships AS m), '[]'::json))
    AS cluster_roles_manifest;
