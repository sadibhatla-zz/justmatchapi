# frozen_string_literal: true
FactoryGirl.define do
  factory :communication_template_translation do
    subject 'MyString'
    body 'MyText'
    language nil
    locale 'MyString'
    communication_template nil
  end
end

# == Schema Information
#
# Table name: communication_template_translations
#
#  id                        :integer          not null, primary key
#  subject                   :string
#  body                      :text
#  language_id               :integer
#  locale                    :string
#  communication_template_id :integer
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#
# Indexes
#
#  index_comm_template_translations_on_comm_template_id      (communication_template_id)
#  index_communication_template_translations_on_language_id  (language_id)
#
# Foreign Keys
#
#  fk_rails_745b09f1d4  (language_id => languages.id)
#
