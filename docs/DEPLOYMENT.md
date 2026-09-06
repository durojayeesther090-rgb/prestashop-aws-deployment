# Deployment Walkthrough

> Note: IPs, endpoints, the admin folder path, and credentials below are
> shown as placeholders (`<...>`). Never commit real values for these —
> the admin folder name in particular is a security control (PrestaShop
> randomizes it specifically so it isn't guessable), and RDS endpoints/
> passwords should never be public.

## 1. Database layer — Amazon RDS

Created a MySQL instance using RDS's Free Tier template rather than
installing MySQL directly on the EC2 instance, so the data tier can be
patched, backed up, and scaled independently of the web tier.

- Engine: MySQL, Free Tier template
- VPC: Default VPC — EC2 and RDS only need to share a VPC to communicate
  privately, no custom networking required
- Public access: **No** — not reachable from the internet at all
- Compute resource connection: configured manually (declined the
  auto-connect option) so the security group rule was deliberate and
  understood, not opaque

## 2. Application layer — Amazon EC2

- AMI: Ubuntu Server 26.04 LTS
- Instance type: t2/t3.micro (Free Tier eligible)
- Key pair created and downloaded for SSH access; never committed to this
  repo or exposed anywhere

## 3. Network isolation — security groups

Two separate groups enforce the boundary between the public web tier and
the private database tier:

- **`prestashop-web-sg`** (EC2): inbound SSH (22, restricted to a single
  admin IP), HTTP (80, open), HTTPS (443, open)
- **`prestashop-db-sg`** (RDS): inbound MySQL (3306), source =
  `prestashop-web-sg` **as a security group**, not an IP address

Scoping the database rule to a security-group source means only traffic
actually originating from the EC2 instance's own security group can reach
port 3306 — this is tied to the resource's identity rather than a network
address, which can't be spoofed or accidentally left open the way an IP
range can.

**Issue hit:** the EC2 launch wizard's default flow initially left both
instances sharing one security group. Fixed by creating `prestashop-web-sg`
explicitly, reassigning it to the EC2 instance, then locking down
`prestashop-db-sg` to accept only the web security group as its source —
removing a leftover direct-IP rule the RDS wizard had added by default.

See [`scripts/security-groups.sh`](../scripts/security-groups.sh) for the
reference AWS CLI commands (sanitized).

## 4. Web stack installation

Connected via SSH and installed:

- Apache 2.4
- PHP 8.5 with the extensions PrestaShop requires: `mysql`, `curl`, `gd`,
  `intl`, `xml`, `zip`, `mbstring`

Confirmed Apache served its default page at the instance's public IP
*before* installing PrestaShop, to isolate any later issues to the
application layer rather than the base server.

## 5. PrestaShop installation

Downloaded PrestaShop directly onto the EC2 instance with `wget` from
PrestaShop's official release asset host (AWS-to-AWS transfer — the 116MB
package moved in under a second, versus downloading locally and
re-uploading).

**Issues hit during the compatibility check, both resolved before
continuing:**
- `mod_rewrite` wasn't enabled by default on the fresh Apache install,
  which PrestaShop requires for URL routing — fixed with `a2enmod rewrite`
  + Apache restart
- The ICU library needed upgrading to satisfy the `intl` PHP extension's
  compatibility check — fixed with a targeted `apt upgrade` on the
  `libicu*` packages

**Issue hit at the database step:** the RDS instance had no initial
database name set. Connected to the RDS endpoint from the EC2 instance
using the MySQL client and ran `CREATE DATABASE prestashop;` before
returning to the installer with the correct database name.

## 6. Post-install hardening and a routing fix

- Deleted the `/install` directory immediately after setup, per
  PrestaShop's own security requirement — leaving it in place would let
  anyone re-run the installer against the live store.
- The admin back office returned a 404 despite the files being present
  with correct ownership. Root cause: Apache's global
  `AllowOverride None` setting, which causes Apache to ignore all
  `.htaccess` files — including the one PrestaShop relies on for both
  admin routing and clean front-office URLs. Fixed by changing it to
  `AllowOverride All` and restarting Apache.

## Summary

Final architecture: a public web tier (EC2, Apache/PHP) fully separated
from a private data tier (RDS, MySQL), with the boundary enforced at the
network layer via security groups rather than convention. Every issue
along the way was diagnosed from its actual symptom — a 404, an
access-denied error, a failed compatibility check — rather than guessed
at, which is the same approach applicable to debugging any production
issue.
