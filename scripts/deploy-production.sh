#!/bin/bash

# Vanta X - Trade Spend Platform Production Deployment Script
# This script handles the complete deployment process

set -euo pipefail

# Configuration
ENVIRONMENT="${1:-production}"
VERSION="${2:-latest}"
NAMESPACE="vantax-${ENVIRONMENT}"
REGISTRY="ghcr.io/your-org/vanta-x-trade-spend"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" >&2
}

warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO:${NC} $1"
}

# Pre-deployment checks
pre_deployment_checks() {
    log "=== Running pre-deployment checks ==="
    
    # Check required tools
    command -v kubectl >/dev/null 2>&1 || { error "kubectl is not installed"; exit 1; }
    command -v docker >/dev/null 2>&1 || { error "docker is not installed"; exit 1; }
    command -v helm >/dev/null 2>&1 || { error "helm is not installed"; exit 1; }
    
    # Check Kubernetes connectivity
    if ! kubectl cluster-info &>/dev/null; then
        error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    # Check namespace
    if ! kubectl get namespace ${NAMESPACE} &>/dev/null; then
        log "Creating namespace ${NAMESPACE}"
        kubectl create namespace ${NAMESPACE}
    fi
    
    log "Pre-deployment checks passed ✓"
}

# Database migration
run_database_migrations() {
    log "=== Running database migrations ==="
    
    # Create migration job
    cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: db-migration-${VERSION}
  namespace: ${NAMESPACE}
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: migrate
        image: ${REGISTRY}/migration:${VERSION}
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: vantax-secrets
              key: DATABASE_URL
        command: ["npm", "run", "migrate:deploy"]
EOF
    
    # Wait for migration to complete
    kubectl wait --for=condition=complete --timeout=300s job/db-migration-${VERSION} -n ${NAMESPACE}
    
    log "Database migrations completed ✓"
}

# Deploy services
deploy_services() {
    log "=== Deploying services ==="
    
    local services=(
        "api-gateway"
        "identity-service"
        "company-service"
        "trade-marketing-service"
        "analytics-service"
        "notification-service"
        "integration-service"
        "ai-service"
        "admin-service"
        "web-app"
        "admin-portal"
    )
    
    for service in "${services[@]}"; do
        info "Deploying ${service}..."
        
        # Update image
        kubectl set image deployment/${service} ${service}=${REGISTRY}/${service}:${VERSION} \
            -n ${NAMESPACE} --record || true
        
        # If deployment doesn't exist, create it
        if [ $? -ne 0 ]; then
            kubectl apply -f infrastructure/kubernetes/${ENVIRONMENT}/${service}.yaml
        fi
        
        # Wait for rollout
        kubectl rollout status deployment/${service} -n ${NAMESPACE} --timeout=300s
        
        log "${service} deployed successfully ✓"
    done
}

# Health checks
run_health_checks() {
    log "=== Running health checks ==="
    
    # Wait for all pods to be ready
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/part-of=vantax \
        -n ${NAMESPACE} --timeout=300s
    
    # Check API Gateway health
    local api_gateway_url=$(kubectl get service api-gateway -n ${NAMESPACE} \
        -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    
    if [ -n "${api_gateway_url}" ]; then
        for i in {1..30}; do
            if curl -s "http://${api_gateway_url}/health" | grep -q "healthy"; then
                log "API Gateway health check passed ✓"
                break
            fi
            sleep 10
        done
    fi
    
    # Check all services
    local services=(
        "identity-service:4001"
        "company-service:4002"
        "trade-marketing-service:4003"
        "analytics-service:4004"
        "ai-service:4007"
    )
    
    for service_port in "${services[@]}"; do
        local service="${service_port%:*}"
        local port="${service_port#*:}"
        
        kubectl run health-check-${service} --rm -i --restart=Never \
            --image=curlimages/curl:latest -- \
            curl -s "http://${service}:${port}/health" || true
    done
    
    log "Health checks completed ✓"
}

# Run smoke tests
run_smoke_tests() {
    log "=== Running smoke tests ==="
    
    # Create test job
    cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: smoke-tests-${VERSION}
  namespace: ${NAMESPACE}
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: smoke-tests
        image: ${REGISTRY}/tests:${VERSION}
        env:
        - name: API_URL
          value: "http://api-gateway:4000"
        command: ["npm", "run", "test:smoke"]
EOF
    
    # Wait for tests to complete
    kubectl wait --for=condition=complete --timeout=600s job/smoke-tests-${VERSION} -n ${NAMESPACE}
    
    # Check test results
    local pod_name=$(kubectl get pods -n ${NAMESPACE} -l job-name=smoke-tests-${VERSION} \
        -o jsonpath='{.items[0].metadata.name}')
    
    kubectl logs ${pod_name} -n ${NAMESPACE}
    
    log "Smoke tests completed ✓"
}

# Setup monitoring
setup_monitoring() {
    log "=== Setting up monitoring ==="
    
    # Deploy Prometheus ServiceMonitors
    kubectl apply -f infrastructure/monitoring/service-monitors.yaml
    
    # Deploy Grafana dashboards
    kubectl apply -f infrastructure/monitoring/dashboards/
    
    # Deploy alerts
    kubectl apply -f infrastructure/monitoring/alerts.yaml
    
    log "Monitoring setup completed ✓"
}

# Post-deployment tasks
post_deployment_tasks() {
    log "=== Running post-deployment tasks ==="
    
    # Clear caches
    kubectl exec -n ${NAMESPACE} deployment/api-gateway -- \
        redis-cli -h redis FLUSHDB || true
    
    # Warm up caches
    kubectl create job warm-cache-${VERSION} \
        --from=cronjob/cache-warmer -n ${NAMESPACE} || true
    
    # Send deployment notification
    if [ -n "${SLACK_WEBHOOK:-}" ]; then
        curl -X POST ${SLACK_WEBHOOK} \
            -H 'Content-type: application/json' \
            -d "{
                \"text\": \"🚀 Vanta X deployed to ${ENVIRONMENT}\",
                \"attachments\": [{
                    \"color\": \"good\",
                    \"fields\": [{
                        \"title\": \"Version\",
                        \"value\": \"${VERSION}\",
                        \"short\": true
                    }, {
                        \"title\": \"Environment\",
                        \"value\": \"${ENVIRONMENT}\",
                        \"short\": true
                    }]
                }]
            }" || true
    fi
    
    log "Post-deployment tasks completed ✓"
}

# Rollback function
rollback() {
    error "Deployment failed, initiating rollback..."
    
    kubectl rollout undo deployment --selector=app.kubernetes.io/part-of=vantax \
        -n ${NAMESPACE}
    
    error "Rollback completed. Please investigate the issue."
    exit 1
}

# Main deployment flow
main() {
    log "=== Vanta X - Trade Spend Platform Deployment ==="
    log "Environment: ${ENVIRONMENT}"
    log "Version: ${VERSION}"
    log "Namespace: ${NAMESPACE}"
    
    # Set error trap
    trap rollback ERR
    
    # Run deployment steps
    pre_deployment_checks
    run_database_migrations
    deploy_services
    run_health_checks
    run_smoke_tests
    setup_monitoring
    post_deployment_tasks
    
    log "=== Deployment completed successfully! ==="
    log "Access the platform at:"
    log "- Web App: https://vantax.com"
    log "- Admin Portal: https://admin.vantax.com"
    log "- API: https://api.vantax.com"
    log "- API Docs: https://api.vantax.com/api-docs"
}

# Run main function
main "$@"