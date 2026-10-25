#!/usr/bin/env bash
if [[ $# -ne 3 ]]; then echo "Usage: $0 BUCKET EC2_URL LAMBDA_URL"; exit 1; fi
BUCKET="$1"; EC2_URL="${2%/}"; LAMBDA_URL="${3%/}"
ROLL="22l-7922"; OUT="evidence.txt"
: > "$OUT"
section() { echo "== $1 ==" >> "$OUT"; }
run() { "$@" >> "$OUT" 2>&1 || echo "COMMAND FAILED (exit $?): $*" >> "$OUT"; }
section caller; run aws sts get-caller-identity
section public-access; run aws s3api get-public-access-block --bucket "$BUCKET"
section versioning; run aws s3api get-bucket-versioning --bucket "$BUCKET"
section objects; run aws s3 ls "s3://$BUCKET/site/" --recursive
section ec2-policy; run aws iam get-role-policy --role-name "cv-ec2-role-$ROLL" --policy-name CVSiteReadOnly
section lambda-policy; run aws iam list-attached-role-policies --role-name "cv-lambda-role-$ROLL"; run aws iam get-role-policy --role-name "cv-lambda-role-$ROLL" --policy-name CVSiteReadOnly
section security-group
SG=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=cv-ec2-$ROLL" "Name=instance-state-name,Values=running" --query 'Reservations[0].Instances[0].SecurityGroups[0].GroupId' --output text 2>>"$OUT")
if [[ "$SG" != None && -n "$SG" ]]; then run aws ec2 describe-security-groups --group-ids "$SG"; else echo 'COMMAND FAILED: security group not found' >> "$OUT"; fi
section instance; run aws ec2 describe-instances --filters "Name=tag:Name,Values=cv-ec2-$ROLL" --query 'Reservations[].Instances[].[InstanceId,InstanceType,MetadataOptions.HttpTokens,IamInstanceProfile.Arn,PublicIpAddress]' --output json
section endpoints
for url in "$EC2_URL/" "$EC2_URL/style.css" "$EC2_URL/cv.pdf" "$LAMBDA_URL/" "$LAMBDA_URL/style.css" "$LAMBDA_URL/cv.pdf" "$LAMBDA_URL/anything" "https://${BUCKET}.s3.amazonaws.com/site/index.html"; do
  printf '%s ' "$url" >> "$OUT"
  run curl -sS -o /dev/null --max-time 15 -w 'status=%{http_code} content_type=%{content_type}\n' "$url"
done
section lambda-logs; run aws logs tail "/aws/lambda/cv-func-$ROLL" --since 1h
section log-retention; run aws logs describe-log-groups --log-group-name-prefix "/aws/lambda/cv-func-$ROLL" --query 'logGroups[].{name:logGroupName,days:retentionInDays}'
echo DONE
