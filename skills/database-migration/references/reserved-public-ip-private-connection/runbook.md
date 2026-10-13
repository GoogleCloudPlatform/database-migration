Your goal is to ensure a healthy Private Connection exists to enable a DMS
migration to reach the source database that is accessible via Public IP or
Hostname.

**Inputs Required:**

-   `project_id` and `region`: The GCP Project ID and Region where the DMS
    migration will be created.
-   `terraform_directory` or `gcloud_directory`: Path to the directory to use
    for provisioning required GCP resources with Terraform or gcloud.

**Outputs Expected:**

-   The full name of the DMS Private Connection.

### 1. Identify or Create Private Connection

Check if there is already an existing Private Connection in the desired
`project_id` and `region` in a `CREATED` state that uses
`ReservedPublicIPConfig`.

-   **If yes:** Reuse it.
-   **If no:** Create a new DMS Private Connection:
    -   Refer to
        `references/reserved-public-ip-private-connection/gcloud/private-connection.sh`
        or
        `references/reserved-public-ip-private-connection/terraform/private-connection.tf`
        for examples of how to create it. If using Terraform, ensure the
        `hashicorp/google` provider version is `>= 8.6.0`.
    -   Execute the creation using the provided `terraform_directory` or
        `gcloud_directory`.

### 2. Identify Egress IPs

Once the Private Connection is created, its `ReservedPublicIPConfig` outputs
`egress_public_ips`. Depending on the database engine and provider, you may need
to allowlist these IPs to allow connecting to the database instance through the
created Private Connection.
