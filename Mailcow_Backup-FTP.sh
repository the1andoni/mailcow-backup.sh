#!/bin/bash

# Variablen
BACKUP_DIR="/backup/mailcow"
FTP_Server="NEXTCLOUD-URL"
FTP_USER="NEXTCLOUD-USER"
FTP_PASS="NEXTCLOUD-PW"
FTP_UPLOAD_DIR="E:\Backups\FromFTP\MailServer"
MAILCOW_DIR="/opt/mailcow-dockerized"
DATE=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_PATH="$BACKUP_DIR/mailcow-$DATE"
TAR_FILE="$BACKUP_DIR/mailcow-backup-$DATE.tar.gz"

# Sicherstellen, dass das Backup-Verzeichnis existiert
mkdir -p "$BACKUP_DIR"
mkdir -p "$BACKUP_PATH"  # Sicherstellen, dass das Backup-Verzeichnis existiert

echo "[+] Starte Mailcow-Backup..."

# Mailcow-Backup starten und Pfad direkt übergeben, ohne Abfrage
cd "$MAILCOW_DIR" || { echo "❌ Fehler: Mailcow-Verzeichnis nicht gefunden!"; exit 1; }

# Der folgende Befehl überspringt die interaktive Abfrage und übergibt den Backup-Pfad direkt
echo "$BACKUP_PATH" | ./helper-scripts/backup_and_restore.sh backup all --delete-days 7

# Prüfen, ob das Backup erstellt wurde
if [ ! -d "$BACKUP_PATH" ] || [ -z "$(ls -A "$BACKUP_PATH")" ]; then
    echo "❌ Fehler: Backup-Ordner ist leer oder wurde nicht erstellt!"
    exit 1
fi

echo "[+] Backup erfolgreich erstellt: $BACKUP_PATH"

# Backup in ein tar.gz-Archiv packen
tar -czvf "$TAR_FILE" -C "$BACKUP_DIR" "mailcow-$DATE"

# Prüfen, ob das Archiv existiert
if [ ! -f "$TAR_FILE" ]; then
    echo "❌ Fehler: Backup-Archiv wurde nicht erstellt!"
    exit 1
fi

echo "[+] Archiv erfolgreich erstellt: $TAR_FILE"

# Backup auf Nextcloud hochladen
echo "[+] Lade Backup auf Nextcloud hoch..."
UPLOAD_RESPONSE=$(curl -u "$NEXTCLOUD_USER:$NEXTCLOUD_PASS" -T "$TAR_FILE" "$NEXTCLOUD_URL" --silent --write-out "%{http_code}")

# Prüfen, ob der Upload erfolgreich war
if [ "$UPLOAD_RESPONSE" -eq 201 ] || [ "$UPLOAD_RESPONSE" -eq 204 ]; then
    echo "[✅] Backup erfolgreich auf Nextcloud hochgeladen!"
else
    echo "❌ Fehler: Upload fehlgeschlagen (HTTP-Code: $UPLOAD_RESPONSE)"
    exit 1
fi

# ❌ Alte Backups löschen (nur die 7 neuesten behalten)
echo "[+] Prüfe, ob alte Backups gelöscht werden müssen..."
BACKUP_COUNT=$(ls -1 "$BACKUP_DIR"/*.tar.gz 2>/dev/null | wc -l)

if [ "$BACKUP_COUNT" -gt 7 ]; then
    DELETE_COUNT=$((BACKUP_COUNT - 7))
    echo "[!] Lösche die $DELETE_COUNT ältesten Backups..."
    ls -1t "$BACKUP_DIR"/*.tar.gz | tail -n "$DELETE_COUNT" | xargs rm -f
    echo "[+] Alte Backups gelöscht!"
else
    echo "[✅] Es sind weniger als 7 Backups vorhanden – kein Löschen nötig."
fi

# Temporäre Dateien löschen
rm -rf "$BACKUP_PATH"

echo "[✅] Backup abgeschlossen!"
