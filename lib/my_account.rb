require "my_account/engine"
if Rails.env.development?
    require "my_account/mock_data"
end

module MyAccount
end
