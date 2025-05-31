#!/bin/bash

# Variablen festlegen
DOMAIN="domain.tld"
MAIL_USER="user"  # Ersetze durch den zu löschenden Benutzernamen
VMAIL_DIR="/var/mail/vhosts"
VMAIL_UID=5000
VMAIL_GID=5000

EMAIL="$MAIL_USER@$DOMAIN"
MAILDIR="$VMAIL_DIR/$DOMAIN/$MAIL_USER"

echo "Lösche Mail-Account: $EMAIL"

# 1. Benutzer aus Dovecot entfernen
if grep -q "^$EMAIL:" /etc/dovecot/users; then
  sed -i "/^$EMAIL:/d" /etc/dovecot/users
  echo "Dovecot-Benutzer entfernt."
else
  echo "Kein Dovecot-Eintrag für $EMAIL gefunden."
fi

# 2. Mail-Verzeichnis löschen
if [ -d "$MAILDIR" ]; then
  rm -rf "$MAILDIR"
  echo "Mail-Verzeichnis $MAILDIR gelöscht."
else
  echo "Kein Mail-Verzeichnis für $EMAIL gefunden."
fi

# 3. Postfix vmailbox-Eintrag entfernen
if grep -q "^$EMAIL" /etc/postfix/vmailbox; then
  sed -i "/^$EMAIL/d" /etc/postfix/vmailbox
  postmap /etc/postfix/vmailbox
  echo "Postfix vmailbox-Eintrag entfernt."
else
  echo "Kein Eintrag in /etc/postfix/vmailbox für $EMAIL gefunden."
fi

# 4. Dienste neu starten
echo "Starte Dovecot neu..."
systemctl restart dovecot

echo "Starte Postfix neu..."
systemctl restart postfix

echo "Der Benutzer $EMAIL wurde erfolgreich gelöscht."
