#!/bin/bash

# הגדרת פרטי הקונפיגורציה
AWS_REGION="us-east-1"
TAG_KEY="Project"
TAG_VALUE="DevOpsProject"
BACKEND_FILE="backend/setup.tf"

# פונקציה שמבצעת חיפוש של משאבים עם ה-tag הנדרש
find_resources_with_tag() {
  aws resourcegroupstaggingapi get-resources \
    --region $AWS_REGION \
    --tag-filters Key=$TAG_KEY,Values=$TAG_VALUE \
    --output json
}

# פונקציה שמבצעת את ה-import לכל משאב שנמצא
import_resources_to_state() {
  resources_json=$(find_resources_with_tag)

  # אם אין משאבים מתאימים, תצא מהסקריפט
  if [ "$(echo $resources_json | jq '.ResourceTagMappingList | length')" -eq 0 ]; then
    echo "No resources found with tag $TAG_KEY=$TAG_VALUE"
    exit 0
  fi

  # עבור כל משאב שנמצא, הוסף אותו ל-state
  resource_arns=$(echo $resources_json | jq -r '.ResourceTagMappingList[].ResourceARN')

  for arn in $resource_arns; do
    resource_type=$(echo $arn | cut -d':' -f3)
    resource_id=$(echo $arn | cut -d':' -f6)

    # בדוק אם המשאב כבר קיים בקובץ backend/setup.tf
    if grep -q "$resource_type.$resource_id" "$BACKEND_FILE"; then
      echo "Resource $resource_type/$resource_id already exists in $BACKEND_FILE, skipping import."
      continue
    fi

    # הוסף כל משאב ל-state של Terraform
    echo "Importing resource $resource_type/$resource_id..."
    terraform import "$resource_type.$resource_id" "$arn"
    
    # עדכן את קובץ backend/setup.tf עם המשאב החדש
    echo "resource \"$resource_type\" \"$resource_id\" {}" >> "$BACKEND_FILE"
  done
}

# הרץ את הפונקציה
import_resources_to_state
