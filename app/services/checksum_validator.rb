# code for validating Moab checksums
class ChecksumValidator
  def initialize(druid, endpoint, algorithm)
    @druid = druid
    @endpoint = endpoint
    @algorithm = algorithm
  end

  def validate_checksum
    # TODO: implement this;  we begin with a placeholder
  end
end
