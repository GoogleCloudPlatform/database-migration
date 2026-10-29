<!-- disableFinding(LINE_OVER_80) -->

# PostgreSQL Homogeneous Users & Permissions Runbook

This runbook serves as the definitive technical reference for migrating database
users, roles, password hashes, role hierarchies, and object-level permissions
from PostgreSQL sources to Google Cloud destinations (Cloud SQL for PostgreSQL
and AlloyDB for PostgreSQL).

--------------------------------------------------------------------------------

## 1. Scenario Definition & Default Port

*   **Supported Migration Pathways**:
    *   `POSTGRESQL` -> `CLOUD_SQL_POSTGRESQL`
    *   `POSTGRESQL` -> `ALLOYDB_POSTGRESQL`
*   **Default Database Port**: `5432` (default listening port on the database
    server host for both source and target unless explicitly overridden).
*   **Connection Security**: All CLI connections must enforce `sslmode=require`
    by default.

--------------------------------------------------------------------------------

## 2. Extraction Suite Order & Manifest

To avoid prompt context bloat and syntax corruption, extraction queries **must
be executed directly from their standalone template files** located in
`queries/postgresql/` (e.g. using `psql -t -A -f ...` to stream raw JSON Lines /
NDJSON directly to local session files, or passing the query file content into
the remote MCP `execute_sql` tool).

```
queries/postgresql/
├── roles_memberships.sql   # [Global Pass] Cluster-wide roles from pg_roles & group inheritance
├── databases_dcl.sql       # [Per-Database Pass] Database-level permissions (CONNECT, CREATE, TEMPORARY)
├── namespaces_dcl.sql      # [Per-Database Pass] Schema-level permissions (USAGE, CREATE)
├── relations_dcl.sql       # [Per-Database Pass] Tables, partitioned tables, views, matviews, sequences
├── routines_dcl.sql        # [Per-Database Pass] Functions and stored procedures with overloading signatures
├── types_dcl.sql           # [Per-Database Pass] Custom composite, enum, domain, and range types
└── default_acls.sql        # [Per-Database Pass] Default privileges configured via ALTER DEFAULT PRIVILEGES
```

### Execution Protocol

1.  **Step 1 (Global Cluster Pass - Run Once)**:

    *   Connect to the default database (e.g., `postgres`) on the source
        instance.
    *   Execute `queries/postgresql/roles_memberships.sql` to capture all global
        roles and group memberships across the entire cluster.
    *   Save output to `./<session_id>/global_roles.jsonl`.

2.  **Step 2 (Discover User Databases)**:

    *   Query `pg_database` to discover all non-system databases:

        ```sql
        SELECT datname FROM pg_database
        WHERE datistemplate = false
          AND datname NOT IN ('cloudsqladmin', 'rdsadmin', 'azure_maintenance');
        ```

3.  **Step 3 (Per-Database Loop - Run Iteratively)**:

    *   For each discovered user database (or the user-specified subset),
        establish a connection to that database and execute the remaining 6
        extraction scripts in sequence:
        1.  `databases_dcl.sql`
        2.  `namespaces_dcl.sql`
        3.  `relations_dcl.sql`
        4.  `routines_dcl.sql`
        5.  `types_dcl.sql`
        6.  `default_acls.sql`
    *   Stream output records directly to
        `./<session_id>/<database_name>_permissions.jsonl`.

--------------------------------------------------------------------------------

## 3. Pre-Flight Catalog Access & Role Extraction

### Step 1: Pre-Flight Probe

Run the pre-flight check query on the source database:

```sql
SELECT 1 FROM pg_authid LIMIT 1;
```

### Step 2: Extraction Execution

1.  **Extract Roles & Hierarchies**: Execute
    `queries/postgresql/roles_memberships.sql` against the source database.
2.  **Extract Passwords (If Probe Succeeded)**:

    *   Execute:

        ```sql
        SELECT rolname, rolpassword FROM pg_authid;
        ```
    *   Enrich the extracted user objects in memory with their corresponding
        password hashes (`rolpassword`).
3.  **If Probe Failed (`ERROR: permission denied for table pg_authid`)**:

    *   Proceed with `rolpassword = NULL`.
    *   Route login accounts into **Credential Rotation** (temporary passwords +
        reset CLI commands) or **Cloud IAM User Conversion** in Phase 5.

### Step 3: Cloud SQL Source Remediation (Optional)

If the user wants to enable password extraction on a **Cloud SQL for PostgreSQL
source instance**:

1.  Role names starting with `pg_` are reserved in PostgreSQL 15+ (`CREATE ROLE
    pg_...` fails). Use non-prefixed role name `auth_viewer`.
2.  Set database flags:

    ```bash
    gcloud sql instances patch <INSTANCE> \
        --project=<PROJECT_ID> \
        --database-flags=cloudsql.pg_authid_select_role=auth_viewer,cloudsql.pg_shadow_select_role=auth_viewer
    ```
3.  Create and grant the viewer role:

    ```sql
    CREATE ROLE auth_viewer WITH NOLOGIN;
    GRANT auth_viewer TO <connecting_user>;
    ```

--------------------------------------------------------------------------------

## 4. Role Normalization & Superuser Mapping

Managed database platforms enforce restricted administrative models where
customers do not have OS-level superuser access.

### System & Infrastructure Role Filtering

Exclude all system and cloud-managed roles from extraction and translation:

*   **System Users**: `postgres`, `cloudsqladmin`, `cloudsqlsuperuser`,
    `alloydbadmin`, `rdsadmin`, `azure_pg_admin`, `azure_superuser`, `azuresu`,
    `PUBLIC`.
*   **Role Prefixes**: `pg_%`, `cloudsql%`, `alloydb%`, `rds_%`, `awsdms_%`,
    `azure_%`.

### Superuser Privilege Translation

Managed databases disallow true PostgreSQL `SUPERUSER` (`rolsuper = true`).

*   **Cloud SQL Destination**:
    *   Set `NOSUPERUSER` in the role creation statement.
    *   Map administrative privileges: `GRANT cloudsqlsuperuser TO
        "<role_name>";`
*   **AlloyDB Destination**:
    *   Set `NOSUPERUSER` in the role creation statement.
    *   Map administrative privileges: `GRANT postgres TO "<role_name>";`

### Role Configuration Parameters (`rolconfig`)

When roles have custom session parameters configured (e.g., `search_path`,
`statement_timeout`), `roles_memberships.sql` extracts them from
`pg_roles.rolconfig`.

*   **Translation Rule**: For each parameter in `rolconfig`, emit:

    ```sql
    ALTER ROLE "<role_name>" SET <parameter_name> = <parameter_value>;
    ```

### Identifier Quoting & Keyword Protection

All downstream DCL and ownership statements must wrap object and role
identifiers in standard SQL double quotes (`"<identifier>"`), with one critical
exception:

*   **Identifiers**: Wrap database, schema, table, sequence, routine, type, and
    role names in double quotes (e.g. `GRANT SELECT ON "<schema>"."<table>" TO
    "<role>";`). This prevents parse errors on mixed-case names (`"AppUser"`),
    hyphens (`"app-user"`), or SQL reserved keywords (`"order"`, `"user"`,
    `"group"`).
*   **The `PUBLIC` Pseudo-Role Exception**: When formatting `GRANT` or `REVOKE`
    statements where the grantee is `PUBLIC`, you **must not** enclose `PUBLIC`
    in quotes. `"PUBLIC"` is treated as a non-existent literal user; `PUBLIC` is
    the required PostgreSQL keyword.

--------------------------------------------------------------------------------

## 5. Password Encryption & Credential Rotation

Password hash portability depends on the destination instance's
`password_encryption` configuration (which defaults to `scram-sha-256` on Cloud
SQL for PostgreSQL 14+ and AlloyDB, and `md5` on Cloud SQL for PostgreSQL
9.6–13).

### Hash Inspection Rules

1.  **Source Hash is `SCRAM-SHA-256$...`**:

    *   Directly portable to any SCRAM-compatible destination (Cloud SQL 10+ and
        AlloyDB).
    *   Generate: `CREATE ROLE "<name>" WITH LOGIN ENCRYPTED PASSWORD
        'SCRAM-SHA-256$...';`

2.  **Source Hash is `md5...` (or NULL)**:

    *   **Target with `password_encryption = md5` (e.g. Cloud SQL 9.6–13)**: The
        MD5 hash is directly portable (`CREATE ROLE "<name>" WITH LOGIN
        ENCRYPTED PASSWORD 'md5...';`).
    *   **Target with `password_encryption = scram-sha-256` (e.g. Cloud SQL 14+
        or AlloyDB)**: MD5 hashes cannot authenticate against SCRAM-enforced
        engines. The agent presents two options:
        *   **Option 1 (Cloud IAM Conversion - Recommended)**: Convert the
            account to a Google Cloud IAM database user (`cloudsqliamuser` or
            `alloydbiamuser`).
        *   **Option 2 (Credential Rotation)**: Create the role with a random
            temporary password and output the DBA Reset Manifest (`gcloud sql
            users set-password` or `gcloud alloydb users set-password`).

### Zero-Plaintext Policy & DBA Reset Manifest

*   **Strict Security Rule**: Never display temporary or generated plaintext
    passwords in chat messages, markdown tables, or output artifacts.
*   **Actionable DBA Reset Manifest**: Present affected accounts alongside
    copy-pasteable CLI commands:

    *   **Cloud SQL for PostgreSQL**:

        ```bash
        gcloud sql users set-password <USERNAME> \
            --instance=<INSTANCE_ID> \
            --project=<PROJECT_ID> \
            --prompt-for-password
        ```
    *   **AlloyDB for PostgreSQL**:

        ```bash
        gcloud alloydb users set-password <USERNAME> \
            --cluster=<CLUSTER_ID> \
            --region=<REGION> \
            --project=<PROJECT_ID> \
            --prompt-for-password
        ```
    *   **Native SQL Alternative**:

        ```sql
        ALTER ROLE "<username>" WITH PASSWORD '<new_secure_password>';
        ```

--------------------------------------------------------------------------------

## 6. Multi-Cloud IAM Database User Authentication

### Converting Source Users to Google Cloud IAM Roles

IAM database users must be created through the Cloud SQL or AlloyDB control
plane (`gcloud`, Terraform, or the Admin API), never with `CREATE ROLE`. The
control plane creates the PostgreSQL role and grants the IAM group role
(`cloudsqliamuser`, `cloudsqliamserviceaccount`, or `alloydbiamuser`)
automatically. A new IAM user has no database privileges, so apply its ownership
and object-level grants with SQL DCL afterwards.

1.  **Cloud SQL for PostgreSQL**:

    *   Requires database flag `cloudsql.iam_authentication = on`.
    *   IAM user:

        ```bash
        gcloud sql users create "user@example.com" \
            --instance=<INSTANCE_NAME> --project=<PROJECT_ID> \
            --type=cloud_iam_user
        ```
    *   Service account: use `--type=cloud_iam_service_account` and the email
        without the `.gserviceaccount.com` suffix (`sa-name@project-id.iam`).
    *   Terraform: `google_sql_user` with `type = "CLOUD_IAM_USER"` or
        `"CLOUD_IAM_SERVICE_ACCOUNT"` (see
        `references/users-permissions-postgresql/terraform/cloudsql_users.tf`).

2.  **AlloyDB for PostgreSQL**:

    *   Requires database flag `alloydb.iam_authentication = on`.
    *   IAM user or service account (service accounts also omit the
        `.gserviceaccount.com` suffix):

        ```bash
        gcloud alloydb users create "user@example.com" \
            --cluster=<CLUSTER_ID> --region=<REGION> --project=<PROJECT_ID> \
            --type=IAM_BASED
        ```
    *   Terraform: `google_alloydb_user` with `user_type = "ALLOYDB_IAM_USER"`
        (see
        `references/users-permissions-postgresql/terraform/alloydb_users.tf`).
    *   *AlloyDB MCP Limitation*: As documented in the
        [AlloyDB MCP User Guide](https://docs.cloud.google.com/alloydb/docs/ai/use-alloydb-mcp#limitations),
        the AlloyDB MCP server authenticates exclusively via IAM OAuth
        credentials.

### Terraform User & Flag Provisioning (`iac_mode = "local"` or `"remote"`)

When `iac_mode` is `"local"` or `"remote"`, provision control-plane database
users and IAM authentication flags using the Terraform reference templates in
`references/users-permissions-postgresql/terraform/`:

*   **Cloud SQL for PostgreSQL**: Refer to
    `references/users-permissions-postgresql/terraform/cloudsql_users.tf` to
    provision `google_sql_user` resources (`type = "CLOUD_IAM_USER"`, `type =
    "CLOUD_IAM_SERVICE_ACCOUNT"`, and `type = "BUILT_IN"` for rotated accounts)
    and set `cloudsql.iam_authentication = "on"` on the target
    `google_sql_database_instance`. Note that `CLOUD_IAM_SERVICE_ACCOUNT`
    requires stripping the `.gserviceaccount.com` suffix via `trimsuffix()`.
*   **AlloyDB for PostgreSQL**: Refer to
    `references/users-permissions-postgresql/terraform/alloydb_users.tf` to
    provision `google_alloydb_user` resources (`user_type = "ALLOYDB_IAM_USER"`
    and `user_type = "ALLOYDB_BUILT_IN"`, including `database_roles` such as
    `["alloydbiamuser"]` or `["alloydbsuperuser"]`) and set
    `alloydb.iam_authentication = "on"` on the target `google_alloydb_instance`.
*   **Why SQL DCL (`global_roles.sql` & `<database_name>_permissions.sql`) is
    still required alongside Terraform**: Google Cloud Terraform resources
    manage only instance-level login identities and cannot replay pre-hashed
    `SCRAM-SHA-256$...` verifiers without plaintext passwords, create `NOLOGIN`
    group roles, configure `ALTER ROLE ... SET` session parameters, restore
    object ownership (`ALTER ... OWNER TO`), or grant object-level privileges
    across the 14 PostgreSQL catalog categories. Always generate and apply the
    SQL DCL scripts after `terraform apply` creates the control-plane users.

### Source IAM Identity Mapping & Translation

When extracting roles from a Cloud SQL source instance, `roles_memberships.sql`
preserves memberships in Google Cloud IAM authentication groups
(`cloudsqliamuser`, `cloudsqliamserviceaccount`, `alloydbiamuser`). When an
extracted account belongs to one of these groups (or has `rolpassword = NULL`
and an IAM email/service account naming convention):

*   **Do Not Prompt for Password Rotation**: Recognize the account as an
    existing IAM-authenticated identity.
*   **Do Not Replay the Account with SQL**: Skip `CREATE ROLE` for the account
    and skip `GRANT cloudsqliamuser` / `GRANT cloudsqliamserviceaccount` /
    `GRANT alloydbiamuser`. Instead, recreate the account on the target through
    the control plane as described in **Converting Source Users to Google Cloud
    IAM Roles** (`gcloud` when `iac_mode = "manual"`, Terraform when `"local"`
    or `"remote"`):
    *   **Cloud SQL -> Cloud SQL Target**: `cloudsqliamuser` members use
        `--type=cloud_iam_user`; `cloudsqliamserviceaccount` members use
        `--type=cloud_iam_service_account`.
    *   **Cloud SQL -> AlloyDB Target**: Both map to `gcloud alloydb users
        create --type=IAM_BASED` (`user_type = "ALLOYDB_IAM_USER"`).
*   **Then Apply SQL DCL**: After the control plane creates the account, apply
    its remaining role memberships, ownership restoration, and object-level
    grants from `global_roles.sql` and `<database_name>_permissions.sql`.

### CLI IAM Token Authentication across Cloud Providers

When connecting to source or destination databases via CLI (`psql`), instruct
the user to set the ephemeral IAM token in `PGPASSWORD` with `sslmode=require`:

*   **Google Cloud (Cloud SQL & AlloyDB)**:

    ```bash
    export PGPASSWORD=$(gcloud auth print-access-token)
    ```
*   **AWS RDS / Aurora**:

    ```bash
    export PGPASSWORD=$(aws rds generate-db-auth-token --hostname <HOST> --port 5432 --username <IAM_USER>)
    ```
*   **Azure Database for PostgreSQL**:

    ```bash
    export PGPASSWORD=$(az account get-access-token --resource-type oss-rdbms --query accessToken -o tsv)
    ```

--------------------------------------------------------------------------------

## 7. Destination DMS Replication User Protection & Ownership Restoration

During DMS migrations, the destination instance uses a dedicated replication
user (configured in the DMS Destination Connection Profile) to apply CDC data
streams.

### Replication User Protection Rules

1.  **Identification**: Discover the replication user name from the Destination
    Connection Profile ID (e.g. via `gcloud database-migration
    connection-profiles describe <CP_ID>`).
2.  **Never Revoke**: The agent must never generate `REVOKE` statements against
    this user.
3.  **Administrative Grant Manifest**: Ensure the generated DCL script includes
    explicit administrative grants on all destination objects:
    *   `GRANT USAGE, CREATE ON SCHEMA "<schema_name>" TO
        "<dms_replication_user>";`
        *   *Purpose*: Grants schema-level visibility and table creation rights
            needed for DDL synchronization.
    *   `GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA "<schema_name>" TO
        "<dms_replication_user>";`
        *   *Purpose*: Grants write permissions (`INSERT`, `UPDATE`, `DELETE`,
            `TRUNCATE`) required to apply replicated CDC row changes.
    *   `GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA "<schema_name>" TO
        "<dms_replication_user>";`
        *   *Purpose*: Grants sequence manipulation rights (`USAGE`, `SELECT`,
            `UPDATE`) to synchronize identity and auto-increment values.
    *   `GRANT ALL PRIVILEGES ON ALL ROUTINES IN SCHEMA "<schema_name>" TO
        "<dms_replication_user>";`
        *   *Purpose*: Grants execution rights (`EXECUTE`) in case replicated
            tables trigger function executions or generated columns during data
            writes.

### DMS Replication User Future Objects

Ensure newly created tables and sequences created during ongoing CDC replication
automatically inherit replication privileges:

```sql
ALTER DEFAULT PRIVILEGES IN SCHEMA "<schema_name>"
    GRANT ALL ON TABLES TO "<dms_replication_user>";
ALTER DEFAULT PRIVILEGES IN SCHEMA "<schema_name>"
    GRANT ALL ON SEQUENCES TO "<dms_replication_user>";
```

### Object Ownership Restoration

*   **Object Ownership Restoration**: Because the DMS replication user creates
    the target schema, it initially owns all replicated objects. Before
    executing `GRANT` statements, generate `ALTER <OBJECT_TYPE> "<name>" OWNER
    TO "<owner>";` statements using the `_owner` attributes extracted from the
    source (e.g., `schema_owner`, `relation_owner`, `routine_owner`,
    `type_owner`). This guarantees original owner roles retain native DDL
    privileges (such as `ALTER TABLE`, `CREATE TRIGGER`, or `DROP`).
    *   *Execution Requirement*: Ownership reassignment statements must be
        executed by an authorized identity—either the **Destination Connection
        Profile user**, **`postgres`** (AlloyDB), or a role with
        **`cloudsqlsuperuser`** (Cloud SQL)—otherwise PostgreSQL will reject
        them with `ERROR: must be owner of relation`.

--------------------------------------------------------------------------------

## 8. Transactional DCL Dry-Run (`BEGIN; ... ROLLBACK;`)

PostgreSQL uniquely supports fully transactional DDL and DCL.

### Dry-Run Validation Protocol

1.  **Pre-Flight Test Transaction**: Before executing writes permanently on the
    target database, wrap all generated DCL statements inside a rollback
    transaction block:

    ```sql
    BEGIN;
    -- [All generated CREATE ROLE, GRANT, ALTER DEFAULT PRIVILEGES statements]
    ROLLBACK;
    ```

2.  **Error Isolation & Clean Rollback**:

    *   **If Dry-Run Passes (`0` errors)**: Confirms that 100% of the DCL
        statements are syntactically valid and that all target objects exist,
        leaving no permanent modifications on the target. The agent proceeds to
        ask for user application approval.
    *   **If Dry-Run Fails (`ERROR: ...`)**: The transaction rolls back
        completely with zero target side-effects. The agent isolates the failing
        statement and presents the error to the user (e.g., target tables not
        yet loaded or missing parent role).

--------------------------------------------------------------------------------

## 9. 14-Object Coverage & Catalog Specification Matrix

Object Category              | Catalog Source                  | Extraction Template     | Privilege Types Extracted                                                   | Notes
:--------------------------- | :------------------------------ | :---------------------- | :-------------------------------------------------------------------------- | :----
**1. Global Roles & Users**  | `pg_roles`, `pg_authid`         | `roles_memberships.sql` | Login, Superuser, Replication, BypassRLS                                    | Excludes system/cloud prefixes.
**2. Role Memberships**      | `pg_auth_members`               | `roles_memberships.sql` | `ADMIN OPTION`, Role Inheritance                                            | Reconstructs full role hierarchies.
**3. Databases**             | `pg_database.datacl`            | `databases_dcl.sql`     | `CONNECT`, `CREATE`, `TEMPORARY`                                            | Uses literal database identifiers in DCL.
**4. Schemas / Namespaces**  | `pg_namespace.nspacl`           | `namespaces_dcl.sql`    | `USAGE`, `CREATE`                                                           | Handles `PUBLIC` schema grants.
**5. Tables**                | `pg_class.relacl` (`'r'`)       | `relations_dcl.sql`     | `SELECT`, `INSERT`, `UPDATE`, `DELETE`, `TRUNCATE`, `REFERENCES`, `TRIGGER` | Unrolled via `aclexplode()`.
**6. Partitioned Tables**    | `pg_class.relacl` (`'p'`)       | `relations_dcl.sql`     | Table privileges                                                            | Handled identically to base tables.
**7. Views**                 | `pg_class.relacl` (`'v'`)       | `relations_dcl.sql`     | `SELECT`, `INSERT`, `UPDATE`, `DELETE`                                      | Excludes internal catalog views.
**8. Materialized Views**    | `pg_class.relacl` (`'m'`)       | `relations_dcl.sql`     | `SELECT`                                                                    | Captured via `pg_class` (missed by `information_schema`).
**9. Sequences**             | `pg_class.relacl` (`'S'`)       | `relations_dcl.sql`     | `USAGE`, `SELECT`, `UPDATE`                                                 | Captures sequence permissions for identity columns.
**10. Functions**            | `pg_proc.proacl` (`'f'`)        | `routines_dcl.sql`      | `EXECUTE`                                                                   | Overloading resolved via `pg_get_function_identity_arguments()`.
**11. Procedures**           | `pg_proc.proacl` (`'p'`)        | `routines_dcl.sql`      | `EXECUTE`                                                                   | Handled identically to functions.
**12. Custom Types & Enums** | `pg_type.typacl` (`'c'`, `'e'`) | `types_dcl.sql`         | `USAGE`                                                                     | Excludes automatic array companion types (`_...`).
**13. Domains & Ranges**     | `pg_type.typacl` (`'d'`, `'r'`) | `types_dcl.sql`         | `USAGE`                                                                     | Captured from `pg_type`.
**14. Default Privileges**   | `pg_default_acl`                | `default_acls.sql`      | Default grants on Tables, Sequences, Functions, Types                       | Formats `ALTER DEFAULT PRIVILEGES` rules for future objects.

### Coverage Boundaries & Known Limitations

*   **Column-Level Grants (`pg_attribute.attacl`)**: Object-level extraction
    captures whole-relation grants. Column-specific permissions (e.g. `GRANT
    SELECT (col1, col2) ON table`) are out of scope for bulk relation DCL
    extraction.
*   **Default Privileges Negative Revocations**: `pg_default_acl` records
    explicit additive default grants; baseline system revocations from `PUBLIC`
    are governed by PostgreSQL engine catalog defaults.
