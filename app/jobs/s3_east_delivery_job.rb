# frozen_string_literal: true

# Same as parent class, just a different queue.
class S3EastDeliveryJob < S3WestDeliveryJob
  queue_as :s3_us_east_1_delivery # note: still needs proper ENVs for AWS_REGION, etc.
end
