#!/bin/bash

# Dieses Skript installiert und konfiguriert Postfix, Dovecot und OpenDKIM auf einem Ubuntu-Server.
# Es richtet einen Mailserver mit virtuellen Benutzern und Domains ein.

# Bitte ersetze die Variablen DOMAIN, MAIL_USER und MAIL_PASS durch deine eigenen Werte.

# Variablen festlegen
DOMAIN="domain.de"
MAIL_USER="info"
MAIL_PASS="DEIN_PASSWORT"
HOSTNAME="mail.$DOMAIN"
VMAIL_UID=5000
VMAIL_GID=5000
VMAIL_DIR="/var/mail/vhosts"

# Hostname setzen
echo "Setze Hostname auf $HOSTNAME"
hostnamectl set-hostname $HOSTNAME

# System aktualisieren
echo "Aktualisiere das System..."
apt update && apt upgrade -y

# Installiere benötigte Pakete
echo "Installiere benötigte Pakete..."
apt install -y postfix postfix-mysql dovecot-core dovecot-imapd dovecot-lmtpd opendkim opendkim-tools mailutils ufw fail2ban certbot

# Postfix-Konfiguration
echo "Konfiguriere Postfix..."

# Main.cf sichern
cp /etc/postfix/main.cf /etc/postfix/main.cf.backup

# Postfix Main-Konfiguration
tee /etc/postfix/main.cf > /dev/null <<EOF
# Postfix Hauptkonfigurationsdatei

# Allgemeine Einstellungen
smtpd_banner = \$myhostname ESMTP \$mail_name
biff = no
append_dot_mydomain = no

# TLS-Einstellungen
smtpd_tls_cert_file=/etc/letsencrypt/live/$HOSTNAME/fullchain.pem
smtpd_tls_key_file=/etc/letsencrypt/live/$HOSTNAME/privkey.pem
smtpd_use_tls=yes
smtpd_tls_security_level=may
smtpd_tls_auth_only=yes
smtpd_tls_session_cache_database=btree:\${data_directory}/smtpd_scache

# SMTP-Authentifizierung
smtpd_sasl_auth_enable = yes
smtpd_sasl_type = dovecot
smtpd_sasl_path = private/auth
smtpd_sasl_security_options = noanonymous

# Milter für OpenDKIM
milter_default_action = accept
smtpd_milters = inet:localhost:12301
non_smtpd_milters = inet:localhost:12301

# Virtual Mailboxen
virtual_mailbox_domains = $DOMAIN
virtual_mailbox_base = $VMAIL_DIR
virtual_mailbox_maps = hash:/etc/postfix/vmailbox
virtual_minimum_uid = $VMAIL_UID
virtual_uid_maps = static:$VMAIL_UID
virtual_gid_maps = static:$VMAIL_GID
virtual_transport = lmtp:unix:private/dovecot-lmtp

# Empfängerbeschränkungen
smtpd_recipient_restrictions = permit_sasl_authenticated, permit_mynetworks, reject_unauth_destination

myhostname = $HOSTNAME
myorigin = /etc/mailname
mydestination = \$myhostname, localhost.\$mydomain, localhost
relayhost =

alias_maps = hash:/etc/aliases
alias_database = hash:/etc/aliases

# Postfix-Datenbankeinstellungen
smtp_tls_session_cache_database = btree:\${data_directory}/smtp_scache
smtp_tls_security_level = may

# Weitere Einstellungen
inet_interfaces = all
inet_protocols = ipv4
EOF

# Zertifikate erstellen (Let's Encrypt)
echo "Erstelle SSL-Zertifikate mit Let's Encrypt..."
apt install -y certbot
certbot certonly --standalone -d $HOSTNAME --non-interactive --agree-tos -m admin@$DOMAIN

# Prüfen, ob die Zertifikate erfolgreich erstellt wurden
if [ ! -f /etc/letsencrypt/live/$HOSTNAME/fullchain.pem ]; then
  echo "Fehler beim Erstellen des SSL-Zertifikats. Bitte überprüfe deine Domain und DNS-Einstellungen."
  exit 1
fi

# Master.cf anpassen
echo "Passe /etc/postfix/master.cf an..."
sed -i 's/^#submission/submission/' /etc/postfix/master.cf
sed -i 's/^# \-o syslog_name=postfix\/submission/  -o syslog_name=postfix\/submission/' /etc/postfix/master.cf
sed -i 's/^# \-o smtpd_tls_security_level=encrypt/  -o smtpd_tls_security_level=encrypt/' /etc/postfix/master.cf
sed -i 's/^# \-o smtpd_sasl_auth_enable=yes/  -o smtpd_sasl_auth_enable=yes/' /etc/postfix/master.cf
sed -i 's/^# \-o smtpd_client_restrictions=permit_sasl_authenticated,reject/  -o smtpd_client_restrictions=permit_sasl_authenticated,reject/' /etc/postfix/master.cf

# SMTPS (Port 465) aktivieren
tee -a /etc/postfix/master.cf > /dev/null <<EOF

smtps     inet  n       -       n       -       -       smtpd
  -o syslog_name=postfix/smtps
  -o smtpd_tls_wrappermode=yes
  -o smtpd_tls_security_level=encrypt
  -o smtpd_sasl_auth_enable=yes
  -o smtpd_client_restrictions=permit_sasl_authenticated,reject
EOF

# Postfix-Neustart
echo "Starte Postfix neu..."
systemctl restart postfix

# Dovecot-Konfiguration
echo "Konfiguriere Dovecot..."

# Benutzer und Gruppe für virtuelle Mailboxen erstellen
echo "Erstelle Benutzer und Gruppe für virtuelle Mailboxen..."
groupadd -g $VMAIL_GID vmail
useradd -g vmail -u $VMAIL_UID vmail -d /var/mail

# Mail-Verzeichnis erstellen
echo "Erstelle Mail-Verzeichnis..."
mkdir -p $VMAIL_DIR/$DOMAIN/$MAIL_USER/Maildir
chown -R vmail:vmail $VMAIL_DIR
chmod -R 700 $VMAIL_DIR

# Dovecot Hauptkonfiguration
tee /etc/dovecot/dovecot.conf > /dev/null <<EOF
# Dovecot Hauptkonfigurationsdatei
protocols = imap lmtp

mail_location = maildir:$VMAIL_DIR/%d/%n/Maildir

namespace inbox {
  inbox = yes
}

auth_mechanisms = plain login

passdb {
  driver = passwd-file
  args = scheme=SHA512-CRYPT username_format=%u /etc/dovecot/users
}

userdb {
  driver = static
  args = uid=$VMAIL_UID gid=$VMAIL_GID home=$VMAIL_DIR/%d/%n
}

service auth {
  unix_listener /var/spool/postfix/private/auth {
    mode = 0660
    user = postfix
    group = postfix
  }
}

service lmtp {
  unix_listener /var/spool/postfix/private/dovecot-lmtp {
    mode = 0600
    user = postfix
    group = postfix
  }
}

ssl = required
ssl_cert = </etc/letsencrypt/live/$HOSTNAME/fullchain.pem
ssl_key = </etc/letsencrypt/live/$HOSTNAME/privkey.pem
EOF

# Dovecot-Benutzer hinzufügen
echo "Füge Dovecot-Benutzer hinzu..."
PASSWORD_HASH=$(doveadm pw -s SHA512-CRYPT -u $MAIL_USER@$DOMAIN -p $MAIL_PASS)
echo "$MAIL_USER@$DOMAIN:$PASSWORD_HASH" > /etc/dovecot/users

# Dovecot neu starten
echo "Starte Dovecot neu..."
systemctl restart dovecot

# Postfix-virtuelle Mailboxen konfigurieren
echo "Konfiguriere Postfix virtuelle Mailboxen..."
echo "$MAIL_USER@$DOMAIN    $DOMAIN/$MAIL_USER/" > /etc/postfix/vmailbox
postmap /etc/postfix/vmailbox

# OpenDKIM installieren und konfigurieren
echo "Installiere und konfiguriere OpenDKIM..."

# OpenDKIM-Ordner erstellen
mkdir -p /etc/opendkim/keys/$DOMAIN
chown -R opendkim:opendkim /etc/opendkim

# OpenDKIM-Schlüssel generieren
echo "Generiere OpenDKIM-Schlüssel..."
opendkim-genkey -D /etc/opendkim/keys/$DOMAIN/ -d $DOMAIN -s mail
chown opendkim:opendkim /etc/opendkim/keys/$DOMAIN/mail.private
chmod 600 /etc/opendkim/keys/$DOMAIN/mail.private

# OpenDKIM Hauptkonfiguration
tee /etc/opendkim.conf > /dev/null <<EOF
# OpenDKIM Hauptkonfiguration
Syslog                  yes
UMask                   002
Mode                    sv
Canonicalization        relaxed/simple
OversignHeaders         From
Domain                  $DOMAIN
KeyFile                 /etc/opendkim/keys/$DOMAIN/mail.private
Selector                mail
Socket                  inet:12301@localhost
PidFile                 /run/opendkim/opendkim.pid
UserID                  opendkim:opendkim
EOF

# OpenDKIM-TrustedHosts
tee /etc/opendkim/TrustedHosts > /dev/null <<EOF
127.0.0.1
localhost
$DOMAIN
EOF

# OpenDKIM-Schlüssel in KeyTable und SigningTable eintragen
tee /etc/opendkim/KeyTable > /dev/null <<EOF
mail._domainkey.$DOMAIN $DOMAIN:mail:/etc/opendkim/keys/$DOMAIN/mail.private
EOF

tee /etc/opendkim/SigningTable > /dev/null <<EOF
*@$DOMAIN mail._domainkey.$DOMAIN
EOF

# OpenDKIM-Ordner und Berechtigungen
mkdir -p /run/opendkim
chown opendkim:opendkim /run/opendkim
chmod 750 /run/opendkim

# OpenDKIM neu starten
echo "Starte OpenDKIM neu..."
systemctl restart opendkim

# Postfix Milter-Einstellungen hinzufügen
postconf -e 'milter_default_action = accept'
postconf -e 'smtpd_milters = inet:localhost:12301'
postconf -e 'non_smtpd_milters = inet:localhost:12301'

# Postfix neu starten
echo "Starte Postfix neu..."
systemctl restart postfix

# DNS-Einträge anzeigen
echo "Bitte füge folgende DNS-Einträge hinzu:"
echo
echo "DKIM (TXT Record):"
cat /etc/opendkim/keys/$DOMAIN/mail.txt
echo
echo "SPF (TXT Record):"
echo "@ IN TXT \"v=spf1 mx a ~all\""
echo
echo "DMARC (TXT Record):"
echo "_dmarc IN TXT \"v=DMARC1; p=none; rua=mailto:postmaster@$DOMAIN; ruf=mailto:postmaster@$DOMAIN; sp=none; aspf=r; adkim=r;\""
echo

# UFW konfigurieren
echo "Konfiguriere UFW..."
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp       # SSH
ufw allow 25/tcp       # SMTP
ufw allow 465/tcp      # SMTPS
ufw allow 587/tcp      # SMTP Submission
ufw allow 993/tcp      # IMAPS
ufw allow 995/tcp      # POP3S (optional)
ufw --force enable

# Fail2Ban installieren und konfigurieren
echo "Installiere und konfiguriere Fail2Ban..."

# Fail2Ban konfigurieren
tee /etc/fail2ban/jail.local > /dev/null <<EOF
[DEFAULT]
bantime  = 1h
findtime  = 10m
maxretry = 5

[sshd]
enabled = true
port    = ssh
logpath = %(sshd_log)s
backend = %(sshd_backend)s

[postfix]
enabled = true
port    = smtp,submissions,465
filter  = postfix
logpath = journal
backend = systemd

[dovecot]
enabled = true
port    = imap,imaps,pop3,pop3s
filter  = dovecot
logpath = journal
backend = systemd
EOF

# Fail2Ban neu starten
echo "Starte Fail2Ban neu..."
systemctl restart fail2ban

echo "Die Installation und Konfiguration ist abgeschlossen!"
echo "Bitte denke daran, die DNS-Einträge bei deinem DNS-Provider zu setzen."
