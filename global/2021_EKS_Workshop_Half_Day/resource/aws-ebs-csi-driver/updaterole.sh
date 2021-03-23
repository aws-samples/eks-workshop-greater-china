
echo  "CSI Policy ARN| $1"

CSI_ARN=$1
ROLES=$(aws iam list-roles --query 'Roles[?contains(RoleName,`nodegr`)].RoleName' --output text)

for i in $ROLES
do
    echo attach [$CSI_ARN] to [$i]
    aws iam attach-role-policy \
            --policy-arn $CSI_ARN \
             --role-name $i \
             --region cn-northwest-1

done


