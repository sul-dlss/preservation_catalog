class S3EastDeliveryJob < S3EndpointDeliveryJob
  queue_as :s3_us_east_1_delivery # note: still needs proper ENVs for AWS_REGION, etc.
end
