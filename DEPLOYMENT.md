# Deployment checklist — run only after creating your own AWS account

**Confirm your instructor's AWS Region first.** The following commands are designed for AWS CloudShell in that Region, using a configured AWS CLI session. Do not create IAM access keys. Creating AWS resources may incur charges; verify pricing/free-tier eligibility and create an AWS Budget first in Billing > Budgets (for example a small monthly cost budget with email alerts). Budgets are alerts, not a spending cap.

## 1. Create account and choose Region
1. Register at https://aws.amazon.com/ using your own details and payment method; complete verification.
2. Enable MFA on your root user. For daily work, use the recommended AWS account administrative access method (e.g. IAM Identity Center) instead of root credentials.
3. Open Billing > Budgets and create a monthly cost budget with an email notification. Confirm the Region used in class.
4. Open AWS CloudShell in that Region. Upload/unzip this repository into CloudShell (or clone your own GitHub repository). `cd` to the repository root. `aws sts get-caller-identity` should succeed.

## 2. Set names and upload private S3 objects
```bash
export AWS_DEFAULT_REGION=YOUR_CLASS_REGION
export ROLL=22l-7922
export BUCKET=cv-$ROLL
# If bucket name is already taken, append digits, e.g. cv-22l-7922-123.
# In that case also replace the bucket name in BOTH IAM permission JSONs and ec2/sync-cv.sh,
# then regenerate ec2/user-data.sh from the updated sync script before creating EC2.
aws s3api create-bucket --bucket "$BUCKET" --region "$AWS_DEFAULT_REGION" $( [ "$AWS_DEFAULT_REGION" = us-east-1 ] || echo "--create-bucket-configuration LocationConstraint=$AWS_DEFAULT_REGION" )
aws s3api put-public-access-block --bucket "$BUCKET" --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
aws s3api put-bucket-versioning --bucket "$BUCKET" --versioning-configuration Status=Enabled
aws s3api put-bucket-tagging --bucket "$BUCKET" --tagging 'TagSet=[{Key=Owner,Value=22L-7922},{Key=Course,Value=cloud}]'
aws s3 cp site/ "s3://$BUCKET/site/" --recursive
aws s3 ls "s3://$BUCKET/site/" --recursive
```
The bucket should contain **exactly three current objects** under `site/`.

## 3. Create restricted roles
```bash
aws iam create-role --role-name cv-ec2-role-$ROLL --assume-role-policy-document file://iam/ec2-trust.json --tags Key=Owner,Value=22L-7922 Key=Course,Value=cloud
aws iam put-role-policy --role-name cv-ec2-role-$ROLL --policy-name CVEC2ReadSite --policy-document file://iam/ec2-permissions.json
aws iam create-role --role-name cv-lambda-role-$ROLL --assume-role-policy-document file://iam/lambda-trust.json --tags Key=Owner,Value=22L-7922 Key=Course,Value=cloud
aws iam put-role-policy --role-name cv-lambda-role-$ROLL --policy-name CVLambdaReadSite --policy-document file://iam/lambda-permissions.json
aws iam attach-role-policy --role-name cv-lambda-role-$ROLL --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
aws iam create-instance-profile --instance-profile-name cv-ec2-profile-$ROLL --tags Key=Owner,Value=22L-7922 Key=Course,Value=cloud
aws iam add-role-to-instance-profile --instance-profile-name cv-ec2-profile-$ROLL --role-name cv-ec2-role-$ROLL
```
Wait about a minute for IAM propagation before launching.

## 4. EC2 setup in AWS console (simplest)
1. EC2 > Launch instance. Name `cv-ec2-22l-7922`. Choose **Amazon Linux 2023**, and `t3.micro` or `t2.micro` only if currently marked eligible for your account. Choose an appropriate VPC and a public subnet with auto-assign public IPv4 enabled. **No Elastic IP, NAT gateway or load balancer.**
2. Network security group: allow **HTTP TCP 80 from 0.0.0.0/0**. Leave SSH TCP 22 closed, or allow only your own IP as `/32`; no other inbound rules.
3. Advanced details > IAM instance profile: `cv-ec2-profile-22l-7922`. Metadata version: **V2 only (token required)**.
4. Advanced details > User data: paste the complete contents of `ec2/user-data.sh`. Add tags `Owner=22L-7922`, `Course=cloud` (and retain the Name tag). Launch exactly **one** instance.
5. Wait for startup, visit `http://PUBLIC_IP/`, `http://PUBLIC_IP/style.css`, `http://PUBLIC_IP/cv.pdf`. If Instance Connect is needed, temporarily authorize its documented IP range for SSH or use an approved secure access method; restore the security group to the assignment's strict inbound rules before submission.
6. From the instance shell: `sudo systemctl status cv-sync.timer`; `sudo tail -n 10 /var/log/cv-sync.log`; `aws s3 rm s3://cv-22l-7922/site/style.css` (must be AccessDenied). Paste real outputs into README. Wait at least 15 minutes for three or more logged sync runs.

## 5. Lambda setup
1. Lambda > Create function > Author from scratch; name `cv-func-22l-7922`; choose the **latest offered Python runtime** and **Use an existing role**: `cv-lambda-role-22l-7922`.
2. Upload/paste `lambda/lambda_function.py` as the handler code. Handler: `lambda_function.lambda_handler`. Deploy.
3. Configuration > General configuration: memory **128 MB** (or 256 MB), timeout **10 seconds**.
4. Configuration > Environment variables: `BUCKET=cv-22l-7922` and `PREFIX=site/`.
5. Configuration > Function URL: create URL with auth type **NONE**. AWS may require explicit resource-based permissions for `lambda:InvokeFunctionUrl` and `lambda:InvokeFunction` depending on creation method and service behavior; use the console's offered public-access permission setup and verify Permissions > Resource-based policy. Never make the bucket public.
6. CloudWatch > Log groups > `/aws/lambda/cv-func-22l-7922` > set retention to **7 days** after the first invocation (or create the group first and set it). Invoke `/`, `/style.css`, `/cv.pdf`, `/anything`; verify HTTP status, content types, and the PDF.

## 6. Evidence, GitHub, submission
```bash
chmod +x collect-evidence.sh ec2/*.sh
./collect-evidence.sh cv-22l-7922 http://YOUR_EC2_IP https://YOUR_LAMBDA_FUNCTION_URL
# Run with two arguments as well; it must print Usage and exit 1.
git init
git add README.md DEPLOYMENT.md collect-evidence.sh evidence.txt site ec2 lambda iam .gitignore
git commit -m "Complete AWS CV lab"
```
Create a **public** GitHub repository and push using your own GitHub credentials (never commit AWS keys). Submit public GitHub URL, EC2 URL, Lambda URL, and roll number. Check the site from outside AWS before submission. Keep the deployment running until grading is finished, then clean up every resource and all S3 object versions.
