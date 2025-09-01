#!/bin/bash

# Vanta X - System Health Check Script
# Monitors the health of all services and components

set -e

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
API_GATEWAY_URL="${API_GATEWAY_URL:-http://localhost:4000}"
WEB_APP_URL="${WEB_APP_URL:-http://localhost:3000}"
GRAFANA_URL="${GRAFANA_URL:-http://localhost:3001}"

# Health check results
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNINGS=0

print_header() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║              Vanta X - System Health Check                       ║"
    echo "║                    $(date +"%Y-%m-%d %H:%M:%S")                          ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

check_service() {
    local service_name=$1
    local check_command=$2
    local expected_result=$3
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    echo -n "Checking $service_name... "
    
    if eval "$check_command" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ HEALTHY${NC}"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
        return 0
    else
        echo -e "${RED}✗ UNHEALTHY${NC}"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        return 1
    fi
}

check_docker_service() {
    local container_name=$1
    local service_name=$2
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    echo -n "Checking $service_name... "
    
    if docker ps --format '{{.Names}}' | grep -q "^${container_name}$"; then
        # Check if container is running
        status=$(docker inspect -f '{{.State.Status}}' "$container_name" 2>/dev/null)
        if [ "$status" = "running" ]; then
            # Check container health if available
            health=$(docker inspect -f '{{.State.Health.Status}}' "$container_name" 2>/dev/null || echo "none")
            if [ "$health" = "healthy" ] || [ "$health" = "none" ]; then
                echo -e "${GREEN}✓ RUNNING${NC}"
                PASSED_CHECKS=$((PASSED_CHECKS + 1))
                return 0
            else
                echo -e "${YELLOW}⚠ RUNNING (health: $health)${NC}"
                WARNINGS=$((WARNINGS + 1))
                return 1
            fi
        else
            echo -e "${RED}✗ NOT RUNNING (status: $status)${NC}"
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
            return 1
        fi
    else
        echo -e "${RED}✗ NOT FOUND${NC}"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        return 1
    fi
}

check_http_endpoint() {
    local endpoint_name=$1
    local url=$2
    local expected_code=${3:-200}
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    echo -n "Checking $endpoint_name... "
    
    if command -v curl &> /dev/null; then
        response_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "$url" || echo "000")
        
        if [ "$response_code" = "$expected_code" ]; then
            echo -e "${GREEN}✓ ACCESSIBLE (HTTP $response_code)${NC}"
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
            return 0
        elif [ "$response_code" = "000" ]; then
            echo -e "${RED}✗ UNREACHABLE${NC}"
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
            return 1
        else
            echo -e "${YELLOW}⚠ ACCESSIBLE (HTTP $response_code, expected $expected_code)${NC}"
            WARNINGS=$((WARNINGS + 1))
            return 1
        fi
    else
        echo -e "${YELLOW}⚠ SKIPPED (curl not installed)${NC}"
        WARNINGS=$((WARNINGS + 1))
        return 1
    fi
}

check_database() {
    local db_name=$1
    local db_host=${2:-localhost}
    local db_port=${3:-5432}
    local db_user=${4:-vantax_user}
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    echo -n "Checking PostgreSQL database... "
    
    if docker exec vantax-postgres pg_isready -h localhost -U "$db_user" > /dev/null 2>&1; then
        # Check if database exists
        if docker exec vantax-postgres psql -U "$db_user" -lqt | cut -d \| -f 1 | grep -qw "$db_name"; then
            echo -e "${GREEN}✓ READY${NC}"
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
            return 0
        else
            echo -e "${YELLOW}⚠ RUNNING (database '$db_name' not found)${NC}"
            WARNINGS=$((WARNINGS + 1))
            return 1
        fi
    else
        echo -e "${RED}✗ NOT READY${NC}"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        return 1
    fi
}

check_redis() {
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    echo -n "Checking Redis cache... "
    
    if docker exec vantax-redis redis-cli ping > /dev/null 2>&1; then
        echo -e "${GREEN}✓ READY${NC}"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
        return 0
    else
        echo -e "${RED}✗ NOT READY${NC}"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        return 1
    fi
}

check_disk_space() {
    local min_space_gb=${1:-10}
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    echo -n "Checking disk space... "
    
    available_space=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    
    if [ "$available_space" -ge "$min_space_gb" ]; then
        echo -e "${GREEN}✓ SUFFICIENT (${available_space}GB available)${NC}"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
        return 0
    else
        echo -e "${RED}✗ LOW SPACE (${available_space}GB available, need ${min_space_gb}GB)${NC}"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        return 1
    fi
}

check_memory() {
    local min_memory_gb=${1:-4}
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    echo -n "Checking memory... "
    
    available_memory=$(free -g | awk '/^Mem:/ {print $7}')
    total_memory=$(free -g | awk '/^Mem:/ {print $2}')
    
    if [ "$available_memory" -ge "$min_memory_gb" ]; then
        echo -e "${GREEN}✓ SUFFICIENT (${available_memory}GB available of ${total_memory}GB)${NC}"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
        return 0
    else
        echo -e "${YELLOW}⚠ LOW MEMORY (${available_memory}GB available of ${total_memory}GB)${NC}"
        WARNINGS=$((WARNINGS + 1))
        return 1
    fi
}

check_api_health() {
    local service_name=$1
    local health_endpoint=$2
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    echo -n "Checking $service_name API health... "
    
    if response=$(curl -s --connect-timeout 5 "$health_endpoint" 2>/dev/null); then
        if echo "$response" | grep -q '"status":"ok"'; then
            echo -e "${GREEN}✓ HEALTHY${NC}"
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
            return 0
        else
            echo -e "${YELLOW}⚠ DEGRADED${NC}"
            WARNINGS=$((WARNINGS + 1))
            return 1
        fi
    else
        echo -e "${RED}✗ UNREACHABLE${NC}"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        return 1
    fi
}

print_summary() {
    echo ""
    echo -e "${BLUE}══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}Health Check Summary${NC}"
    echo -e "${BLUE}══════════════════════════════════════════════════════════════════${NC}"
    
    echo "Total Checks: $TOTAL_CHECKS"
    echo -e "Passed: ${GREEN}$PASSED_CHECKS${NC}"
    echo -e "Failed: ${RED}$FAILED_CHECKS${NC}"
    echo -e "Warnings: ${YELLOW}$WARNINGS${NC}"
    
    # Calculate health score
    if [ $TOTAL_CHECKS -gt 0 ]; then
        HEALTH_SCORE=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))
        
        echo ""
        echo -n "Overall Health Score: "
        
        if [ $HEALTH_SCORE -ge 90 ]; then
            echo -e "${GREEN}${HEALTH_SCORE}% - EXCELLENT${NC}"
        elif [ $HEALTH_SCORE -ge 70 ]; then
            echo -e "${YELLOW}${HEALTH_SCORE}% - GOOD${NC}"
        elif [ $HEALTH_SCORE -ge 50 ]; then
            echo -e "${YELLOW}${HEALTH_SCORE}% - FAIR${NC}"
        else
            echo -e "${RED}${HEALTH_SCORE}% - CRITICAL${NC}"
        fi
    fi
    
    # Recommendations
    if [ $FAILED_CHECKS -gt 0 ] || [ $WARNINGS -gt 0 ]; then
        echo ""
        echo -e "${BLUE}Recommendations:${NC}"
        
        if [ $FAILED_CHECKS -gt 0 ]; then
            echo -e "${RED}• Address failed checks immediately${NC}"
            echo "  - Check service logs: docker compose logs [service-name]"
            echo "  - Restart failed services: docker compose restart [service-name]"
        fi
        
        if [ $WARNINGS -gt 0 ]; then
            echo -e "${YELLOW}• Review warnings for potential issues${NC}"
            echo "  - Monitor system resources"
            echo "  - Check service configurations"
        fi
    fi
}

# Main health check execution
main() {
    print_header
    
    echo -e "${BLUE}System Resources${NC}"
    echo "────────────────────────────────────────"
    check_disk_space 10
    check_memory 2
    
    echo ""
    echo -e "${BLUE}Infrastructure Services${NC}"
    echo "────────────────────────────────────────"
    check_docker_service "vantax-postgres" "PostgreSQL Database"
    check_docker_service "vantax-redis" "Redis Cache"
    check_docker_service "vantax-rabbitmq" "RabbitMQ Message Queue"
    
    echo ""
    echo -e "${BLUE}Core Services${NC}"
    echo "────────────────────────────────────────"
    check_docker_service "vantax-api-gateway" "API Gateway"
    check_docker_service "vantax-identity-service" "Identity Service"
    check_docker_service "vantax-operations-service" "Operations Service"
    check_docker_service "vantax-analytics-service" "Analytics Service"
    check_docker_service "vantax-ai-service" "AI Service"
    
    echo ""
    echo -e "${BLUE}Support Services${NC}"
    echo "────────────────────────────────────────"
    check_docker_service "vantax-integration-service" "Integration Service"
    check_docker_service "vantax-coop-service" "Co-op Service"
    check_docker_service "vantax-notification-service" "Notification Service"
    check_docker_service "vantax-reporting-service" "Reporting Service"
    check_docker_service "vantax-workflow-service" "Workflow Service"
    check_docker_service "vantax-audit-service" "Audit Service"
    
    echo ""
    echo -e "${BLUE}Web Services${NC}"
    echo "────────────────────────────────────────"
    check_docker_service "vantax-web-app" "Web Application"
    check_docker_service "vantax-nginx" "Nginx Proxy"
    
    echo ""
    echo -e "${BLUE}Monitoring Services${NC}"
    echo "────────────────────────────────────────"
    check_docker_service "vantax-prometheus" "Prometheus"
    check_docker_service "vantax-grafana" "Grafana"
    check_docker_service "vantax-loki" "Loki"
    
    echo ""
    echo -e "${BLUE}API Endpoints${NC}"
    echo "────────────────────────────────────────"
    check_http_endpoint "API Gateway" "$API_GATEWAY_URL/health"
    check_http_endpoint "Web Application" "$WEB_APP_URL"
    check_api_health "Identity Service" "$API_GATEWAY_URL/api/v1/auth/health"
    check_api_health "Operations Service" "$API_GATEWAY_URL/api/v1/operations/health"
    
    echo ""
    echo -e "${BLUE}Database Connectivity${NC}"
    echo "────────────────────────────────────────"
    check_database "vantax"
    check_redis
    
    print_summary
    
    # Exit with appropriate code
    if [ $FAILED_CHECKS -gt 0 ]; then
        exit 1
    elif [ $WARNINGS -gt 0 ]; then
        exit 2
    else
        exit 0
    fi
}

# Run main function
main "$@"