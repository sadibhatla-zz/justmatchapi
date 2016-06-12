# frozen_string_literal: true
require 'rails_helper'

RSpec.describe JsonApiData do
  let(:id) { 1 }
  let(:type) { 'watman' }
  let(:attributes) { { 'test_key' => 3 } }
  subject do
    json = JsonApiData.new(id: id, type: type, attributes: attributes).to_json
    JSON.parse(json)
  end

  it 'returns id' do
    expect(subject.dig('data', 'id')).to eq(id)
  end

  it 'returns type' do
    expect(subject.dig('data', 'type')).to eq(type)
  end

  it 'returns dasherized attributes' do
    expect(subject.dig('data', 'attributes', 'test-key')).to eq(3)
  end
end
