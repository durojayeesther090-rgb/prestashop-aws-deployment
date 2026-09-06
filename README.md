# PrestaShop Deployment on AWS Free Tier

A production-style e-commerce deployment on AWS, separating the application
tier (EC2) from the data tier (RDS) with network-level isolation enforced
through security groups.

**Live demo:** `http://<ec2-public-ip>/` *(instance may be stopped to avoid Free Tier overage — see note below)*

## Architecture

```
                    Internet
                        │
                 ┌──────▼──────┐
                 │   EC2       │   prestashop-web-sg
                 │ Ubuntu 26.04│   - 22  (SSH, my IP only)
                 │ Apache+PHP  │   - 80  (HTTP)
                 │ 8.5         │   - 443 (HTTPS)
                 └──────┬──────┘
                        │ (source = prestashop-web-sg)
                 ┌──────▼──────┐
                 │   RDS       │   prestashop-db-sg
                 │   MySQL     │   - 3306 (from web-sg only,
                 │ Free Tier   │           not from any IP)
                 └─────────────┘
```

- **EC2** (t2/t3.micro, Ubuntu Server 26.04 LTS): hosts Apache 2.4, PHP 8.5,
  and the PrestaShop application.
- **RDS** (MySQL, Free Tier): a separate managed database instance, not
  co-located with the application server. `Public access: No` — reachable
  only from within the VPC.
- **Security groups**: the database's inbound rule for port 3306 is scoped
  to the *EC2 security group itself* as the source, not an IP range. This
  means only traffic actually originating from the web tier's security
  group can reach the database, regardless of what IP that traffic comes
  from.

## Why this structure

Keeping the database on its own RDS instance rather than installing MySQL
directly on the EC2 box means the data tier can be patched, backed up, and
scaled independently of the web tier, and a compromise of the web server
doesn't hand over direct access to the database. Scoping the security group
rule to a security-group source instead of an IP address ties access to the
resource's identity rather than a network address, which is materially
harder to spoof or misconfigure than an IP allow-list.

## Build steps

See [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md) for the full walkthrough,
including the compatibility issues hit during install (missing
`mod_rewrite`, an ICU version gap, a missing initial database name, and an
`AllowOverride None` misconfiguration blocking clean URLs) and how each was
diagnosed and fixed.

Reference commands used throughout the build (with placeholders in place of
real IDs/IPs/secrets) are in [`scripts/`](scripts/).

## Stack

- AWS EC2 (Ubuntu Server 26.04 LTS)
- AWS RDS (MySQL, Free Tier)
- Apache 2.4 + PHP 8.5
- PrestaShop 9.1.5

## Note on availability

This was built on AWS Free Tier. To avoid ongoing charges, the EC2/RDS
instances may be stopped when not actively being demonstrated. The
screenshots in `docs/DEPLOYMENT.md` document the working deployment.
