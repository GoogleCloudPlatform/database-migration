-- Extracts database-level privileges (CREATE, CONNECT, TEMPORARY) and ownership
-- for the current database from pg_database.
-- Excludes cloud provider infrastructure and database engine system accounts.

WITH
  raw_db_acls AS (
    SELECT
      d.datname AS database_name,
      r_owner.rolname AS database_owner,
      CASE WHEN acl.grantee = 0 THEN 'PUBLIC' ELSE r_grantee.rolname END AS grantee,
      r_grantor.rolname AS grantor,
      acl.privilege_type,
      acl.is_grantable
    FROM pg_database AS d
    INNER JOIN pg_roles AS r_owner
      ON r_owner.oid = d.datdba
    CROSS JOIN LATERAL aclexplode(COALESCE(d.datacl, acldefault('d', d.datdba))) AS acl
    INNER JOIN pg_roles AS r_grantor
      ON r_grantor.oid = acl.grantor
    LEFT JOIN pg_roles AS r_grantee
      ON r_grantee.oid = acl.grantee
    WHERE
      d.datname = current_database()
      AND acl.grantee != d.datdba
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
FROM raw_db_acls AS a;
