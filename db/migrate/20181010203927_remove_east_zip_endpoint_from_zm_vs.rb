# Commenting out so this stays in the history, turns out we need to run these commands in the console.
class RemoveEastZipEndpointFromZmVs < ActiveRecord::Migration[5.1]
#   def change
#     east_endpoint = ZipEndpoint.find_by(endpoint_name: "aws_s3_east_1")
#     east_endpoint.zipped_moab_versions.find_each(&:destroy)
#     east_endpoint.destroy
#   end
end
