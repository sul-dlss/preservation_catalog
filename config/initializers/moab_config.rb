require 'moab'
require 'moab/stanford'

Moab::Config.configure do
  storage_roots(Settings.storage_root_map.default.to_h.values)
  storage_trunk(Settings.moab.storage_trunk)
  path_method(Settings.moab.path_method.to_sym)
  checksum_algos(Settings.checksum_algos.map(&:to_sym))
end
