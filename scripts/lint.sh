#!/bin/bash

# BlockchainCore Linting Script
# Runs all code quality checks in the correct order

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored output
print_header() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                BlockchainCore Code Quality                   ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we're in the right directory
check_directory() {
    if [ ! -f "requirements.txt" ] || [ ! -d "src" ]; then
        print_error "Please run this script from the project root directory"
        exit 1
    fi
}

# Check if required tools are installed
check_dependencies() {
    print_status "Checking dependencies..."
    
    # Check Python
    if ! command -v python3 &> /dev/null; then
        print_error "Python 3 is required but not installed"
        exit 1
    fi
    
    # Check pip packages
    if ! command -v black &> /dev/null; then
        print_error "Black is not installed. Run: pip install -r requirements.txt"
        exit 1
    fi
    
    if ! command -v isort &> /dev/null; then
        print_error "isort is not installed. Run: pip install -r requirements.txt"
        exit 1
    fi
    
    if ! command -v flake8 &> /dev/null; then
        print_error "flake8 is not installed. Run: pip install -r requirements.txt"
        exit 1
    fi
    
    if ! command -v mypy &> /dev/null; then
        print_error "mypy is not installed. Run: pip install -r requirements.txt"
        exit 1
    fi
    
    print_success "All dependencies found"
}

# Run Black formatting
run_black() {
    print_status "Running Black code formatter..."
    
    if black --check src/ tests/ 2>/dev/null; then
        print_success "Black: Code is properly formatted"
    else
        print_warning "Black: Code needs formatting"
        print_status "Running Black to format code..."
        black src/ tests/
        print_success "Black: Code formatted successfully"
    fi
}

# Run isort import sorting
run_isort() {
    print_status "Running isort import sorter..."
    
    if isort --check-only src/ tests/ 2>/dev/null; then
        print_success "isort: Imports are properly sorted"
    else
        print_warning "isort: Imports need sorting"
        print_status "Running isort to sort imports..."
        isort src/ tests/
        print_success "isort: Imports sorted successfully"
    fi
}

# Run flake8 linting
run_flake8() {
    print_status "Running flake8 linting..."
    
    if flake8 src/ tests/; then
        print_success "flake8: No linting issues found"
    else
        print_error "flake8: Linting issues found"
        print_status "Please fix the issues above and run again"
        exit 1
    fi
}

# Run mypy type checking
run_mypy() {
    print_status "Running mypy type checking..."
    
    if mypy src/; then
        print_success "mypy: No type issues found"
    else
        print_error "mypy: Type checking issues found"
        print_status "Please fix the issues above and run again"
        exit 1
    fi
}

# Main execution
main() {
    print_header
    
    # Check environment
    check_directory
    check_dependencies
    
    echo "Starting code quality checks..."
    echo ""
    
    # Run checks in order
    run_black
    echo ""
    
    run_isort
    echo ""
    
    run_flake8
    echo ""
    
    run_mypy
    echo ""
    
    # Success message
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                    🎉 All Checks Passed! 🎉                  ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    print_success "Code quality checks completed successfully!"
    print_success "Your code is ready for commit and deployment!"
}

# Handle command line arguments
case "${1:-}" in
    --check-only)
        print_status "Running in check-only mode (no auto-fixing)..."
        # Override functions to only check, not fix
        run_black() {
            print_status "Running Black code formatter (check only)..."
            if black --check src/ tests/; then
                print_success "Black: Code is properly formatted"
            else
                print_error "Black: Code needs formatting"
                exit 1
            fi
        }
        
        run_isort() {
            print_status "Running isort import sorter (check only)..."
            if isort --check-only src/ tests/; then
                print_success "isort: Imports are properly sorted"
            else
                print_error "isort: Imports need sorting"
                exit 1
            fi
        }
        ;;
    
    --help|-h)
        echo "BlockchainCore Linting Script"
        echo ""
        echo "Usage:"
        echo "  ./scripts/lint.sh          - Run all checks and auto-fix what's possible"
        echo "  ./scripts/lint.sh --check-only - Run all checks without auto-fixing"
        echo "  ./scripts/lint.sh --help   - Show this help message"
        echo ""
        echo "This script runs:"
        echo "  - Black (code formatting)"
        echo "  - isort (import sorting)"
        echo "  - flake8 (linting)"
        echo "  - mypy (type checking)"
        exit 0
        ;;
esac

# Run main function
main "$@"
