#!/bin/bash

# Variablen festlegen
DOMAIN="domain.de"
MAIL_USER="security"   # Ersetze durch den neuen Benutzernamen
MAIL_PASS='secure_passwd'   # Ersetze durch das Passwort für den neuen Benutzer
VMAIL_UID=5000               # Muss mit der UID übereinstimmen, die du für vmail verwendet hast
VMAIL_GID=5000               # Muss mit der GID übereinstimmen, die du für vmail verwendet hast
VMAIL_DIR="/var/mail/vhosts"

# 1. Passwort-Hash generieren und Benutzer in Dovecot hinzufügen
echo "Füge Dovecot-Benutzer hinzu..."
PASSWORD_HASH=$(doveadm pw -s SHA512-CRYPT -u $MAIL_USER@$DOMAIN -p $MAIL_PASS)

# Prüfen, ob der Benutzer bereits existiert
if grep -q "^$MAIL_USER@$DOMAIN:" /etc/dovecot/users; then
  echo "Benutzer $MAIL_USER@$DOMAIN existiert bereits. Aktualisiere Passwort..."
  sed -i "s|^$MAIL_USER@$DOMAIN:.*|$MAIL_USER@$DOMAIN:$PASSWORD_HASH|" /etc/dovecot/users
else
  echo "$MAIL_USER@$DOMAIN:$PASSWORD_HASH" >> /etc/dovecot/users
fi

# 2. Mail-Verzeichnis für den Benutzer erstellen
echo "Erstelle Mail-Verzeichnis für $MAIL_USER@$DOMAIN..."
MAILDIR="$VMAIL_DIR/$DOMAIN/$MAIL_USER"
if [ ! -d "$MAILDIR" ]; then
  mkdir -p "$MAILDIR"
  chown -R $VMAIL_UID:$VMAIL_GID "$VMAIL_DIR/$DOMAIN/$MAIL_USER"
  chmod -R 700 "$VMAIL_DIR/$DOMAIN/$MAIL_USER"
  echo "Mail-Verzeichnis erstellt."
else
  echo "Mail-Verzeichnis existiert bereits."
fi

# 3. Postfix virtuelle Mailboxen aktualisieren
echo "Aktualisiere Postfix virtuelle Mailboxen..."
if grep -q "^$MAIL_USER@$DOMAIN" /etc/postfix/vmailbox; then
  echo "Eintrag für $MAIL_USER@$DOMAIN existiert bereits in /etc/postfix/vmailbox."
else
  echo "$MAIL_USER@$DOMAIN    $DOMAIN/$MAIL_USER/" >> /etc/postfix/vmailbox
  postmap /etc/postfix/vmailbox
  echo "Postfix virtuelle Mailboxen aktualisiert."
fi

# 4. Dienste neu starten
echo "Starte Dovecot neu..."
systemctl restart dovecot

echo "Starte Postfix neu..."
systemctl restart postfix

echo "Der Benutzer $MAIL_USER@$DOMAIN wurde erfolgreich erstellt!"
