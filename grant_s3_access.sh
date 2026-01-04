#!/bin/bash

# AWS S3 User Access Grant Script
# This script helps you grant an AWS IAM user access to an S3 bucket

# Configuration - UPDATE THESE VALUES
BUCKET_NAME="YOUR-BUCKET-NAME"
IAM_USERNAME="YOUR-USERNAME"
AWS_ACCOUNT_ID="YOUR-ACCOUNT-ID"
POLICY_NAME="S3BucketAccessPolicy"

echo "=========================================="
echo "AWS S3 User Access Grant Script"
echo "=========================================="
echo ""
echo "Configuration:"
echo "  Bucket: $BUCKET_NAME"
echo "  User: $IAM_USERNAME"
echo "  Account: $AWS_ACCOUNT_ID"
echo ""

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "ERROR: AWS CLI is not installed."
    echo "Install it using: pip install awscli"
    exit 1
fi

# Check if user has AWS credentials configured
if ! aws sts get-caller-identity &> /dev/null; then
    echo "ERROR: AWS credentials not configured."
    echo "Run: aws configure"
    exit 1
fi

echo "Select method to grant access:"
echo "1) IAM User Policy (Recommended)"
echo "2) S3 Bucket Policy"
echo "3) Both"
echo ""
read -p "Enter choice (1-3): " choice

case $choice in
    1|3)
        echo ""
        echo "Creating IAM policy..."
        
        # Create policy document
        cat > /tmp/s3-policy.json <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "ListBucket",
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket",
                "s3:GetBucketLocation"
            ],
            "Resource": "arn:aws:s3:::${BUCKET_NAME}"
        },
        {
            "Sid": "ObjectAccess",
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:DeleteObject"
            ],
            "Resource": "arn:aws:s3:::${BUCKET_NAME}/*"
        }
    ]
}
EOF
        
        # Create policy
        POLICY_ARN=$(aws iam create-policy \
            --policy-name ${POLICY_NAME} \
            --policy-document file:///tmp/s3-policy.json \
            --query 'Policy.Arn' \
            --output text 2>/dev/null)
        
        if [ -z "$POLICY_ARN" ]; then
            echo "Policy may already exist, attempting to get ARN..."
            POLICY_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${POLICY_NAME}"
        fi
        
        echo "Policy ARN: $POLICY_ARN"
        
        # Attach policy to user
        echo "Attaching policy to user..."
        aws iam attach-user-policy \
            --user-name ${IAM_USERNAME} \
            --policy-arn ${POLICY_ARN}
        
        if [ $? -eq 0 ]; then
            echo "✓ Successfully attached policy to user"
        else
            echo "✗ Failed to attach policy to user"
        fi
        ;;
esac

case $choice in
    2|3)
        echo ""
        echo "Creating S3 bucket policy..."
        
        # Create bucket policy document
        cat > /tmp/bucket-policy.json <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllowUserAccess",
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::${AWS_ACCOUNT_ID}:user/${IAM_USERNAME}"
            },
            "Action": [
                "s3:ListBucket",
                "s3:GetBucketLocation"
            ],
            "Resource": "arn:aws:s3:::${BUCKET_NAME}"
        },
        {
            "Sid": "AllowObjectAccess",
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::${AWS_ACCOUNT_ID}:user/${IAM_USERNAME}"
            },
            "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:DeleteObject"
            ],
            "Resource": "arn:aws:s3:::${BUCKET_NAME}/*"
        }
    ]
}
EOF
        
        # Apply bucket policy
        aws s3api put-bucket-policy \
            --bucket ${BUCKET_NAME} \
            --policy file:///tmp/bucket-policy.json
        
        if [ $? -eq 0 ]; then
            echo "✓ Successfully applied bucket policy"
        else
            echo "✗ Failed to apply bucket policy"
        fi
        ;;
esac

echo ""
echo "=========================================="
echo "Testing Access..."
echo "=========================================="

# Test access
echo "Attempting to list bucket contents..."
aws s3 ls s3://${BUCKET_NAME}/ --profile default 2>&1

echo ""
echo "Done! Access has been granted."
echo ""
echo "To test as the user, run:"
echo "  aws s3 ls s3://${BUCKET_NAME}/"



