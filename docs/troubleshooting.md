# Troubleshooting Guide

This guide covers common issues and their solutions for the BlockchainCore project.

## Specific Issues & Solutions

### 1. Producer Hanging on WebSocket Connection

- **Issue**: Producer hangs indefinitely when connecting to Binance WebSocket
- **Solution**: Use `simple_producer.py` instead of complex async context managers
- **Check**: Verify WebSocket connectivity with `test_websocket.py`

### 2. DynamoDB Float Type Error

- **Issue**: Lambda fails with "Float types are not supported. Use Decimal types instead"
- **Solution**: Convert all float values to Decimal using `Decimal(str(value))`
- **Check**: Ensure processor Lambda uses Decimal types for OHLCV data

### 3. SQS Queue Not Receiving Data

- **Issue**: Messages not appearing in SQS queue
- **Solution**: Verify `SQS_QUEUE_URL` environment variable is set correctly
- **Check**: Run `aws sqs get-queue-attributes` to see message counts

### 4. Lambda Function Not Processing Messages

- **Issue**: SQS messages stuck in "NotVisible" state
- **Solution**: Check Lambda function logs in CloudWatch
- **Check**: Verify IAM permissions for SQS, S3, and DynamoDB access

### 5. Producer WebSocket Connection Issues

- **Issue**: Cannot connect to Binance WebSocket
- **Solution**: Test with `minimal_test.py` to isolate network issues
- **Check**: Ensure no firewall blocking WebSocket connections

### 6. Script Files Missing or Deleted

- **Issue**: Script files accidentally deleted during development
- **Solution**: Recreate scripts with improved organization and functionality
- **Check**: Verify all scripts exist in `scripts/` and `scripts/subscripts/` directories

### 7. Start Script Producer Path Error

- **Issue**: `./scripts/subscripts/start-producer.sh: No such file or directory`
- **Solution**: Ensure all subscripts are created and executable
- **Check**: Run `chmod +x scripts/subscripts/*.sh` to make scripts executable

### 8. Python Environment Mismatch in Scripts

- **Issue**: Scripts using `python3` instead of `python` (Anaconda environment)
- **Solution**: Update scripts to use correct Python interpreter
- **Check**: Verify `which python` points to correct environment with required packages

### 9. S3 Bucket Cleanup Taking Too Long

- **Issue**: Shutdown script hanging on S3 bucket cleanup with many versions
- **Solution**: Use fast shutdown option or add `force_destroy = true` to S3 bucket
- **Check**: Terraform configuration includes `force_destroy = true` for S3 bucket

## Getting Help

For additional support:

- Create a GitHub issue
- Review CloudWatch logs for detailed error information
- Check the main [README.md](../README.md) for general setup and configuration
