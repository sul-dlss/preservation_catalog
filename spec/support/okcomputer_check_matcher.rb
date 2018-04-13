# Taken from okcomputer's own tests
# https://github.com/sportngin/okcomputer/blob/master/spec/support/check_matcher.rb

RSpec::Matchers.define :have_message do |message|
  match do |actual|
    actual.check
    actual.message.include? message
  end

  failure_message do |actual|
    "expected '#{actual.message}' to include '#{message}'"
  end

  failure_message_when_negated do |actual|
    "expected '#{actual.message}' to not include '#{message}'"
  end
end

RSpec::Matchers.define :be_successful do |_message|
  match do |actual|
    actual.check
    actual.success?
  end

  failure_message do |actual|
    "expected #{actual.inspect} to be successful"
  end

  failure_message_when_negated do |actual|
    "expected '#{actual}' to not be successful"
  end
end
