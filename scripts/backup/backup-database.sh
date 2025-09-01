#!/bin/bash

# Vanta X Database Backup Script
# This script performs automated database backups with rotation

set -euo pipefail

# Configuration
BACKUP_DIR="${BACKUP_DIR:-/var/backups/vantax}"
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-vantax}"
DB_USER="${DB_USER:-vantax}"
RETENTION_DAYS="${RETENTION_DAYS:-30}"
S3_BUCKET="${S3_BUCKET:-vantax-backups}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="vantax_backup_${TIMESTAMP}.sql.gz"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" >&2
}

warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

# Create backup directory if it doesn't exist
mkdir -p "${BACKUP_DIR}"

# Function to perform database backup
perform_backup() {
    log "Starting database backup..."
    
    # Use pg_dump to create backup
    PGPASSWORD="${DB_PASSWORD}" pg_dump \
        -h "${DB_HOST}" \
        -p "${DB_PORT}" \
        -U "${DB_USER}" \
        -d "${DB_NAME}" \
        --verbose \
        --no-owner \
        --no-acl \
        --format=plain \
        --encoding=UTF8 | gzip > "${BACKUP_DIR}/${BACKUP_FILE}"
    
    if [ $? -eq 0 ]; then
        log "Database backup completed: ${BACKUP_FILE}"
        
        # Get backup size
        BACKUP_SIZE=$(du -h "${BACKUP_DIR}/${BACKUP_FILE}" | cut -f1)
        log "Backup size: ${BACKUP_SIZE}"
    else
        error "Database backup failed!"
        exit 1
    fi
}

# Function to upload to S3
upload_to_s3() {
    if [ -n "${AWS_ACCESS_KEY_ID:-}" ] && [ -n "${S3_BUCKET}" ]; then
        log "Uploading backup to S3..."
        
        aws s3 cp "${BACKUP_DIR}/${BACKUP_FILE}" "s3://${S3_BUCKET}/database/${BACKUP_FILE}" \
            --storage-class STANDARD_IA
        
        if [ $? -eq 0 ]; then
            log "Backup uploaded to S3 successfully"
        else
            warning "Failed to upload backup to S3"
        fi
    else
        warning "S3 configuration not found, skipping cloud backup"
    fi
}

# Function to clean old backups
cleanup_old_backups() {
    log "Cleaning up old backups..."
    
    # Local cleanup
    find "${BACKUP_DIR}" -name "vantax_backup_*.sql.gz" -mtime +${RETENTION_DAYS} -delete
    
    # S3 cleanup
    if [ -n "${AWS_ACCESS_KEY_ID:-}" ] && [ -n "${S3_BUCKET}" ]; then
        aws s3 ls "s3://${S3_BUCKET}/database/" | while read -r line; do
            createDate=$(echo $line | awk '{print $1" "$2}')
            createDate=$(date -d "$createDate" +%s)
            olderThan=$(date -d "${RETENTION_DAYS} days ago" +%s)
            if [[ $createDate -lt $olderThan ]]; then
                fileName=$(echo $line | awk '{print $4}')
                if [[ $fileName == vantax_backup_*.sql.gz ]]; then
                    aws s3 rm "s3://${S3_BUCKET}/database/${fileName}"
                    log "Deleted old backup from S3: ${fileName}"
                fi
            fi
        done
    fi
}

# Function to verify backup
verify_backup() {
    log "Verifying backup integrity..."
    
    # Test if the file can be unzipped
    if gzip -t "${BACKUP_DIR}/${BACKUP_FILE}" 2>/dev/null; then
        log "Backup file integrity verified"
        
        # Get line count for verification
        LINE_COUNT=$(zcat "${BACKUP_DIR}/${BACKUP_FILE}" | wc -l)
        log "Backup contains ${LINE_COUNT} lines"
    else
        error "Backup file is corrupted!"
        exit 1
    fi
}

# Function to send notification
send_notification() {
    local status=$1
    local message=$2
    
    # Send to monitoring system (example with curl to webhook)
    if [ -n "${WEBHOOK_URL:-}" ]; then
        curl -X POST "${WEBHOOK_URL}" \
            -H "Content-Type: application/json" \
            -d "{
                \"text\": \"Database Backup ${status}\",
                \"attachments\": [{
                    \"color\": \"$([ \"$status\" = \"SUCCESS\" ] && echo \"good\" || echo \"danger\")\",
                    \"fields\": [{
                        \"title\": \"Database\",
                        \"value\": \"${DB_NAME}\",
                        \"short\": true
                    }, {
                        \"title\": \"Backup File\",
                        \"value\": \"${BACKUP_FILE}\",
                        \"short\": true
                    }, {
                        \"title\": \"Message\",
                        \"value\": \"${message}\",
                        \"short\": false
                    }]
                }]
            }" 2>/dev/null || true
    fi
}

# Main execution
main() {
    log "=== Vanta X Database Backup Script ==="
    log "Database: ${DB_NAME}@${DB_HOST}:${DB_PORT}"
    
    # Check prerequisites
    command -v pg_dump >/dev/null 2>&1 || { error "pg_dump is not installed"; exit 1; }
    command -v gzip >/dev/null 2>&1 || { error "gzip is not installed"; exit 1; }
    
    # Perform backup
    perform_backup
    
    # Verify backup
    verify_backup
    
    # Upload to S3
    upload_to_s3
    
    # Clean old backups
    cleanup_old_backups
    
    # Send success notification
    send_notification "SUCCESS" "Database backup completed successfully. File: ${BACKUP_FILE}"
    
    log "=== Backup process completed successfully ==="
}

# Error handling
trap 'error "Backup script failed on line $LINENO"; send_notification "FAILED" "Backup failed with error on line $LINENO"' ERR

# Run main function
main "$@"