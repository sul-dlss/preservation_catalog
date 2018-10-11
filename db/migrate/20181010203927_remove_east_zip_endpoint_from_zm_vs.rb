class RemoveEastZipEndpointFromZmVs < ActiveRecord::Migration[5.1]
  def change
    disable_ddl_transaction!
    east_endpoint = ZipEndpoint.find_by(endpoint_name: "aws_s3_east_1")
    east_endpoint.zipped_moab_versions.find_each(&:destroy)
    east_endpoint.destroy
  end
end
