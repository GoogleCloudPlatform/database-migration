# Scenario: PostgreSQL Homogeneous Migration

This scenario focuses on migrating PostgreSQL databases into Cloud SQL for
PostgreSQL or AlloyDB for PostgreSQL.

DMS supports two flavors of homogeneous PostgreSQL migrations - an older one
that leverages the `pglogical` extension, and a newer one that leverages native
logical replication, also known as PostgreSQL Quickstart migrations. These are
different migration types and require different configurations. This runbook is
intended for PostgreSQL Quickstart migrations specifically, and not
`pglogical`-based migrations. To troubleshoot migration verification errors, or
handle user requests that are not part of this runbook, consult public
documentation for PostgreSQL Quickstart migrations. Use your URL reading tools
to read the relevant documentation links:

-   [PostgreSQL to Cloud SQL for PostgreSQL](https://docs.cloud.google.com/database-migration/docs/postgres/quick-start-migrations-guide)
-   [PostgreSQL to AlloyDB for PostgreSQL](https://docs.cloud.google.com/database-migration/docs/postgresql-to-alloydb/quick-start-migrations-guide)

Never suggest configuration steps that are applicable to `pglogical`-based
migrations.

--------------------------------------------------------------------------------

## Migration Configuration Steps

### 1. Tool Discovery & System Verification

Ensure the workspace has the required binaries and access capabilities for
PostgreSQL migrations:

1.  **GCP Management**:
    *   Check if `gcloud` is installed and authenticated.
    *   Check if `terraform` is installed.
    *   *Stop Constraint*: If neither of these is available, stop and provide
        clear installation instructions.
    *   *Terraform Primacy*: If both are available, explain clearly to the user
        that you will use Terraform by default to set up all GCP resources.
2.  **Database Access**:
    *   Check if `psql` is installed.
    *   Check if any MCP servers are available that allow you to communicate
        with the PostgreSQL source database.
    *   Check if the "MCP Toolbox for Databases" is available to communicate
        with Cloud SQL for PostgreSQL or AlloyDB for PostgreSQL.
    *   If `gcloud` is installed, consider using the `gcloud sql instances
        execute-sql` command to execute SQL against Cloud SQL instances with
        Data API access enabled (`ALLOW_DATA_API`).
    *   *Alignment Check*: Provide the list of tools available to you that would
        allow you to reach the source and destination database instances if
        there is a need. Warn the user that you may have to ask them to execute
        SQL commands on your behalf if the source or destination database
        instance is not accessible from the local environment.
3.  **Configuration Proceed/Confirmation**:
    *   Present the consolidated report of discovered tools to the user.
    *   Explicitly verify and ask if the user wants to proceed with the
        currently available toolsets, or if they prefer to stop and install more
        tools to get better troubleshooting support.

### 2. Identify Source And Destination

Invoke the `infrastructure-discoverer` subagent to analyze the user's
infrastructure and identify the migration source and destination details.

*   **Action**: Pass the following context variables to the subagent in its
    prompt:
    *   `source_engine`
    *   `destination_engine`
    *   `iac_mode`
    *   `iac_root_path`
    *   `terraform_directory` or `gcloud_directory`
    *   `plugin_root_path` (the absolute path to this plugin's directory)
*   **Action**: Wait for the subagent to return the structured JSON payload.
*   **Action**: Once the subagent returns the JSON output, parse it and record
    the discovered values to the state file immediately:
    *   Write to `extensible_specialist_state.destination_project`
    *   Write to `extensible_specialist_state.destination_region`
    *   Write to `extensible_specialist_state.destination_cloud_sql_id` or
        `destination_alloydb_cluster_id`
    *   Write to `extensible_specialist_state.source_project`
    *   Write to `extensible_specialist_state.source_vpc`
    *   Write to `extensible_specialist_state.source_network_attachment_uri`
    *   Write to `extensible_specialist_state.source_host`
    *   Write to `extensible_specialist_state.source_port`
    *   Write to `extensible_specialist_state.source_user`

### 3. Prepare Migration Plan and Confirm It with the User

Create a complete plan that sets up all needed resources and present it to the
user for confirmation before executing any resource creation steps. The steps
below describe how to build a migration plan step-by-step:

*   If using Terraform, the plan maps to a set of Terraform files created in
    `terraform_directory`. Ensure a single `required_providers` block in
    `terraform_directory` specifies `hashicorp/google` `>= 7.37.0` (or a higher
    minimum if required by a referenced connectivity template).
*   If using gcloud, the plan maps to a gcloud script created in
    `gcloud_directory`.
*   Write of the Terraform `.tf` files or `gcloud` shell script files to disk
    MUST happen immediately and silently. This ensures the workspace is prepared
    historically.
*   **Natural Language Plan Presentation Constraint**: You MUST never display
    raw Terraform code, file diffs, or shell scripts to the user as the plan for
    them to review. Instead, compile and print a highly readable plan using
    plain, natural English. List every single resource you are about to create
    or update, along with:
    *   **Resource Details**:
        *   Resource Type / Name (e.g., Private Service Connect Connection).
        *   Purpose of the resource (e.g., establishing a private VPC tunnel to
            the source database).
        *   Its naming pattern ending with the consistent 6-character session
            suffix.
    *   **Configured Parameters & Resource Targeting**:
        *   List all configuration details important to the end user.
        *   Make it exceptionally clear which existing or newly planned GCP
            resources the new resource targets. For example, clearly identify
            which existing or new Cloud SQL / AlloyDB instance the destination
            connection profile targets, which source Port is used (e.g.,
            standard port 5432), which projects are targeted (e.g., source
            project ID, destination project ID), and the corresponding VPC/VPC
            ID.
    *   **Planning Decisions & Logic**:
        *   List and clarify all major architectural and configuration decisions
            made by the agent during planning.
        *   Explicitly state whether the agent decided to reuse an existing
            Private Connection or plans to provision a new one.
        *   Explicitly state whether the agent decided to include all databases
            into the migration or only migrate specific ones.
        *   Clarify target instance decisions (e.g., creating a new or reusing
            an existing target Cloud SQL or AlloyDB resource).
*   **Explicit Action Confirmation**: Do NOT proceed to execute or apply any of
    the generated plan/files yet. You MUST ask the user for explicit
    confirmation (e.g., "I have prepared the resource configuration plan. Would
    you like me to proceed with creating these resources now?") and wait for
    them to type a reply before proceeding to physical creation in Step 5.

#### 1. Destination Instance

If migrating to a new instance, provision a new Cloud SQL / AlloyDB instance.
Create a PSC-enabled instance since Postgres homogeneous migrations only support
migrating into PSC-enabled instances.

#### 2. Private Connection

PostgreSQL homogeneous migrations require a Private Connection to be created for
both private and public source connectivity.

*   Load and follow the instructions in the runbook depending on the
    connectivity type used by the source:

    *   For private connectivity:
        `references/psci-private-connection/runbook.md`
    *   For public connectivity:
        `references/reserved-public-ip-private-connection/runbook.md`

*   **Action**: Record the resolved connection identifier immediately:

    *   Write `extensible_specialist_state.private_connection_id` to state.

#### 3. Source Connection Profile

Create and validate the source connection profile. Refer to
`references/postgresql-homogeneous/terraform/source_cp.tf` or
`references/postgresql-homogeneous/gcloud/source_cp.sh` for examples of how to
create it.

*   **Action**: Record the resolved connection profile immediately:
    *   Write `extensible_specialist_state.source_connection_id` to state.

If connection profile creation fails or the profile remains in a `FAILED` state,
troubleshoot and resolve errors before proceeding.

#### 4. Destination Connection Profile

*   Create a user on the destination instance for migration purposes using
    available tools (rather than direct SQL execution). Ensure the created user
    has `cloudsqlsuperuser` (Cloud SQL) or `alloydbsuperuser` (AlloyDB)
    privileges. Name the user `dms_user_<suffix>`. Generate a random password
    for the user.
*   Create a destination connection profile that uses the created user. Refer to
    `references/postgresql-homogeneous/terraform/dest_cp_cloudsql.tf`,
    `references/postgresql-homogeneous/terraform/dest_cp_alloydb.tf`,
    `references/postgresql-homogeneous/gcloud/dest_cp_cloudsql.sh`, or
    `references/postgresql-homogeneous/gcloud/dest_cp_alloydb.sh` for examples.
*   **Action**: Record the migration user and profile identifier immediately:
    *   Write `extensible_specialist_state.destination_user` to state.
    *   Write `extensible_specialist_state.destination_connection_id` to state.

#### 5. Migration Job

Create the migration job. Refer to:

-   `references/postgresql-homogeneous/terraform/migration_job_all_databases.tf`
-   `references/postgresql-homogeneous/terraform/migration_job_selected_databases.tf`
-   `references/postgresql-homogeneous/gcloud/migration_job_all_databases.sh`
-   `references/postgresql-homogeneous/gcloud/migration_job_selected_databases.sh`
    for examples.

*   You must create a migration job with the `--use-postgres-native` flag.

*   Unless stated otherwise, default to all databases to be included in the
    migration.

*   For Terraform, create the migration job in the `NOT_STARTED` state and set
    `stop_on_warnings = true`.

*   **Action**: Record the created resource identifiers immediately to the state
    ledger:

    *   Write the logical `extensible_specialist_state.migration_job_id` to
        state.

### 5. Confirm and Execute Migration Plan

Plan execution involves the three actions below:

1.  Create all needed resources.
2.  Verify the migration job.
3.  Start the migration job.

Follow the guidelines below for plan execution:

*   For Terraform, update the migration job state to `RUNNING` and set
    `stop_on_warnings = true` initially to get and present all warnings to the
    user.
*   For `gcloud`, both verification and start operations return an operation ID.
    Poll the operation until it finishes to retrieve any warnings or errors.
*   If verification or start returns errors, troubleshoot them using available
    tools. Do not proceed until verification succeeds with no errors (warnings
    are acceptable and can be acknowledged/skipped).
*   If verification returns warnings, ask the user if they are okay to ignore
    them.
*   In the final response, provide:
    *   A direct link to the started migration job in the Google Cloud Console
        using exactly this URL format (where `<region>` replaces the region and
        `<migration_id>` replaces the migration job ID):
        `https://console.cloud.google.com/dbmigration/migrations/locations/<region>/instances/<migration_id>`
    *   A link to either `terraform_directory` or `gcloud_directory`.
