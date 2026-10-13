# Database Migration Agents Plugin

> [!NOTE] **Preview:** This plugin is currently in "**Preview**". While we
> encourage you to try it out and provide feedback, it is not yet considered
> generally available (GA) for production workloads. The included skills and
> behaviors are subject to change without notice. Additionally, please be aware
> that this plugin may utilize Google Cloud Database Migration Service (DMS)
> features that are also currently in Preview.

## Overview

This repository contains a plugin for Antigravity and Claude Code that aims to
streamline the database migration journey using Cloud Database Migration Service
(DMS). The plugin leverages tools available on the user's local machine to
orchestrate GCP resources, discover infrastructure, and connect to source and
destination databases seamlessly.

## Prerequisites

Before using the plugin, ensure that you have either `gcloud` or `terraform`
installed on your machine and properly authenticated to your Google Cloud
environment.

## Installation

### Option 1: Antigravity CLI (agy)

You can add the plugin using the Antigravity CLI:

```bash
agy plugins install https://github.com/GoogleCloudPlatform/database-migration-agents
```

### Option 2: Claude Code

Add the database migration marketplace for Claude plugins:

```bash
claude plugin marketplace add GoogleCloudPlatform/database-migration-agents
```

Install the Claude plugin:

```bash
claude plugin install database-migration-agents@database-migration-marketplace
```

## Supported Migration Paths

The plugin currently supports Assisted Configuration for the following migration
paths:

1.  PostgreSQL to Cloud SQL for PostgreSQL
2.  PostgreSQL to AlloyDB for PostgreSQL

For other migration paths supported by Cloud DMS, the plugin supports advisory
assistance to guide you through the process.

## Assisted Configuration

Assisted Configuration automatically discovers your source databases,
destination environments, and connectivity paths, helping orchestrate the
necessary GCP networking resources for your migration. It supports 3 modes of
infrastructure discovery:

1.  **Local Mode**: Reviews available Terraform files locally in your workspace
    to understand your existing infrastructure.
2.  **Remote Mode**: Reviews remote Terraform files and `.tfstate` to discover
    your environment.
3.  **Manual Mode**: Uses the `gcloud` CLI tool to manually explore your
    existing GCP infrastructure and resources.

## Usage Statistics

The Database Migration Agents plugin collects anonymous usage statistics (such
as which migration runbooks are used and the migration type) to help us improve
the plugin. **We do not collect personal information, prompt texts, or database
contents.**

To opt out, either set `DO_NOT_TRACK=1` in the environment where you run your
agent:

```bash
export DO_NOT_TRACK=1
```

Or create or update `~/.google-database-migration/config.json`:

```json
{
  "enableTelemetry": false
}
```

