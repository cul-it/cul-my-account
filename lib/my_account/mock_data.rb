# Mock data module for the development environment
# used when DEBUG_USER=FAKEUSER
# intercepts API calls and returns fake data

require 'faker'

module MyAccount
  module MockData
    def self.get_folio_data
        charges = Array.new(rand(5..15)) { generate_charge }
        total_amount = charges.sum { |charge| charge[:chargeAmount][:amount] }.round(2)
        {
            code: 200,
            account: {
                totalCharges: {
                    amount: total_amount,
                    isoCurrencyCode: 'USD'
                },
                totalChargesCount: charges.size,
                totalLoans: rand(1..50),
                totalHolds: rand(0..10),
                charges: charges,
                holds: [],
                loans: Array.new(rand(5..25)) { generate_loan }
            }
        }
    end

    def self.get_service_point
        {
            service_point: {
                discoveryDisplayName: Faker::Address.community
            }
        }
    end

    def self.ajax_catalog_link_and_source
        {
            link: "https://catalog.library.cornell.edu/catalog/9761242",
            source: %w[MARC FOLIO ILL BorrowDirect mock].sample
        }
    end

    def self.get_illiad_data
        {
            code: 200,
            pending: Array.new(rand(5..40)) { generate_illiad_request('Pending') },
            available: Array.new(rand(5..40)) { generate_illiad_request('Available') }
        }
    end

    def self.generate_illiad_request(status)
        # used on the Pending requests tab & Ready for Pickup tab
        {
            'iid' => "illiad-#{Faker::Number.unique.number(digits: 8)}",
            'system_types' => %w[illiad bd folio].sample,
            'requestDate' => Faker::Date.backward(days: rand(1..30)).strftime('%Y-%m-%d'),
            'ou_title' => Faker::Movies::StarWars.quote,
            'ou_aulast' => Faker::Movies::StarWars.character,
            'status' => status,
            'shipped' => [true, false].sample,
            'lo' => Faker::Movies::StarWars.planet
        }
    end

    def self.get_bd_requests
        # used on Ready for pickup tab
        Array.new(rand(3..6)) do
            {
            'tl' => Faker::Fantasy::Tolkien.poem,
            'au' => Faker::Fantasy::Tolkien.character,
            'system' => 'bd',
            'status' => %w[REQ_CHECKED_IN PREPARING LOCAL ACTIVE ACTIVE_PENDING_CONDITIONAL_ANSWER ACTIVE_SHIPPED COMPLETED].sample,
            'iid' => Faker::Alphanumeric.alphanumeric(number: 8),
            'lo' => Faker::Fantasy::Tolkien.location,
            'shipped' => [true, false].sample
            }
        end
    end

    def self.ajax_renew
        {
            code: 200,
            message: "Request successfully renewed the fake item",
            due_date: "2050-01-01T23:59:59Z"
        }
    end

    def self.ajax_cancel
        {
            code: 200,
            message: "Request successfully canceled the fake request"
        }
    end

    # Helper methods
    def self.generate_charge
        # used on the Fines and fees tab
        {
            chargeAmount: {
                amount: Faker::Commerce.price(range: 1..50.0),
                isoCurrencyCode: 'USD'
            },
            accrualDate: Faker::Time.backward(days: rand(120..365)).iso8601,
            reason: %w[Overdue Lost\ Item Damaged].sample,
            item: {
                title: Faker::Quote.famous_last_words
            }
        }
    end

    def self.generate_loan
        # used on the checkout tab
        {
            id: Faker::Alphanumeric.alphanumeric(number: 36),
            item: {
                instanceId: Faker::Alphanumeric.alphanumeric(number: 36),
                itemId: Faker::Alphanumeric.alphanumeric(number: 36),
                title: Faker::Book.title,
                author: Faker::Music.band
            },
            loanDate: Faker::Time.backward(days: 365).iso8601,
            dueDate: Faker::Time.forward(days: 30).iso8601,
            overdue: [true, false].sample
        }
    end
    
  end
end
