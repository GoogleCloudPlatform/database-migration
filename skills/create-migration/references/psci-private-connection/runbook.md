Your goal is to ensure a healthy Private Connection exists to enable a DMS
migration to reach the source database. This skill assumes a Network Attachment
has already been created.

**Inputs Required:**

-   `project_id` and `region`: The GCP Project ID and Region where the DMS
    migration will be created.
-   `network_attachment_uri`: The full URI of the existing Network Attachment
    that exposes the source database.
-   `terraform_directory` or `gcloud_directory`: Path to the directory to use
    for provisioning required GCP resources with Terraform or gcloud.

**Outputs Expected:**

-   The full name of the DMS Private Connection.

### 1. Identify or Create Private Connection

Check if there is already an existing Private Connection in the desired
`project_id` and `region` in a `CREATED` state that points to the provided
`network_attachment_uri`.

-   **If yes:** Reuse it.
-   **If no:** Create a new DMS Private Connection pointing to the
    `network_attachment_uri`.
    -   Refer to
        `references/psci-private-connection/gcloud/private-connection.sh` or
        `references/psci-private-connection/terraform/private-connection.tf` for
        examples of how to create it. If using Terraform, ensure the
        `hashicorp/google` provider version is `>= 7.33.0`.
    -   Execute the creation using the provided `terraform_directory` or
        `gcloud_directory`.

### 2. Allowlist DMS Tenant Project ID

To ensure the Private Connection can attach successfully, you must allowlist the
DMS Tenant Project ID on the Network Attachment.

-   Refer to the
    `references/psci-private-connection/gcloud/private-connection-validate-only.sh`
    script to understand how to query for the DMS Tenant Project ID.
-   Update the Network Attachment to allowlist the discovered DMS Tenant Project
    ID.
-   **Fallback:** If `gcloud` is not available or the Tenant Project ID cannot
    be retrieved, fall back to updating the Network Attachment to use the
    `ACCEPT_AUTOMATIC` connection preference.
