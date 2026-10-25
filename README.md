# Lab 7 — Host Your CV on AWS

**Student:** Hassan Yousaf  
**Roll:** 22L-7922  
**Email:** l227922@lhr.nu.edu.pk  
**Region:** TODO — confirm the class region before deployment.

## Architecture

```text
Browser ──HTTP──> EC2 (Apache, local copy of CV) ──IAM role──> private S3/site/
        └─HTTPS──> Lambda Function URL ──IAM role──> private S3/site/
```

For the EC2 path, the browser connects to Apache on the instance, which serves a local copy of the CV synchronized from S3 every five minutes. For the Lambda path, the browser calls the public function URL and the function reads the requested object directly from private S3.

## Live endpoints (fill after deployment)
- EC2: TODO
- Lambda: TODO
- S3 object direct URL (should be AccessDenied): TODO

## Access denied test (paste actual EC2 shell output)
```text
TODO: On EC2 run: aws s3 rm s3://cv-22l-7922/site/style.css
Paste the AccessDenied result here. Do not run a successful deletion.
```

## Last 10 sync log lines (paste actual EC2 output)
```text
TODO: sudo tail -n 10 /var/log/cv-sync.log
```

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
Assignment requirements: *Lab 7 - Basic App Deployment on AWS*, provided by instructor. Starter scripts and text generated with AI assistance; reviewed and adapted by student before submission. AWS deployment has not yet been performed.

## Before submitting
Replace sample CV details in both `site/index.html` and `site/cv.pdf`. Fill the actual URLs, denied-output, and sync log above. Confirm the required region, tags, AWS budget, running endpoints, IAM permissions, and log retention. Keep services available until grading ends.
