require 'nypl_log_formatter'

require_relative File.join('..', 'application')
require_relative File.join('..', 'lib', 'deferred_request')
require_relative File.join('..', 'lib', 'kms_client')
require_relative File.join('..', 'lib', 'sqs_client')

RSpec::Matchers.define :equivalent_sqs_entry_to do |model|
  match do |actual|
    return false if ! actual.is_a? Hash

    # Set up series of named conditions so that we can assert all pass and log
    # out any failures to assist debugging:
    must = []
    must << { message: "Match groupId", condition: (model[:message_group_id].nil? || model[:message_group_id] == actual[:message_group_id]) }
    must << { message: "Match deduplciation id", condition: (model[:message_deduplication_id].nil? || model[:message_deduplication_id] == actual[:message_deduplication_id]) }
    must << { message: "Match queue_url", condition: model[:queue_url] == actual[:queue_url] }
    must << { message: "Match message_body", condition: model[:message_body] == actual[:message_body] }

    must.map do |clause|
      puts "Unmatched SQS matching condition: #{clause[:message]}: #{actual}" if ! clause[:condition]
    end

    # Matches if no failed conditions:
    must.select { |clause| ! clause[:condition] }.empty?
  end
end
