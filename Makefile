# BlockchainCore Makefile
# Common development tasks and shortcuts

.PHONY: help install test lint format clean deploy-infra deploy-lambda start-producer docker-up docker-down

# Default target
help:
	@echo "BlockchainCore - Real-Time Blockchain Data Analytics on AWS"
	@echo ""
	@echo "Available commands:"
	@echo "  install        - Install Python dependencies"
	@echo "  test           - Run tests"
	@echo "  lint           - Run linting checks"
	@echo "  format         - Format code with black and isort"
	@echo "  clean          - Clean build artifacts"
	@echo "  deploy-infra   - Deploy AWS infrastructure with Terraform"
	@echo "  deploy-lambda  - Deploy Lambda functions"
	@echo "  start-producer - Start the data producer"
	@echo "  docker-up      - Start local development environment"
	@echo "  docker-down    - Stop local development environment"
	@echo "  setup          - Complete project setup"

# Install dependencies
install:
	@echo "Installing Python dependencies..."
	pip install -r requirements.txt

# Run tests
test:
	@echo "Running tests..."
	pytest tests/ -v --cov=src --cov-report=html --cov-report=term

# Run linting
lint:
	@echo "Running linting checks..."
	flake8 src/ tests/
	black --check src/ tests/
	isort --check-only src/ tests/
	mypy src/

# Format code
format:
	@echo "Formatting code..."
	black src/ tests/
	isort src/ tests/

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	rm -rf src/lambda/*/build/
	rm -rf src/lambda/*/*.zip
	rm -rf .pytest_cache/
	rm -rf htmlcov/
	rm -rf .coverage
	find . -type d -name "__pycache__" -exec rm -rf {} +
	find . -type f -name "*.pyc" -delete

# Deploy infrastructure
deploy-infra:
	@echo "Deploying AWS infrastructure..."
	cd terraform && terraform init
	cd terraform && terraform plan
	cd terraform && terraform apply -auto-approve

# Deploy Lambda functions
deploy-lambda:
	@echo "Deploying Lambda functions..."
	./scripts/deploy-lambda.sh

# Start data producer
start-producer:
	@echo "Starting data producer..."
	python src/producer/main.py

# Docker commands
docker-up:
	@echo "Starting local development environment..."
	docker-compose up -d

docker-down:
	@echo "Stopping local development environment..."
	docker-compose down

# Complete setup
setup: install
	@echo "Setting up BlockchainCore project..."
	@echo "1. Installing dependencies..."
	@echo "2. Setting up pre-commit hooks..."
	pre-commit install
	@echo "3. Creating necessary directories..."
	mkdir -p logs
	mkdir -p data
	@echo "Setup complete! Run 'make help' for available commands."

# Development workflow
dev: format lint test

# Production deployment
prod: clean test lint deploy-infra deploy-lambda

# Local development
local: docker-up
	@echo "Local development environment started!"
	@echo "Access services at:"
	@echo "  - Jupyter: http://localhost:8888"
	@echo "  - Grafana: http://localhost:3000"
	@echo "  - Prometheus: http://localhost:9090"

# Stop local development
local-stop: docker-down
	@echo "Local development environment stopped!"

# Show project status
status:
	@echo "BlockchainCore Project Status"
	@echo "============================"
	@echo "Python version: $(shell python --version)"
	@echo "AWS CLI version: $(shell aws --version 2>/dev/null || echo 'Not installed')"
	@echo "Terraform version: $(shell terraform --version 2>/dev/null | head -n1 || echo 'Not installed')"
	@echo "Docker version: $(shell docker --version 2>/dev/null || echo 'Not installed')"
	@echo ""
	@echo "AWS credentials: $(shell aws sts get-caller-identity --query 'Account' --output text 2>/dev/null || echo 'Not configured')"
	@echo ""
	@echo "Installed packages:"
	@pip list | grep -E "(boto3|websockets|pandas|numpy)" || echo "No key packages found"

# Backup and restore
backup:
	@echo "Creating backup..."
	tar -czf backup-$(shell date +%Y%m%d-%H%M%S).tar.gz \
		--exclude='.git' \
		--exclude='node_modules' \
		--exclude='__pycache__' \
		--exclude='*.pyc' \
		--exclude='.pytest_cache' \
		--exclude='htmlcov' \
		--exclude='.coverage' \
		.

# Security checks
security:
	@echo "Running security checks..."
	bandit -r src/ -f json -o security-report.json || true
	@echo "Security report generated: security-report.json"

# Performance testing
perf-test:
	@echo "Running performance tests..."
	python -m pytest tests/test_performance.py -v

# Documentation
docs:
	@echo "Generating documentation..."
	pdoc --html src/ --output-dir docs/
	@echo "Documentation generated in docs/"

# Environment setup
env-setup:
	@echo "Setting up environment variables..."
	@if [ ! -f .env ]; then \
		echo "Creating .env file..."; \
		cp .env.example .env 2>/dev/null || echo "No .env.example found"; \
	fi
	@echo "Please update .env file with your configuration"

# Quick start
quickstart: env-setup install docker-up
	@echo "Quick start complete!"
	@echo "Next steps:"
	@echo "1. Update .env file with your AWS credentials"
	@echo "2. Run 'make deploy-infra' to deploy to AWS"
	@echo "3. Run 'make start-producer' to start data ingestion"
