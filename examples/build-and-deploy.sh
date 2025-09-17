#!/bin/bash

# SQL Exporter - Build and Deploy Script
# This script helps build Docker images and deploy to Kubernetes

set -e

# Configuration
DOCKER_REGISTRY="${DOCKER_REGISTRY:-localhost:5000}"
IMAGE_NAME="${IMAGE_NAME:-sql-exporter}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
NAMESPACE="${K8S_NAMESPACE:-monitoring}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Build Docker image
build_image() {
    log "Building Docker image..."
    docker build -t "${IMAGE_NAME}:${IMAGE_TAG}" .

    if [ ! -z "$DOCKER_REGISTRY" ] && [ "$DOCKER_REGISTRY" != "localhost:5000" ]; then
        log "Tagging image for registry..."
        docker tag "${IMAGE_NAME}:${IMAGE_TAG}" "${DOCKER_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
    fi

    log "Docker image built successfully"
}

# Push Docker image
push_image() {
    if [ ! -z "$DOCKER_REGISTRY" ] && [ "$DOCKER_REGISTRY" != "localhost:5000" ]; then
        log "Pushing image to registry..."
        docker push "${DOCKER_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
        log "Image pushed successfully"
    else
        warn "No registry specified or using local registry, skipping push"
    fi
}

# Deploy to Kubernetes
deploy_k8s() {
    log "Deploying to Kubernetes..."

    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        error "kubectl is not installed or not in PATH"
        exit 1
    fi

    # Create namespace if it doesn't exist
    kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

    # Update image in kustomization.yaml if using registry
    if [ ! -z "$DOCKER_REGISTRY" ] && [ "$DOCKER_REGISTRY" != "localhost:5000" ]; then
        log "Updating image reference in kustomization.yaml..."
        cd k8s
        kustomize edit set image sql-exporter="${DOCKER_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
        cd ..
    fi

    # Apply manifests
    log "Applying Kubernetes manifests..."
    kubectl apply -k k8s

    # Wait for deployment to be ready
    log "Waiting for deployment to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/sql-exporter -n "$NAMESPACE"

    log "Deployment completed successfully"

    # Show status
    kubectl get pods -n "$NAMESPACE" -l app=sql-exporter
}

# Deploy using docker-compose
deploy_compose() {
    log "Deploying with Docker Compose..."

    # Check if docker-compose is available
    if ! command -v docker-compose &> /dev/null; then
        error "docker-compose is not installed or not in PATH"
        exit 1
    fi

    # Start services
    docker-compose up -d

    log "Docker Compose deployment completed"

    # Show status
    docker-compose ps
}

# Test deployment
test_deployment() {
    log "Testing deployment..."

    # Test with kubectl port-forward for K8s
    if command -v kubectl &> /dev/null; then
        log "Testing Kubernetes deployment..."
        kubectl port-forward -n "$NAMESPACE" svc/sql-exporter-service 9090:9090 &
        PORT_FORWARD_PID=$!

        sleep 5

        if curl -s http://localhost:9090/metrics > /dev/null; then
            log "Kubernetes deployment test passed"
        else
            warn "Kubernetes deployment test failed"
        fi

        kill $PORT_FORWARD_PID 2>/dev/null || true
    fi

    # Test Docker Compose deployment
    if docker-compose ps sql-exporter | grep -q "Up"; then
        log "Testing Docker Compose deployment..."
        if curl -s http://localhost:9090/metrics > /dev/null; then
            log "Docker Compose deployment test passed"
        else
            warn "Docker Compose deployment test failed"
        fi
    fi
}

# Clean up resources
cleanup() {
    log "Cleaning up..."

    # Clean up Kubernetes resources
    if command -v kubectl &> /dev/null; then
        kubectl delete -k k8s --ignore-not-found=true
    fi

    # Clean up Docker Compose
    if command -v docker-compose &> /dev/null; then
        docker-compose down -v
    fi

    # Remove Docker images
    docker rmi "${IMAGE_NAME}:${IMAGE_TAG}" 2>/dev/null || true
    if [ ! -z "$DOCKER_REGISTRY" ] && [ "$DOCKER_REGISTRY" != "localhost:5000" ]; then
        docker rmi "${DOCKER_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}" 2>/dev/null || true
    fi

    log "Cleanup completed"
}

# Show help
show_help() {
    echo "SQL Exporter - Build and Deploy Script"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  build       Build Docker image"
    echo "  push        Push Docker image to registry"
    echo "  deploy-k8s  Deploy to Kubernetes"
    echo "  deploy-compose Deploy with Docker Compose"
    echo "  test        Test deployment"
    echo "  cleanup     Clean up resources"
    echo "  all         Build, push, and deploy to Kubernetes"
    echo "  help        Show this help message"
    echo ""
    echo "Environment variables:"
    echo "  DOCKER_REGISTRY   Docker registry URL (default: localhost:5000)"
    echo "  IMAGE_NAME        Docker image name (default: sql-exporter)"
    echo "  IMAGE_TAG         Docker image tag (default: latest)"
    echo "  K8S_NAMESPACE     Kubernetes namespace (default: monitoring)"
    echo ""
    echo "Examples:"
    echo "  $0 build"
    echo "  DOCKER_REGISTRY=my-registry.com $0 all"
    echo "  $0 deploy-compose"
}

# Main script logic
case "${1:-help}" in
    build)
        build_image
        ;;
    push)
        push_image
        ;;
    deploy-k8s)
        deploy_k8s
        ;;
    deploy-compose)
        deploy_compose
        ;;
    test)
        test_deployment
        ;;
    cleanup)
        cleanup
        ;;
    all)
        build_image
        push_image
        deploy_k8s
        test_deployment
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac