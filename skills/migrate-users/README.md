<!-- disableFinding(LINE_OVER_80) -->

# Database Migration: Users & Permissions Skill

The `migrate-users` skill extracts, normalizes, translates, and migrates
database user accounts, role definitions, password hashes, role hierarchies, and
object-level permissions from a source PostgreSQL database into Google Cloud
target instances (**Cloud SQL for PostgreSQL** and **AlloyDB for PostgreSQL**).

--------------------------------------------------------------------------------

## Capabilities & Feature Coverage

*   **Global Roles & Role Memberships**: Extracts role attributes, login
    privileges, superuser flags, connection limits, and group inheritance trees.
*   **Object-Level DCL Migration**: Captures and translates permissions across
    14 database object categories:
    *   Databases, Schemas, Tables, Partitioned Tables, Views, Materialized
        Views, Sequences, Functions, Stored Procedures, Custom Types, Enums,
        Domains, Range Types, and Default ACLs (`ALTER DEFAULT PRIVILEGES`).
*   **Managed Platform Normalization**:
    *   Maps source superusers to managed destination administrator roles
        (`cloudsqlsuperuser` for Cloud SQL, `postgres` for AlloyDB).
*   **Credential Security & Password Handling**:
    *   Transfers portable `SCRAM-SHA-256` password hashes directly.
    *   Detects incompatible hashes (e.g. legacy MD5 on SCRAM-enforced targets)
        and generates actionable DBA Reset Manifests with copy-pasteable CLI
        commands (`gcloud sql users set-password`, `gcloud alloydb users
        set-password`).
    *   Enforces a zero-plaintext credential policy.
*   **Cloud IAM Database Authentication**:
    *   Supports migrating source users directly into Google Cloud IAM database
        roles (`cloudsqliamuser`, `alloydbiamuser`).
    *   Supports CLI connections using ephemeral OAuth tokens (`PGPASSWORD`).
*   **DMS Replication User Protection**:
    *   Discovers the destination replication user from DMS Destination
        Connection Profiles and guarantees it retains full administrative grants
        so CDC data replication is never blocked.
*   **Schema & Object Readiness Check**:
    *   Verifies that target database schemas, tables, and routines exist on the
        destination before applying object grants to prevent runtime
        relation-not-found errors.

--------------------------------------------------------------------------------

## Directory Structure

```
migrate-users/
├── SKILL.md                 # Master orchestrator & conversational state machine
├── README.md                # Skill overview, prerequisites, and operational guide
├── references/
│   └── users-permissions-postgresql/
│       ├── runbook.md       # PostgreSQL catalog mechanics, remediation & normalization rules
│       └── terraform/
│           ├── alloydb_users.tf   # AlloyDB built-in and IAM user Terraform resources
│           └── cloudsql_users.tf  # Cloud SQL built-in and IAM user Terraform resources
└── queries/
    └── postgresql/
        ├── roles_memberships.sql  # Global roles and group inheritance extraction
        ├── databases_dcl.sql      # Database-level grants (CONNECT, CREATE, TEMPORARY)
        ├── namespaces_dcl.sql     # Schema-level grants (USAGE, CREATE)
        ├── relations_dcl.sql      # Tables, views, matviews, sequences grants
        ├── routines_dcl.sql       # Functions & procedures with overloading signatures
        ├── types_dcl.sql          # Custom types, enums, domains grants
        └── default_acls.sql       # Default privileges (ALTER DEFAULT PRIVILEGES)
```

--------------------------------------------------------------------------------

## Operational Modes

### 1. Assessment & Planning (Dry-Run)

*   Scans source catalogs across all non-system databases to extract complete
    role hierarchies and object-level grants.
*   Prepares target-ready DCL statements by translating administrative
    privileges and normalizing managed platform rules.
*   Generates standalone, reviewable DCL alignment scripts (`global_roles.sql`,
    `<dbname>_permissions.sql`) for inspection without modifying the destination
    database.

### 2. End-to-End Migration

*   Extracts source catalogs and handles destination role collisions (`SKIP` by
    default).
*   Runs pre-flight schema and object readiness checks against the target
    database catalog.
*   Presents generated scripts for interactive review and approval.
*   Executes DCL in ordered batches (Roles -> Schemas -> Relations/Routines ->
    Default ACLs) and outputs a post-migration parity summary report.

--------------------------------------------------------------------------------

## Supported Connection Setups

The skill supports connecting to source and target databases through any of the
following client environments:

1.  **Direct CLI Client (`psql`)**:
    *   Connects directly using native CLI binaries.
    *   Enforces SSL encryption (`sslmode=require`).
2.  **Containerized Client (Docker)**:
    *   Uses an isolated container (e.g. `docker run --rm -i postgres:alpine
        psql ...`) when local database binaries are not installed on the host.
3.  **Remote Managed MCP Servers (`cloud-sql`, `alloydb`)**:
    *   Uses Google Cloud's remote Model Context Protocol (MCP) servers
        (`execute_sql`) authenticating via Google Application Default
        Credentials (ADC).
4.  **Local / Third-Party MCP Servers**:
    *   Supports custom or cloud provider MCP servers (e.g. AWS Postgres MCP
        server) configured in the agent's MCP settings.

--------------------------------------------------------------------------------

## Prerequisites & Credentials

### 1. Remote MCP Authentication (ADC)

When using remote MCP tools (`cloud-sql`, `alloydb`), ensure Application Default
Credentials are configured:

```bash
gcloud auth application-default login
```

*Note: If using MCP tools, ensure the database MCP server (e.g. `cloud-sql` or a
custom MCP server) is registered in your agent's MCP configuration.*

### 2. CLI / Docker Non-Interactive Credentials

When connecting via native CLI (`psql`) or Docker containers, export database
credentials in your shell environment before invoking the agent:

```bash
# Direct Password Connections
export SRC_DB_PASSWORD="<source_password>"
export DEST_DB_PASSWORD="<destination_password>"

# Google Cloud IAM OAuth Tokens (Cloud SQL / AlloyDB)
export DEST_DB_PASSWORD=$(gcloud auth print-access-token)

# AWS RDS IAM Database Auth Token (Source)
export SRC_DB_PASSWORD=$(aws rds generate-db-auth-token --hostname <HOST> --port 5432 --username <IAM_USER>)

# Azure Database for PostgreSQL Access Token (Source)
export SRC_DB_PASSWORD=$(az account get-access-token --resource-type oss-rdbms --query accessToken -o tsv)
```

### 3. Required Database Flags (Optional / Platform-Specific)

*   **Cloud SQL Source (Password Hash Extraction)**: Set
    `cloudsql.pg_authid_select_role=auth_viewer,cloudsql.pg_shadow_select_role=auth_viewer`
    and grant `auth_viewer` to the connecting user.
*   **Cloud IAM Database Authentication**: Set `cloudsql.iam_authentication =
    on` (Cloud SQL) or `alloydb.iam_authentication = on` (AlloyDB).

--------------------------------------------------------------------------------

## Example Prompts

*   *"Migrate all users, roles, and object grants from my PostgreSQL database to
    my Cloud SQL instance."*
*   *"Assess and generate the DCL scripts for my PostgreSQL database permissions
    without applying them."*
*   *"Export my PostgreSQL database users and convert designated application
    users to Cloud IAM database authentication on AlloyDB."*
