# frozen_string_literal: true
ActiveAdmin.register CommunicationTemplate do
  menu parent: 'Settings'

  include AdminHelpers::MachineTranslation::Actions

  after_save do |template|
    template.set_translation(
      name: permitted_params.dig(:communication_template, :name),
      body: permitted_params.dig(:communication_template, :body)
    )
  end

  permit_params do
    [:language_id, :category, :subject, :body]
  end
end
