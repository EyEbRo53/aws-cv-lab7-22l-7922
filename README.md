# Lab 7 — Host Your CV on AWS

**Student:** Hassan Yousaf  
**Roll:** 22L-7922  
**Email:** l227922@lhr.nu.edu.pk  
**Region:** ap-southeast-2 (Sydney)

## Architecture

```text
Browser ──HTTP──> EC2 (Apache, local copy of CV) ──IAM role──> private S3/site/
        └─HTTPS──> Lambda Function URL ──IAM role──> private S3/site/
```

For the EC2 path, the browser connects to Apache on the instance, which serves a local copy of the CV synchronized from S3 every five minutes. For the Lambda path, the browser calls the public function URL and the function reads the requested object directly from private S3.

## Live endpoints
- EC2: http://16.176.169.190/
- Lambda: https://bficwk25gle5bhlpkp5rjgphja0zciht.lambda-url.ap-southeast-2.on.aws/
- Direct S3 object: https://cv-22l-7922.s3.amazonaws.com/site/index.html (HTTP 403)

## Access denied test

The following command was run on the EC2 instance:

    aws s3 cp /tmp/denied-test.txt s3://cv-22l-7922/site/denied-test.txt

Result: AccessDenied. The EC2 IAM role does not permit s3:PutObject.

## EC2 synchronization

The EC2 instance runs Apache and synchronizes its local CV files
from private S3 using a systemd timer every five minutes.

Recorded successful synchronization entries:

    2026-10-25T17:23:14+00:00 OK: synced i-03da7b9c6666bf0a1
    2026-10-25T17:31:29+00:00 OK: synced i-03da7b9c6666bf0a1
    2026-10-25T17:32:03+00:00 OK: synced i-03da7b9c6666bf0a1

See ec2-test-results.txt for the recorded test results.

## Written answers

**1. Why roles rather than access keys?**  
IAM roles give EC2 and Lambda temporary credentials automatically. Hardcoded access keys can be stolen from scripts or instance user data and used to access AWS resources. Roles avoid storing long-lived credentials.

**2. What happens if someone opens the direct S3 URL?**  
They receive an AccessDenied response. All four S3 Block Public Access settings are enabled, and no public read permission is granted.

**3. Why is the function URL public but the bucket private?**  
The Lambda function URL has a resource-based permission that allows unauthenticated public invocation. This is acceptable because the function serves only the intended CV paths; the S3 bucket remains private and is accessed using the function's restricted IAM role.

**4. Compare idle cost and traffic growth.**  
EC2 can incur compute and public IPv4 charges while running even if nobody visits. Lambda charges depend mainly on invocations and execution time, with any applicable free allowances; S3 storage also has costs. With much higher traffic, Lambda scales automatically subject to limits and costs, while a single EC2 instance may become overloaded.

**5. What if EC2 is deleted?**  
The instance, its local web files, its public IP, and its web endpoint are lost. The private S3 bucket and its files, the Lambda function and its URL, and IAM roles remain unless separately deleted.

## Evidence
Run `./collect-evidence.sh cv-22l-7922 http://EC2_PUBLIC_IP https://LAMBDA_FUNCTION_URL` from a configured AWS CLI environment in the class region. Commit the resulting `evidence.txt`. **Do not fabricate evidence or commit credentials.**

## Sources and adaptation
Assignment requirements: *Lab 7 - Basic App Deployment on AWS*, provided by instructor. Starter scripts and text generated with AI assistance; reviewed and adapted by student before submission. AWS deployment was completed and tested.

## Deployment verification

- EC2 and Lambda websites return HTTP 200.
- HTML, CSS, and PDF are served successfully.
- Unknown Lambda paths return HTTP 404.
- Direct S3 object access returns HTTP 403.
- EC2 security group has inbound port 80 only.
- EC2 S3 write attempt returned AccessDenied.
- Lambda CloudWatch log retention is seven days.
- Evidence collected in evidence.txt.

## GitHub repository

https://github.com/EyEbRo53/aws-cv-lab7-22l-7922

Keep the deployed services running until grading is complete.
