# frozen_string_literal: true

FactoryBot.define do
  factory :zip_part do
    md5 { '00236a2ae558018ed13b5222ef1bd977' }
    create_info { { zip_cmd: 'zip some args', zip_version: '3.14' } }
    parts_count { 1 }
    size { 1234 }
    status { 'unreplicated' }
    suffix { parts_count == 1 ? '.zip' : format('.z%02d', parts_count) }
    zipped_moab_version
  end
end
