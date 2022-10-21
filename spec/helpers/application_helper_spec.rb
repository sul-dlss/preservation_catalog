# frozen_string_literal: true

RSpec.describe ApplicationHelper, type: :helper do
  describe '#version_string_to_int' do
    { # passed value => expected parsed value
      6 => 6,
      0 => 0,
      -1 => -1,
      '6' => 6,
      '006' => 6,
      'v0006' => 6,
      '0' => 0,
      '-666' => '-666',
      'vv001' => 'vv001',
      'asdf' => 'asdf'
    }.each do |k, v|
      it "by parsing '#{k}' to '#{v}'" do
        expect(version_string_to_int(k)).to eq(v)
      end
    end
  end

  describe '#string_to_int' do
    context 'sets incoming_size' do
      { # passed value => expected parsed value
        6 => 6,
        0 => 0,
        -1 => -1,
        '0' => 0,
        '6' => 6,
        '006' => 6,
        'v0006' => 'v0006',
        '-666' => '-666',
        'vv001' => 'vv001',
        'asdf' => 'asdf'
      }.each do |k, v|
        it "by parsing '#{k}' to '#{v}'" do
          expect(string_to_int(k)).to eq(v)
        end
      end
    end
  end
end
