# frozen_string_literal: true

module Api
  module V1
    class ContactsController < BaseController
      after_action :verify_authorized, only: []

      resource_description do
        api_versions '1.0'
        name 'Contact'
        short 'API for sending contact emails'
        description ''
        formats [:json]
      end

      api :POST, '/contacts/', 'Create contact notification'
      description 'Send contact notification.'
      error code: 422, desc: 'Unprocessable entity'
      ApipieDocHelper.params(self)
      param :data, Hash, desc: 'Top level key', required: true do
        param :attributes, Hash, desc: 'Contact attributes', required: true do
          param :name, String, desc: 'Name', required: true
          param :email, String, desc: 'Email', required: true
          param :body, String, desc: 'Body', required: true
        end
      end
      example '# Response example
{}
'
      def create
        contact = Contact.new(contact_params)

        if contact.save
          ContactNotifier.call(contact: contact)
          render json: {}, status: :created
        else
          api_render_errors(contact)
        end
      end

      protected

      def allow_expired_auth_token?
        %w[create].include?(params['action'])
      end

      private

      def contact_params
        jsonapi_params.permit(:name, :email, :body)
      end
    end
  end
end
