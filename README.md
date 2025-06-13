# Mail‑Server Auto‑Installer (Postfix + Dovecot + OpenDKIM) – Hardened Edition – **June 2025**

This script automates the installation and configuration of a secure **single‑domain** mail‑server stack on a fresh Debian / Ubuntu host. It bundles Postfix, Dovecot, OpenDKIM, Let’s Encrypt, UFW, and Fail2Ban with modern hardened defaults so you can be up and running in minutes.

---

## ✨ Features

* **Postfix** – SMTP/Submission with virtual mailboxes and postscreen DNSBL filtering
* **Dovecot** – IMAP (+ LMTP) with secure Maildir storage
* **OpenDKIM** – Automatic DKIM key generation & signing
* **Let’s Encrypt** – Auto‑issued TLS cert for your mail host
* **UFW** – Locked‑down firewall rules (22, 25, 587, 993)
* **Fail2Ban** – Brute‑force protection for SSH, Postfix & Dovecot
* **Security hardening** – TLS ≥ 1.2 enforced, sane HELO/recipient checks, spam blacklists
* **DNS helper** – Prints DKIM, SPF, DMARC, TLS‑RPT & MTA‑STS records to add to your zone

---

## 🛠 Prerequisites

* Fresh Ubuntu / Debian server **with root** access
* A registered domain (e.g. `domain.de`)
* Correct **A** and **MX** records pointing to the server’s public IP
* Ports **80, 443, 25, 587, 993** reachable from the internet

---

## Installation

1. Edit the domain variable at the top of the script:

   ```bash
   DOMAIN="example.com"
   ```

2. Run the setup script as root:

   ```bash
   chmod +x setup.sh
   ./setup.sh
   ```

## 1 · Clone the repository & review the script

```bash
git clone https://github.com/Bleckitechs/Mailserver_setup.sh.git
cd Mailserver_setup.sh
nano setupmail.sh      # or your editor of choice
```

> **Important:** Read the variable block at the top of `setupmail.sh` and adjust it for your domain!

### 2 · Edit variables

```bash
DOMAIN="domain.de"       # Your mail domain
MAIL_USER="info"         # First mailbox user (local part)
MAIL_PASS="PASSWORT"     # Initial password (will be hashed)
HOSTNAME="mail.$DOMAIN"  # FQDN for this server (matches MX & cert)
VMAIL_UID=5000            # UID for virtual mail user
VMAIL_GID=5000            # GID for virtual mail group
VMAIL_DIR="/var/mail/vhosts"  # Mail storage root
```

### 3 · Run the script as **root**

```bash
sudo bash setupmail.sh
```

The installer will:

1. Set the system hostname (`$HOSTNAME`)
2. Update all packages
3. Install Postfix, Dovecot, OpenDKIM, UFW, Fail2Ban, Certbot
4. Pull a Let’s Encrypt cert for `$HOSTNAME`
5. Write hardened configs for Postfix & Dovecot
6. Generate DKIM keys and enable signing
7. Create the first mailbox user (`$MAIL_USER@$DOMAIN`)
8. Activate firewall & Fail2Ban jails
9. Print ready‑to‑copy DNS records for SPF/DKIM/DMARC/TLS‑RPT/MTA‑STS

---

## 🔍 What the script does — Step by Step

1. **Sanity checks** – aborts if not run as root
2. **System prep** – sets hostname, updates apt cache
3. **Package install** – Postfix, Dovecot, OpenDKIM, Certbot, UFW, Fail2Ban
4. **TLS certificate** – obtains/renews Let’s Encrypt cert (stops on failure)
5. **Postfix** – backs up old configs, writes new `main.cf` & `master.cf` with:

   * TLS ≥ 1.2 only, strong ciphers
   * postscreen DNSBLs, HELO & recipient sanity checks
   * Virtual mailbox maps for **one domain**
   * OpenDKIM milter enabled
6. **Dovecot** – creates `vmail` user/group, secure `maildir` layout, auth config
7. **Virtual mailbox map** – builds `/etc/postfix/vmailbox` and runs `postmap`
8. **OpenDKIM** – key generation (`/etc/opendkim/keys/$DOMAIN`), tables & perms
9. **Firewall** – enables UFW: allow 22, 25, 587, 993; deny everything else
10. **Fail2Ban** – installs `jail.local` for SSH, Postfix, Dovecot
11. **DNS helper** – prints TXT records & hints at the end of the run

---

## 📝 Manual Steps After Installation

### 1 · Add DNS records

| Record      | Value                                                                                     |
| ----------- | ----------------------------------------------------------------------------------------- |
| **DKIM**    | Use contents of `/etc/opendkim/keys/$DOMAIN/mail.txt`                                     |
| **SPF**     | `@ IN TXT "v=spf1 mx a -all"`                                                             |
| **DMARC**   | `_dmarc IN TXT "v=DMARC1; p=quarantine; rua=mailto:postmaster@$DOMAIN; aspf=r; adkim=r;"` |
| **TLS‑RPT** | `_smtp._tls.$DOMAIN. IN TXT "v=TLSRPTv1; rua=mailto:tlsrpt@$DOMAIN"`                      |
| **MTA‑STS** | Publish policy & corresponding TXT record                                                 |

> Wait for DNS to propagate before running external tests.

### 2 · Test the server

* Connect via **IMAP over TLS (993)** with `user: $MAIL_USER@$DOMAIN`
* Send & receive test mails (check spam folders)
* Validate SPF/DKIM/DMARC at [mail‑tester.com](https://www.mail-tester.com/)

---

## 📡 Ports Opened

| Protocol   | Port |
| ---------- | ---- |
| SMTP       | 25   |
| Submission | 587  |
| IMAPS      | 993  |

---

## 🛠 Troubleshooting

### Certificate retrieval fails

* DNS **A/MX** records missing or not propagated?
* Ensure **ports 80/443** are open and not blocked upstream.

### Mail not delivered

* Check `/var/log/mail.log`, `/var/log/dovecot.log`, `/var/log/fail2ban.log`
* Re‑check DNS records (SPF/DKIM/DMARC) for typos.

### IMAP login fails

* Username must be the **full address** (`user@$DOMAIN`)
* Verify hashed password in `/etc/dovecot/users`.

---

## 🔐 Security Notes

* TLS ≥ 1.2, no legacy ciphers or protocols
* Fail2Ban bans hostile IPs automatically
* Only required ports are open via UFW
* DKIM private keys **never leave** the server

---

## 📄 License

Released under the [MIT License](LICENSE).
