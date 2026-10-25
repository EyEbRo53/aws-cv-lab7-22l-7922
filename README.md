# Lab 7 — Host Your CV on AWS

**Name:** Hassan Yousaf  
**Roll Number:** 22L-7922  
**Email:** l227922@lhr.nu.edu.pk  
**AWS Region:** ap-southeast-2 (Sydney)

## 1. Overview

In this lab, I hosted my CV using two AWS services: EC2 and Lambda. Both websites use the same files stored in a private S3 bucket.

The EC2 version runs on an Amazon Linux 2023 instance using Apache, while the Lambda version serves the files directly from S3 through a public Function URL.

## 2. Architecture

```text
                     Private S3 Bucket
                        cv-22l-7922
                        /site/
                           |
                  +--------+--------+
                  |                 |
              IAM Role          IAM Role
                  |                 |
                 EC2              Lambda
               Apache          Function URL
                  |                 |
                HTTP              HTTPS
                  |                 |
                  +--------+--------+
                           |
                         Browser
```

The S3 bucket contains three files:

- `site/index.html` — CV webpage
- `site/style.css` — Website styling
- `site/cv.pdf` — Downloadable CV

The bucket is private, and both EC2 and Lambda use IAM roles with read-only access to the required files.

## 3. Website Links

**EC2 Website:**  
http://16.176.169.190/

**Lambda Website:**  
https://bficwk25gle5bhlpkp5rjgphja0zciht.lambda-url.ap-southeast-2.on.aws/

**Private S3 Object:**  
https://cv-22l-7922.s3.amazonaws.com/site/index.html

Opening the S3 object directly returns HTTP 403 because public access to the bucket is blocked.

## 4. EC2 Deployment

I launched a `t3.micro` EC2 instance using Amazon Linux 2023 and installed Apache to serve the CV website.

The instance uses an IAM role to download files from the private S3 bucket. A systemd timer runs the synchronization script every five minutes, allowing changes made in S3 to appear on the EC2 website automatically.

The security group allows inbound HTTP traffic on port 80. SSH access was removed after configuration, and IMDSv2 is required for instance metadata.

**EC2 Instance ID:** `i-03da7b9c6666bf0a1`

### Synchronization logs

The following successful entries were recorded in `/var/log/cv-sync.log`:

```text
2026-10-25T17:23:14+00:00 OK: synced i-03da7b9c6666bf0a1
2026-10-25T17:31:29+00:00 OK: synced i-03da7b9c6666bf0a1
2026-10-25T17:32:03+00:00 OK: synced i-03da7b9c6666bf0a1
```

Additional EC2 test details are saved in `ec2-test-results.txt`.

## 5. IAM Permission Test

To check that the EC2 instance could not modify the S3 bucket, I attempted to upload a file from the instance:

```bash
aws s3 cp /tmp/denied-test.txt s3://cv-22l-7922/site/denied-test.txt
```

**Result:** `AccessDenied`

The upload was blocked because the EC2 IAM role does not have `s3:PutObject` permission. This confirmed that the instance could read the CV files without being allowed to change the contents of the bucket.

## 6. Lambda Deployment

I created a Python 3.12 Lambda function named `cv-func-22l-7922`.

The function retrieves the requested file from S3 and returns it through a public Function URL. It handles the HTML page, CSS file, and PDF with their appropriate content types.

The function also replaces the hosting placeholder in the HTML footer with its Lambda function name.

**Configuration:**

- Memory: 128 MB
- Timeout: 10 seconds
- Authentication: NONE (public Function URL)
- S3 access: Read-only IAM role
- CloudWatch log retention: 7 days

The function records the function name, requested path, response status, and execution time in CloudWatch.

## 7. Testing Results

I tested the websites using `curl` from AWS CloudShell.

| Test | Result |
|---|---|
| EC2 homepage | HTTP 200 |
| EC2 CSS | HTTP 200 |
| EC2 PDF | HTTP 200 |
| Lambda homepage | HTTP 200 |
| Lambda CSS | HTTP 200 |
| Lambda PDF | HTTP 200 |
| Invalid Lambda path | HTTP 404 |
| Direct S3 object access | HTTP 403 |
| EC2 S3 upload attempt | AccessDenied |

The tests confirmed that both websites could serve the CV while the S3 bucket remained private.

The AWS configuration and command outputs are saved in `evidence.txt`, generated using `collect-evidence.sh`.

## 8. Lab Questions

### Q1. Why use IAM roles instead of access keys?

IAM roles provide temporary credentials to EC2 and Lambda without storing access keys in the application code. This is safer because there are no permanent credentials to expose accidentally. Permissions can also be limited to exactly what the application needs.

### Q2. What happens when someone opens the S3 object URL directly?

They receive HTTP 403 (AccessDenied). The S3 bucket has Block Public Access enabled, so its files cannot be accessed directly by anonymous users.

### Q3. Why is the Lambda Function URL public while the S3 bucket is private?

The Function URL needs to be public so visitors can open the CV without signing in to AWS. The bucket remains private because visitors should access the files through the Lambda function, not directly through S3. Lambda uses its IAM role to read only the required files.

### Q4. How do EC2 and Lambda compare in terms of idle cost and increasing traffic?

EC2 can incur charges while the instance is running, even when nobody visits the website. Lambda generally charges based on requests and execution time, so it can be more economical for a website with very little traffic.

When traffic increases, Lambda can automatically handle more concurrent requests within its service limits. A single EC2 instance has fixed resources and may need additional instances or scaling configuration to handle heavier traffic.

### Q5. What happens if the EC2 instance is deleted?

The EC2-hosted website becomes unavailable because Apache and the local CV files were running on that instance. Its public IP address is also lost.

However, the files in S3 and the Lambda website remain available because they are separate AWS resources. A new EC2 instance could be configured to download the same CV files again.

## 9. Repository Files

| File or folder | Purpose |
|---|---|
| `site/` | HTML, CSS, and PDF CV files |
| `ec2/` | EC2 setup and synchronization scripts |
| `lambda/` | Python Lambda function |
| `iam/` | IAM trust and permission policies |
| `collect-evidence.sh` | Collects AWS configuration and test results |
| `evidence.txt` | Collected deployment evidence |
| `ec2-test-results.txt` | Recorded EC2 tests |
| `DEPLOYMENT.md` | Deployment instructions |
