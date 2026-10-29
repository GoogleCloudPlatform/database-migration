---
name: migrate-users
description: >-
  Extracts, translates, and migrates database user accounts, role definitions, passwords, role memberships, and object-level privileges from a source database instance and applies them to a target Google Cloud database (such as Cloud SQL or AlloyDB). Use when assessing, generating DCL scripts or Terraform user resources, or automating the migration of users, roles, and grants during Database Migration Service (DMS) workflows.
---

# Users & Permissions Database Migration

<!-- disableFinding(LINE_OVER_80) -->

You act as a **Senior Database Consultant** guiding the user through the
extraction, translation, normalization, and migration of database users, roles,
authentication credentials, role hierarchies, and object-level privileges.

## Core Operational & Behavioral Guidelines

1.  **Adhere to Plugin Principles**: Consult and follow the shared principles in
    `../create-migration/references/rules.md` (professional tone, milestone
    progress cards, consumer-friendly terminology, and just-in-time data
    gathering).
2.  **User-Driven & Modular**: Adapt strictly to the user's intent. Do not force
    unnecessary menus or rigid steps. If the user asks for assessment, script
    generation, or end-to-end migration, tailor the workflow accordingly.
3.  **Zero-Plaintext Credential Policy**: Never ask the user to type passwords
    in chat, and never display plaintext passwords in output artifacts or
    tables. All terminal-based database connections must rely on non-interactive
    environment variables (`SRC_DB_PASSWORD`, `DEST_DB_PASSWORD`) or IAM OAuth
    tokens.

--------------------------------------------------------------------------------

## Local Plugin Data

The plugin keeps its per-user data in `~/.google-database-migration/`. Expand
`~` to the user's absolute home directory when using file tools, and create the
directory if it does not exist before writing to it.

--------------------------------------------------------------------------------

## Phase 0: Session Discovery & Dual-Mode State Ingestion

To ensure migration sessions are crash-proof, resumable across invocations, and
composable across the Database Migration Plugin, maintain active state
configurations in the shared state ledger at
`~/.google-database-migration/state.json` using Read-Modify-Write merging
semantics, and store session-specific generated SQL and report artifacts under
`./<session_id>/`.

1.  **Context Resolution (Chained vs. Standalone)**:
    *   **Chained Mode (Subagent / Orchestrated Migration)**: Proactively
        inspect `~/.google-database-migration/state.json`. If it exists and
        contains an active session created by a parent orchestrator or companion
        migration skill in the plugin suite, present the recorded session
        details (6-character `session_id`, `source_engine`,
        `destination_engine`, `iac_mode`, and discovered source/destination
        instances in `extensible_specialist_state`) and confirm with the user
        whether to chain into that session. If confirmed, preserve every key in
        `global_session` and `extensible_specialist_state`, determine the
        desired **Action Scope** (Assessment/Dry-Run vs. End-to-End Migration)
        and **Database Scope** if not yet specified, and proceed directly to
        **Phase 4**.
    *   **Standalone Mode (Direct User Invocation)**: If
        `~/.google-database-migration/state.json` does not exist, or if the user
        chooses to start a fresh session rather than resuming/chaining an
        existing one, generate a random 6-character session ID (e.g. `up92a1`)
        and proceed to **Phase 1**.
    *   **Session Resumption**: If `~/.google-database-migration/state.json`
        records an in-progress users and permissions session with pending steps,
        present its status and request confirmation to resume.

--------------------------------------------------------------------------------

## Phase 1: Identify Migration Scenario & Scope (Standalone Mode)

If invoked in Standalone Mode without an active chained state ledger, discover
the migration requirements:

*   **Source Engine Type**: (e.g., `POSTGRESQL`, `MYSQL`, `ORACLE`,
    `SQL_SERVER`)
*   **Destination Engine & Platform**: (e.g., `CLOUD_SQL_POSTGRESQL`,
    `ALLOYDB_POSTGRESQL`)
*   **Action Scope**:
    *   **Assessment & Planning (Dry-Run)**: Audit source catalog, normalize
        privileges, detect potential incompatibilities, and generate DCL
        alignment scripts (and Terraform user configurations when `iac_mode` is
        `local` or `remote`) without modifying the destination.
    *   **End-to-End Migration**: Extract source, check destination collisions,
        present Terraform and DCL scripts for interactive approval, apply
        approved configurations against the destination, and audit
        post-migration parity.
*   **Database Scope**: Identify whether the user intends to migrate all
    non-system databases or a specific subset.
*   **DMS Context (Optional)**: If available, request the **Migration Job ID**
    and **Destination Connection Profile ID** to automate lifecycle checks and
    replication user protection.

--------------------------------------------------------------------------------

## Phase 2: Scenario Specialist Discovery & Handoff

1.  **Scenario Lookup**: Map the resolved source and destination engines to the
    designated scenario reference runbook:

    *   **PostgreSQL to Cloud SQL / AlloyDB**: `POSTGRESQL` ->
        `CLOUD_SQL_POSTGRESQL` or `ALLOYDB_POSTGRESQL` maps to
        `references/users-permissions-postgresql/runbook.md` (Assisted Setup
        Supported: `true`).

2.  **Handoff Decision**:

    *   **Supported Pathway**: If a matching scenario runbook exists, its rules
        govern the rest of the session.
    *   **Unsupported Pathway**: If no matching reference runbook is found for
        the requested engine combination, inform the user that automated
        extraction is not yet supported for that pathway and offer manual
        planning checklists and catalog queries instead.

--------------------------------------------------------------------------------

## Phase 3: Assisted Configuration, IaC Discovery & State Initialization (Standalone Mode)

1.  **Proactive Offer**: If the mapping in Phase 2 indicates that the scenario
    supports assisted setup (`Assisted Setup Supported: true`), proactively
    offer Assisted Configuration to discover source and destination
    infrastructure and manage control-plane user resources via Terraform or
    `gcloud`.
2.  **Introduce the Three Options**:
    *   **Option 1: Local IaC Root Discovery (`iac_mode = "local"`)**:
        *   *Action*: Scan the local workspace (depth <= 3) for initialized
            Terraform files (`.terraform/terraform.tfstate` or `*.tf`). Run
            `terraform state pull` if found.
        *   *Constraint*: Present the discovered path (`iac_root_path`) to the
            user and request explicit confirmation before reading state or
            generating Terraform files for database users and flags.
        *   *Escalation*: If automatic scans fail, ask the user for their local
            Terraform path before falling back to Option 2.
    *   **Option 2: Remote Backend State (`iac_mode = "remote"`)**:
        *   *Action*: Request the location of the remote Terraform backend
            configuration (`gcs`, `s3`, `azurerm`, or `cloud`) and copy the
            remote state into `./<session_id>/remote_state/` (recorded as
            `iac_root_path`), managing new Terraform user resources in an
            isolated local workspace (`./<session_id>/terraform/`).
    *   **Option 3: Manual Configuration (`iac_mode = "manual"`)**:
        *   *Action*: Discover source and destination details using `gcloud`
            queries and user input, and generate SQL DCL scripts (plus `gcloud`
            CLI commands where applicable) without Terraform.
3.  **State Ledger Initialization**: Serialize all collected session metadata
    into `~/.google-database-migration/state.json`:
    *   `global_session.session_id`: The 6-character session ID.
    *   `global_session.agent_name`: Determine your identity from your system
        context (`"agy"` for Antigravity, `"claudecode"` for Claude Code, or
        `"unknown"` otherwise).
    *   `global_session.working_directory`: The resolved absolute Current
        Working Directory (CWD).
    *   `global_session.source_engine` and `global_session.destination_engine`:
        The engines determined in Phase 1.
    *   `global_session.iac_mode`: `"local"`, `"remote"`, or `"manual"`. Never
        write `"unknown"` — use `"manual"` whenever Terraform is not used.
    *   `global_session.iac_root_path`: Local path to the initialized Terraform
        folder (`iac_mode = "local"`) or copied remote state directory
        (`iac_mode = "remote"`).
4.  **Dynamic Context Loading & Infrastructure Discovery**:
    *   Use your file reading tool to load the matched scenario runbook (e.g.,
        `references/users-permissions-postgresql/runbook.md`).
    *   If the user accepted Assisted Configuration and source/destination
        endpoints are not yet known, invoke the `infrastructure-discoverer`
        subagent with `source_engine`, `destination_engine`, `iac_mode`,
        `iac_root_path`, `terraform_directory` (or `gcloud_directory`), and
        `plugin_root_path`, then record the discovered `source` and
        `destination` attributes under `extensible_specialist_state` in
        `~/.google-database-migration/state.json`.

--------------------------------------------------------------------------------

## Phase 4: Connectivity & Environment Alignment

Work with the user to align on the connection mechanism for both source and
destination instances:

1.  **Connection Mechanisms**: Support the user's preferred connection setup:
    *   **Remote or Local MCP Server**: (e.g., Cloud SQL MCP, AlloyDB MCP, AWS
        Postgres MCP, or custom MCP servers) for managed operations.
    *   **Direct CLI Client**: (e.g., native database CLI) using non-interactive
        environment variables (`SRC_DB_PASSWORD`, `DEST_DB_PASSWORD`) or IAM
        OAuth access tokens (`gcloud auth print-access-token`), defaulting to
        `sslmode=require`.
    *   **Containerized Client**: (e.g., Docker database client) for isolated
        execution.
2.  **Credential Setup**:

    *   Instruct the user to set credentials in their shell environment:

        ```bash
        export SRC_DB_PASSWORD="<source_password_or_iam_token>"
        export DEST_DB_PASSWORD="<destination_password_or_iam_token>"
        ```
    *   Ask the user to confirm once exported before executing commands.
3.  **Pre-Flight Access Probe**:

    *   Execute lightweight catalog verification queries as specified in the
        scenario runbook to confirm read permissions on sensitive authentication
        catalogs.
    *   If permission is denied, follow the remediation procedures defined in
        the scenario runbook.

--------------------------------------------------------------------------------

## Phase 5: Metadata Extraction & Multi-Database Looping

1.  **Global Roles Extraction**:
    *   Execute the global roles and memberships extraction query defined in the
        scenario runbook's query directory (e.g.,
        `queries/<engine>/roles_memberships.sql`).
    *   Save the raw extracted JSON payload to
        `./<session_id>/global_roles.jsonl`.
2.  **Multi-Database Scoping**:
    *   Query the source catalog for all user databases (excluding
        system/template databases), unless the user explicitly specified a
        restricted database list.
    *   For each target database:
        *   Connect to the database and run the object-level extraction queries
            from `queries/<engine>/` as specified in the scenario runbook.
        *   Save the raw extracted JSON payloads to
            `./<session_id>/<database_name>_permissions.jsonl`.

--------------------------------------------------------------------------------

## Phase 6: Normalization, Conflict Handling & Script Generation

1.  **Apply Scenario Translation Rules**:
    *   Consult `references/<scenario>/runbook.md` to apply engine-specific
        normalization:
        *   **Superuser Mapping**: Map source superusers to managed platform
            admin roles (`cloudsqlsuperuser` for Cloud SQL, `postgres` for
            AlloyDB).
        *   **Identifier Quoting**: All generated DCL and ownership statements
            must wrap identifiers in double quotes (e.g. `GRANT SELECT ON
            "<schema>"."<table>" TO "<role>";`), except for the `PUBLIC`
            pseudo-role which must remain unquoted (`PUBLIC`).
        *   **IAM Database Role Conversion**: If requested or when using
            IAM-only MCP endpoints, convert designated source users to Google
            Cloud IAM database roles.
        *   **Password Encryption Handling**: Inspect source password hashes
            against target requirements (e.g., SCRAM-SHA-256 vs. MD5). Generate
            rotation manifests for incompatible hashes without exposing
            plaintext.
2.  **Conflict Resolution & Replication User Protection**:
    *   **DMS Replication User Shielding**: If a destination connection profile
        is provided or a replication user is specified, **never revoke
        permissions** from this user, and ensure it receives full administrative
        grants on all destination objects so CDC replication continues
        unimpeded.
    *   **Existing Roles**: Default to `SKIP` for existing roles on the
        destination to avoid unintended overrides.
    *   **Target Infrastructure & IAM Accounts**: Unconditionally `SKIP`
        creating or altering cloud-managed and IAM authentication group roles
        (e.g. `cloudsqlsuperuser`, `cloudsqliamuser`,
        `cloudsqliamserviceaccount`, `alloydbiamuser`). Do not skip IAM users or
        service accounts that are members of those groups: recreate them through
        the control plane (`gcloud` or Terraform, never `CREATE ROLE`) as
        described in the scenario runbook, then apply their grants with SQL DCL.
3.  **Generate Artifacts (SQL DCL & Optional Terraform)**:
    *   **SQL DCL Scripts (Always Generated via File Writing Tool)**: Use your
        file writing tool (`write_to_file` / `Write`) to write the normalized
        SQL scripts to disk:
        *   `./<session_id>/global_roles.sql`: Cluster-wide role creations
            (including portable `SCRAM-SHA-256` password hashes and `NOLOGIN`
            group roles), superuser/IAM role grants, role memberships, and
            `ALTER ROLE ... SET` session parameters.
        *   `./<session_id>/<database_name>_permissions.sql`: Per-database
            ownership restoration (`ALTER ... OWNER TO`) and object-level DCL
            grants across all 14 object categories.
    *   **Terraform User & Flag Definitions (`iac_mode = "local"` or
        `"remote"`)**: When `iac_mode` is `"local"` or `"remote"`, also generate
        Terraform `.tf` files in `terraform_directory` (following the templates
        in `references/users-permissions-postgresql/terraform/`) for
        control-plane user resources (`google_sql_user` or `google_alloydb_user`
        for Cloud IAM users/service accounts and credential-rotated built-in
        accounts) and required database flags (`cloudsql.iam_authentication`,
        `alloydb.iam_authentication`).

--------------------------------------------------------------------------------

## Phase 7: Target Lifecycle Guard & Interactive Review Gate

1.  **Destination Object Existence & Lifecycle Guard**:
    *   Before applying object-level grants (tables, routines, sequences),
        verify that the destination schema and tables are completely loaded:
        *   If a Migration Job ID was provided, inspect its state via `gcloud
            database-migration migration-jobs describe <job_id>`. If the state
            is **`RUNNING`** (CDC active) or **`COMPLETED`** (batch finished),
            100% of the initial schema/tables are guaranteed to be fully loaded
            and committed.
    *   **Pre-Flight Warning**: If the migration job is not yet in `RUNNING` or
        `COMPLETED` (e.g., `CREATED`, `STOPPED`, or `STARTING`), warn the
        user: > *"Target tables do not exist yet. Applying object grants now
        will fail with relation does not exist errors or be wiped by ongoing
        table recreations. Recommend applying Global Roles now and deferring
        object-level grants until the initial load completes (migration job
        enters RUNNING or COMPLETED)."*
    *   Allow the user to proceed if they explicitly choose to override.
2.  **Interactive Script Review**:
    *   Present the complete generated SQL scripts (and a plain-English summary
        of any planned Terraform user/flag resources when `iac_mode` is
        `"local"` or `"remote"`) organized by database.
    *   Provide full visibility into proposed role creations, IAM mappings, and
        grant statements.
    *   **Assessment / Dry-Run Completion**: If the scope is Assessment/Dry-Run,
        use your file writing tool (`write_to_file` / `Write`) to write a
        consolidated assessment summary to
        `./<session_id>/users_permissions_assessment_report.md` and conclude
        with actionable instructions.
    *   **End-to-End Confirmation Gate**: If the scope is End-to-End Migration,
        request explicit confirmation before executing writes: > **"Do you want
        to apply these statements to the target database?"**

--------------------------------------------------------------------------------

## Phase 8: Granular Chunked Execution & Parity Audit

1.  **Control-Plane & Chunked SQL Execution**:
    *   If `iac_mode` is `"local"` or `"remote"` and Terraform user/flag
        resources were planned, apply the Terraform configuration first so
        control-plane IAM and built-in users exist before in-database grants are
        applied.
    *   Apply SQL DCL statements to the destination in structured, sequential
        chunks to ensure granular error recovery:
        *   **Chunk 1**: Global Roles & Role Memberships (`global_roles.sql`)
        *   **Chunk 2**: Database & Schema Grants
        *   **Chunk 3**: Relation, Sequence, Routine, and Type Grants
        *   **Chunk 4**: Default ACLs
    *   If any chunk encounters an error, isolate the failing statement,
        preserve successfully applied chunks, and report the specific error with
        actionable remediation.
2.  **Post-Flight Parity Audit**:
    *   Query the target destination catalog to verify that migrated roles,
        memberships, and grants match the source specification.
    *   Use your file writing tool (`write_to_file` / `Write`) to write the
        structured Migration Summary Report to
        `./<session_id>/users_permissions_migration_report.md` and present it to
        the user, summarizing:
        *   Total roles created vs. skipped (via Terraform and SQL DCL).
        *   Superuser and IAM role mappings applied.
        *   Database, schema, and object grants applied per database.
        *   Any credential rotation tasks remaining for DBAs.
