# AWS S3 User Access Guide

## Overview
This guide explains how to grant an AWS IAM user access to an S3 bucket.

## Method 1: Using IAM User Policy (Recommended)

### Step 1: Create IAM Policy JSON

Save this policy as `s3-bucket-access-policy.json` (customize the bucket name and permissions):

```json
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
            "Resource": "arn:aws:s3:::YOUR-BUCKET-NAME"
        },
        {
            "Sid": "ObjectAccess",
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:DeleteObject"
            ],
            "Resource": "arn:aws:s3:::YOUR-BUCKET-NAME/*"
        }
    ]
}
```

### Step 2: Attach Policy to User

#### Using AWS CLI:
```bash
# Create the policy
aws iam create-policy \
    --policy-name S3BucketAccessPolicy \
    --policy-document file://s3-bucket-access-policy.json

# Attach policy to user
aws iam attach-user-policy \
    --user-name YOUR-USERNAME \
    --policy-arn arn:aws:iam::YOUR-ACCOUNT-ID:policy/S3BucketAccessPolicy
```

#### Using AWS Console:
1. Go to IAM Console → Users
2. Select your user
3. Click "Add permissions" → "Attach policies directly"
4. Create a new policy or attach existing one

## Method 2: Using Bucket Policy

Add this policy directly to the S3 bucket:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllowUserAccess",
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::YOUR-ACCOUNT-ID:user/YOUR-USERNAME"
            },
            "Action": [
                "s3:ListBucket",
                "s3:GetBucketLocation"
            ],
            "Resource": "arn:aws:s3:::YOUR-BUCKET-NAME"
        },
        {
            "Sid": "AllowObjectAccess",
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::YOUR-ACCOUNT-ID:user/YOUR-USERNAME"
            },
            "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:DeleteObject"
            ],
            "Resource": "arn:aws:s3:::YOUR-BUCKET-NAME/*"
        }
    ]
}
```

#### Using AWS CLI:
```bash
aws s3api put-bucket-policy \
    --bucket YOUR-BUCKET-NAME \
    --policy file://bucket-policy.json
```

## Common Permission Levels

### Read-Only Access:
```json
{
    "Action": [
        "s3:ListBucket",
        "s3:GetObject"
    ]
}
```

### Read-Write Access:
```json
{
    "Action": [
        "s3:ListBucket",
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
    ]
}
```

### Full Access:
```json
{
    "Action": "s3:*"
}
```

## Verification

Test access with AWS CLI:
```bash
# List bucket contents
aws s3 ls s3://YOUR-BUCKET-NAME/

# Upload a test file
aws s3 cp test.txt s3://YOUR-BUCKET-NAME/

# Download a file
aws s3 cp s3://YOUR-BUCKET-NAME/test.txt ./
```

## For Snowflake Integration

If you're granting access for Snowflake external stages or storage integrations:

```sql
-- Create storage integration in Snowflake
CREATE STORAGE INTEGRATION s3_integration
  TYPE = EXTERNAL_STAGE
  STORAGE_PROVIDER = S3
  ENABLED = TRUE
  STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::YOUR-ACCOUNT-ID:role/YOUR-ROLE'
  STORAGE_ALLOWED_LOCATIONS = ('s3://YOUR-BUCKET-NAME/');

-- Get Snowflake IAM user ARN
DESC STORAGE INTEGRATION s3_integration;
```

Then update your S3 bucket policy to include the Snowflake IAM user ARN.

## Troubleshooting

1. **Access Denied**: Check both IAM policy and bucket policy
2. **Invalid Principal**: Verify the user ARN is correct
3. **Bucket Not Found**: Ensure the bucket name and region are correct

## Replace These Values:
- `YOUR-BUCKET-NAME`: Your S3 bucket name
- `YOUR-USERNAME`: AWS IAM username
- `YOUR-ACCOUNT-ID`: Your AWS account ID (12 digits)
- Permissions: Adjust actions based on your needs (read, write, delete)



