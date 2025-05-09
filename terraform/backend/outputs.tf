output "tf_state_bucket_name" {
  value = aws_s3_bucket.tf_state.bucket
}

output "dynamo_table_name" {
  value = aws_dynamodb_table.tf_lock.name
}
