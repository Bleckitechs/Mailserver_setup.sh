# Secure Mail Server Setup with Postfix, Dovecot, and OpenDKIM

This project provides a full setup script to install and configure a secure mail server on Ubuntu using Postfix, Dovecot, OpenDKIM, Let's Encrypt, Fail2Ban, and UFW.  
Mail users are managed via helper scripts: `addmail.sh` and `delmail.sh`.

## Features

- SMTP with STARTTLS (587), SMTPS (465), and IMAPS (993)
- Virtual mailboxes stored under `/var/mail/vhosts`
- TLS encryption with Let's Encrypt
- DKIM signing using OpenDKIM
- SPF and DMARC DNS suggestions
- Brute-force protection with Fail2Ban
- Firewall configuration using UFW
- Easy user management with `addmail.sh` and `delmail.sh`

## Requirements

- A domain (e.g., `example.com`)
- An A record pointing `mail.example.com` to your server
- Port 25 **open** (required for receiving emails)
- Ubuntu-based system (tested on Ubuntu 22.04)

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

3. Set the following DNS records at your DNS provider:

### SPF
```dns
@ IN TXT "v=spf1 mx a ~all"
```

### DKIM  
Copy the TXT record printed at the end of the script under `mail._domainkey`.

### DMARC
```dns
_dmarc IN TXT "v=DMARC1; p=reject; rua=mailto:postmaster@example.com; ruf=mailto:postmaster@example.com; sp=none; aspf=r; adkim=r;"
```

---

## User Management

### Add Mail User

Use `addmail.sh` to add a new user:
```bash
./addmail.sh user securepassword
```

### Delete Mail User

Use `delmail.sh` to remove a user:
```bash
./delmail.sh user
```

Both scripts handle the virtual mailbox, Dovecot credentials, and directory cleanup.

---

## Ports Used

| Protocol      | Port |
|---------------|------|
| SMTP (Inbound)| 25   |
| Submission    | 587  |
| SMTPS         | 465  |
| IMAPS         | 993  |
| POP3S (opt.)  | 995  |

---

## Security

- TLS certificates are automatically issued via Let's Encrypt.
- Fail2Ban protects SSH, Postfix, and Dovecot from brute-force attacks.
- UFW is configured to allow only necessary ports.
- DKIM, SPF, and DMARC help protect against spoofing.

---

## Notes

- Make sure ports 25, 465, 587, and 993 are open on your firewall and hosting provider.
- Some cloud providers (like AWS or Oracle) block port 25 by default. You may need to request an unblock.

---

## License

MIT License – use at your own risk and customize to your needs.
