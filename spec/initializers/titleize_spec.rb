require 'logger'
require 'active_support'
require 'active_support/core_ext/string'
require_relative '../../config/initializers/titleize'

RSpec.describe 'String#titleize' do
  it 'capitalizes words except exclusions' do
    expect("the lord of the rings".titleize).to eq("The Lord of the Rings")
  end

  it 'capitalizes excluded words if they are first' do
    expect("and then there were none".titleize).to eq("And Then There Were None")
  end

  it 'uses ActiveSupport titleize if exclusions not present' do
    expect("the quick brown fox".titleize(exclude: [])).to eq("The Quick Brown Fox")
  end

  it 'preserves punctuation' do
    expect("war and peace: a novel".titleize).to eq("War and Peace: a Novel")
  end
end