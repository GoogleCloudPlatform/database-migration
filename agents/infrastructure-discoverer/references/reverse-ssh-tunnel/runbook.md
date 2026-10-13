# Reverse SSH Tunnel Setup Runbook

This runbook provides guidance in setting up a reverse SSH tunnel from the
user's local machine to a GCP Bastion VM. This allows the Database Migration
Service (DMS) to reach a local or private database for POC purposes.

## Step 1: Verify Local Connectivity

Ask the user for the local host and port they use to reach the database from
their local machine (e.g., `localhost:5432`, `192.168.1.100:3306`). Once
provided, use your command execution tools to verify connectivity from the local
environment by running:

```bash
nc -zv <local_db_host> <local_db_port>
```

If the command fails, inform the user and troubleshoot. Do not proceed until you
have confirmed the database is reachable from the local machine.

## Step 2: Provision Bastion VM & Establish Tunnel

Check if `gcloud` is available in the local environment (e.g., by running `which
gcloud`).

### Option A: `gcloud` is available (Preferred)

1.  **Provision Bastion VM:** You must provision a small Bastion VM without a
    public IP. Use your file reading tools to inspect the provided examples, and
    then execute the necessary commands to provision the infrastructure:
    -   Terraform:
        `<plugin_root_path>/agents/infrastructure-discoverer/references/reverse-ssh-tunnel/terraform/reverse_ssh_tunnel.tf`
    -   gcloud:
        `<plugin_root_path>/agents/infrastructure-discoverer/references/reverse-ssh-tunnel/gcloud/reverse_ssh_tunnel.sh`
        *(Ensure the firewall rules allow Identity-Aware Proxy (IAP) access: TCP
        port 22 from `35.235.240.0/20`, and that the startup script enables
        `GatewayPorts yes` in `sshd_config`)*
2.  **Establish Tunnel:** Once the Bastion VM is running, use your command
    execution tools to establish the reverse SSH tunnel using IAP. You must run
    this command in the background so it doesn't block your execution loop:

    ```bash
    gcloud compute ssh <bastion_vm_name> \
        --project=<project_id> \
        --zone=<zone> \
        --tunnel-through-iap \
        -- -f -N -R 0.0.0.0:<bastion_port>:<local_db_host>:<local_db_port>
    ```

    *(e.g., `-R 0.0.0.0:5432:localhost:5432`). Note the `-f` flag to send the
    SSH process to the background.*

### Option B: `gcloud` is NOT available

1.  **Provision Bastion VM:** You must provision a Bastion VM **with** a public
    IP.
    -   Use your file reading tools to inspect the provided examples for a
        public Bastion VM, and then execute the necessary commands to provision
        the infrastructure:
        -   Terraform:
            `<plugin_root_path>/agents/infrastructure-discoverer/references/reverse-ssh-tunnel/terraform/reverse_ssh_tunnel_public_ip.tf`
        -   gcloud:
            `<plugin_root_path>/agents/infrastructure-discoverer/references/reverse-ssh-tunnel/gcloud/reverse_ssh_tunnel_public_ip.sh`
2.  **Establish Tunnel:** Execute standard SSH to establish the tunnel in the
    background:

    ```bash
    ssh -i <path_to_private_key> <username>@<bastion_public_ip> -f -N -R 0.0.0.0:<bastion_port>:<local_db_host>:<local_db_port>
    ```

## Step 3: Use Bastion for DMS

Once the tunnel is successfully established, DMS must be configured to connect
to the **internal IP** of the Bastion VM on the port opened by the tunnel
(`<bastion_port>`). Return to the main discovery flow, outputting the Bastion
VM's internal IP and `<bastion_port>` as the discovered source database
connection details.
