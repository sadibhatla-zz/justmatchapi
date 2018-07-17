# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User, type: :model do
  describe '::needs_anonymization' do
    # rubocop:disable Metrics/LineLength
    it 'returns users that should be anonymized' do
      FactoryBot.create(:user)
      FactoryBot.create(:user, anonymization_requested_at: 1.day.ago, anonymized_at: 1.hour.ago)
      user_with_applications = FactoryBot.create(:user, anonymization_requested_at: 1.day.ago)
      FactoryBot.create(:job_user, user: user_with_applications)

      anonymize_user = FactoryBot.create(:user, anonymization_requested_at: 1.day.ago)
      FactoryBot.create(:job_user, user: anonymize_user, created_at: 9.years.ago)

      expect(User.needs_anonymization).to eq([anonymize_user])
    end
    # rubocop:enable Metrics/LineLength
  end

  describe '#anonymization_allowed?' do
    it 'returns true user has no appilcations' do
      user = FactoryBot.build_stubbed(:user)
      expect(user.anonymization_allowed?).to eq(true)
    end

    it 'returns true user has appilcations that are old enough' do
      user = FactoryBot.create(:user)
      FactoryBot.create(
        :job_user,
        user: user,
        created_at: 5.years.ago,
        updated_at: 5.years.ago
      )
      expect(user.anonymization_allowed?).to eq(true)
    end

    it 'returns false user has appilcations that are *not* old enough' do
      user = FactoryBot.create(:user)
      FactoryBot.create(
        :job_user,
        user: user,
        created_at: 1.year.ago,
        updated_at: 1.year.ago
      )
      expect(user.anonymization_allowed?).to eq(false)
    end
  end

  describe '#frilans_finans_users' do
    it 'returns users with frilans finans id set' do
      FactoryBot.create(:user, frilans_finans_id: nil)
      first = FactoryBot.create(:user, frilans_finans_id: 10)
      last = FactoryBot.create(:user, frilans_finans_id: 11)
      frilans_users = described_class.frilans_finans_users

      expect(frilans_users.count).to eq(2)
      expect(frilans_users).to include(first)
      expect(frilans_users).to include(last)
    end
  end

  describe '#virtual_attributes' do
    it 'returns all virtual user attributes' do
      expect(User.new.virtual_attributes).to eq('bank_account' => nil)
    end
  end

  describe '#all_attributes' do
    it 'returns user attributes and virtual user attributes' do
      expect(User.new.all_attributes).to include('bank_account' => nil)
      expect(User.new.all_attributes).to include('first_name' => nil)
    end
  end

  describe '#contact_email' do
    context 'not managed' do
      let(:user) { FactoryBot.build(:user, managed: false) }

      it 'returns users email' do
        expect(user.contact_email).to eq(user.email)
      end
    end

    context 'managed' do
      let(:user_id) { 73 }
      let(:user) { FactoryBot.build(:user, id: user_id, managed: true) }
      let(:env_map) do
        {
          MANAGED_EMAIL_USERNAME: 'address',
          MANAGED_EMAIL_HOSTNAME: 'example.com'
        }
      end

      it 'returns managed email' do
        ENVTestHelper.wrap(env_map) do
          expect(user.contact_email).to eq("address+user#{user_id}@example.com")
        end
      end
    end
  end

  it 'normalizes phone before validation (so unique checks work properly)' do
    phone = '073 5000 000'
    FactoryBot.create(:user, phone: phone)
    user = User.new(phone: phone)
    user.validate
    expect(user.errors[:phone]).to eq(['has already been taken'])
  end

  describe '#set_normalize_phone' do
    it 'normalizes phone number without country prefix' do
      user = User.new(phone: '073 5000 000')
      user.validate
      expect(user.phone).to eq('+46735000000')
    end

    it 'normalizes phone number with country prefix' do
      user = User.new(phone: '+4673 5000 000')
      user.validate
      expect(user.phone).to eq('+46735000000')

      user = User.new(phone: '004673 5000 000')
      user.validate
      expect(user.phone).to eq('+46735000000')
    end
  end

  describe '#set_normalized_email' do
    let(:email) { ' SOME_EMAIL_ADDRESS@example.com  ' }

    it 'lowercases email after validation' do
      user = User.new(email: email)
      user.validate
      expect(user.email).to eq(email.downcase.strip)
    end

    it 'can handle nil address' do
      user = User.new(email: nil)
      user.validate
      expect(user.email).to be_nil
    end
  end

  describe '#bank_account' do
    it 'can set valid bank account' do
      clearing = '8000-2'
      number = '000 00000 00'
      account = [clearing, number].join

      user = User.new
      user.bank_account = account

      expect(user.account_clearing_number).to eq(clearing)
      expect(user.account_number).to eq(number.delete(' '))
    end
  end

  describe '#set_normalized_bank_account' do
    it 'normalizes bank account' do
      user = User.new(account_clearing_number: ' 8000-2 ', account_number: '000 00000 00')
      user.validate
      expect(user.account_clearing_number).to eq('8000-2')
      expect(user.account_number).to eq('0000000000')
    end
  end

  describe 'geocodable' do
    let(:user) { FactoryBot.create(:user) }

    it 'geocodes by exact address' do
      expect(user.latitude).to eq(40.7143528)
      expect(user.longitude).to eq(-74.0059731)
    end

    it 'geocodes by zip' do
      expect(user.zip_latitude).to eq(40.7143528)
      expect(user.zip_longitude).to eq(-74.0059731)
    end
  end

  describe '#frilans_finans_id!' do
    it 'returns frilans_finans_id if one is set' do
      id = 7
      user = FactoryBot.build(:user, frilans_finans_id: id)
      expect(user.frilans_finans_id!).to eq(id)
    end

    it 'returns frilans_finans_id if one is set' do
      user = FactoryBot.build(:user, frilans_finans_id: nil)
      expect do
        user.frilans_finans_id!
      end.to raise_error(User::MissingFrilansFinansIdError)
    end
  end

  describe '#accepted_applicant_for_owner?' do
    let(:owner) { FactoryBot.create(:company_user) }
    let(:user) { FactoryBot.create(:user) }

    let(:job) { FactoryBot.create(:job, owner: owner) }

    it 'returns true when user is an accepted applicant for a job owner' do
      allow(JobUser).to receive(:accepted_jobs_for).and_return([job])
      result = User.accepted_applicant_for_owner?(owner: owner, user: user)
      expect(result).to eq(true)
    end

    it 'returns false when user is *not* an accepted applicant for a job owner' do
      result = User.accepted_applicant_for_owner?(owner: owner, user: user)
      expect(result).to eq(false)
    end
  end

  describe '#locale' do
    it 'returns en for a non-persisted user that has no language' do
      expect(User.new.locale).to eq('en')
    end

    it 'returns correct locale for user that has a language' do
      lang_code = 'wa'
      language = FactoryBot.build(:language, lang_code: lang_code)
      user = FactoryBot.build(:user, system_language: language)
      expect(user.locale).to eq(lang_code)
    end
  end

  describe '#banned' do
    let(:user) { FactoryBot.create(:user) }

    it 'destroys all auth tokens when user is banned' do
      user.create_auth_token
      user.banned = true
      user.save
      expect(user.auth_tokens).to be_empty
      expect(user.banned).to eq(true)
    end
  end

  describe '#add_image_by_token=' do
    let(:user) { FactoryBot.create(:user) }
    let(:user_image) { FactoryBot.create(:user_image) }
    let(:user_image1) { FactoryBot.create(:user_image) }

    it 'can set image from token' do
      user.add_image_by_token = user_image.one_time_token
      expect(user.user_images.first).to eq(user_image)
    end

    it 'does not replace older images' do
      user.add_image_by_token = user_image.one_time_token
      user.add_image_by_token = user_image1.one_time_token
      expect(user.user_images.length).to eq(2)
    end

    it 'does not set token when such token is found' do
      user.add_image_by_token = 'invalid token'
      expect(user.user_images.first).to be_nil
    end

    it 'does not set token when token is nil' do
      user.add_image_by_token = nil
      expect(user.user_images.first).to be_nil
    end
  end

  describe '#valid_password_format?' do
    it 'returns true if password is at least of length 6' do
      expect(User.valid_password_format?('123456')).to eq(true)
    end

    it 'returns false if password is at less than 6 in length' do
      expect(User.valid_password_format?('12345')).to eq(false)
    end

    it 'returns false if password is longer than 50 in length' do
      expect(User.valid_password_format?((1..51).to_a.join(''))).to eq(false)
    end

    it 'returns false if password is *not* a string' do
      expect(User.valid_password_format?(%w(1 2 3 4 5 6))).to eq(false)
      expect(User.valid_password_format?(a: 2)).to eq(false)
    end

    it 'returns false if password is blank' do
      expect(User.valid_password_format?('')).to eq(false)
      expect(User.valid_password_format?(nil)).to eq(false)
    end
  end

  it 'has a one time token validity constant that is 18' do
    expect(User::ONE_TIME_TOKEN_VALID_FOR_HOURS).to eq(18)
  end

  it 'has a min password length constant that is 6' do
    expect(User::MIN_PASSWORD_LENGTH).to eq(6)
  end

  describe '#generate_one_time_token' do
    let(:user) { FactoryBot.build(:user) }

    it 'generates one time token' do
      user.generate_one_time_token
      expected = SecureGenerator::DEFAULT_TOKEN_LENGTH
      expect(user.one_time_token.length).to eq(expected)
    end

    it 'generates one time token expiry datetime' do
      time = Time.zone.now
      validity_time = User::ONE_TIME_TOKEN_VALID_FOR_HOURS.hours
      Timecop.freeze(time) do
        user.generate_one_time_token
        expect(user.one_time_token_expires_at).to eq(time + validity_time)
      end
    end
  end

  describe '#find_by_one_time_token' do
    context 'token still valid' do
      it 'finds and returns user' do
        user = FactoryBot.create(:user)
        user.generate_one_time_token
        user.save!

        token = user.one_time_token
        expect(User.find_by_one_time_token(token)).to eq(user)
      end
    end

    context 'token expired' do
      it 'returns nil' do
        user = FactoryBot.create(:user)
        user.generate_one_time_token
        user.save!

        token = user.one_time_token
        Timecop.freeze(Time.zone.today + 30) do
          expect(User.find_by_one_time_token(token)).to be_nil
        end
      end
    end
  end

  describe '#find_by_credentials' do
    context 'incorrect password' do
      it 'returns nil' do
        password = '12345678'
        user = FactoryBot.create(:user, password: password)
        email = user.email

        found_user = User.find_by_credentials(
          email_or_phone: email,
          password: password + '1'
        )
        expect(found_user).to be_nil
      end
    end

    context 'email' do
      context 'correct' do
        it 'finds and returns user' do
          password = '12345678'
          user = FactoryBot.create(:user, password: password)
          email = user.email

          found_user = User.find_by_credentials(email_or_phone: email, password: password)
          expect(found_user).to eq(user)
        end
      end

      context 'incorrect' do
        it 'returns nil' do
          password = '12345678'
          user = FactoryBot.create(:user, password: password)
          email = user.email + '1'

          found_user = User.find_by_credentials(email_or_phone: email, password: password)
          expect(found_user).to be_nil
        end
      end
    end

    context 'phone number' do
      context 'correct' do
        it 'finds and returns user' do
          password = '12345678'
          user = FactoryBot.create(:user, password: password)
          phone = user.phone

          found_user = User.find_by_credentials(email_or_phone: phone, password: password)
          expect(found_user).to eq(user)
        end

        it 'finds and returns user given a non-normalized phone number' do
          password = '12345678'
          user = FactoryBot.create(:user, password: password)
          phone = user.phone.insert(3, '-  ') # Make user phone number non-normalized

          found_user = User.find_by_credentials(email_or_phone: phone, password: password)
          expect(found_user).to eq(user)
        end

        context 'incorrect' do
          it 'returns nil' do
            password = '12345678'
            user = FactoryBot.create(:user, password: password)
            phone = user.phone + '1'

            found_user = User.find_by_credentials(
              email_or_phone: phone,
              password: password
            )
            expect(found_user).to be_nil
          end
        end
      end
    end
  end

  describe 'notifications' do
    context 'constant' do
      it 'has the correct elements in the correct order' do
        expected = %w(
          accepted_applicant_confirmation_overdue
          accepted_applicant_withdrawn
          applicant_accepted
          applicant_will_perform
          invoice_created
          job_user_performed
          job_cancelled
          new_applicant
          user_job_match
          new_chat_message
          new_job_comment
          applicant_rejected
          job_match
          new_applicant_job_info
          applicant_will_perform_job_info
          failed_to_activate_invoice
          update_data_reminder
          marketing
        )
        expect(UserNotification.names).to eq(expected)
      end

      it 'has corresponding notifier class for each item' do
        # these notifications are sent in other notifiers
        ignore = %w(
          applicant_rejected job_match new_applicant_job_info
          applicant_will_perform_job_info update_data_reminder
        )
        (UserNotification.names - ignore).each do |notification|
          expect { "#{notification.camelize}Notifier".constantize }.to_not raise_error
        end
      end

      it 'has corresponding notifier class UpdateApplicantDataReminderNotifier' do
        expect { UpdateApplicantDataReminderNotifier }.to_not raise_error
      end

      it 'has corresponding I18n for each notification' do
        UserNotification.names.each do |notification|
          translation = I18n.t("notifications.#{notification}")
          expect(translation).not_to match('translation missing:')
        end
      end
    end

    describe '#ignored_notification?' do
      it 'returns true when is ignored' do
        ignored = 'new_applicant'
        user = FactoryBot.build(:user, ignored_notifications: [ignored])
        expect(user.ignored_notification?(ignored)).to eq(true)
      end

      it 'returns false when *not* ignored' do
        user = FactoryBot.build(:user)
        expect(user.ignored_notification?('new_applicant')).to eq(false)
      end
    end

    it 'can set mask' do
      ignored = %w(new_applicant)
      user = FactoryBot.build(:user, ignored_notifications: ignored)
      expect(user.ignored_notifications).to eq(ignored)
    end

    it 'can set default mask' do
      user = FactoryBot.build(:user)
      expect(user.ignored_notifications).to eq([])
    end
  end

  describe 'validate email address format' do
    it 'adds error if language is not in available locale' do
      user = FactoryBot.build(:user, email: 'buren@')
      user.validate

      message = user.errors.messages[:email]
      expect(message).to include(I18n.t('errors.validators.email'))
    end

    it 'adds *no* error if language is not in available locale' do
      user = FactoryBot.build(:user, email: 'watman@example.com')
      user.validate

      message = user.errors.messages[:email]
      expect(message || []).not_to include(I18n.t('errors.validators.email'))
    end
  end

  describe '#validate_language_id_in_available_locale' do
    it 'adds error if language is not in available locale' do
      language = FactoryBot.create(:language, lang_code: 'aa')
      user = FactoryBot.build(:user, system_language: language)
      user.validate

      message = user.errors.messages[:system_language_id]
      expect(message).to include(I18n.t('errors.user.must_be_available_locale'))
    end

    it 'adds *no* error if language is not in available locale' do
      language = FactoryBot.create(:language, lang_code: 'en')
      user = FactoryBot.build(:user, system_language: language)
      user.validate

      message = user.errors.messages[:system_language_id]
      expect(message || []).not_to include(I18n.t('errors.user.must_be_available_locale'))
    end
  end

  describe '#validate_arrival_date_in_past' do
    let(:error_message) { I18n.t('errors.user.arrived_at_must_be_in_past') }

    it 'adds error if arrived_at is in the future' do
      user = FactoryBot.build(:user, arrived_at: 2.days.from_now.to_date)
      user.validate

      message = user.errors.messages[:arrived_at]
      expect(message).to include(error_message)
    end

    it 'adds *no* error if arrived at is a blank string' do
      user = FactoryBot.build(:user, arrived_at: ' ')
      user.validate_arrival_date_in_past

      message = user.errors.messages[:arrived_at]
      expect(message).not_to include(error_message)
    end

    it 'adds *no* error if arrived_at is in the past' do
      user = FactoryBot.build(:user, arrived_at: 2.days.ago.to_date)
      user.validate

      message = user.errors.messages[:arrived_at]
      expect(message || []).not_to include(error_message)
    end

    it 'adds *no* error if arrived_at is nil' do
      user = FactoryBot.build(:user, arrived_at: nil)
      user.validate

      message = user.errors.messages[:arrived_at]
      expect(message || []).not_to include(error_message)
    end
  end

  describe '#validate_format_of_phone_number' do
    let(:error_message) { I18n.t('errors.user.must_be_valid_phone_number_format') }

    it 'adds error if format of phone is not valid' do
      user = FactoryBot.build(:user, phone: '000123456789')
      user.validate

      message = user.errors.messages[:phone]
      expect(message).to include(error_message)
    end

    it 'adds *no* error if phone format is valid' do
      user = FactoryBot.build(:user)
      user.validate

      message = user.errors.messages[:phone]
      expect(message || []).not_to include(error_message)
    end
  end

  describe '#validate_swedish_ssn' do
    before(:each) do
      Rails.configuration.x.validate_swedish_ssn = true
    end
    after(:each) do
      Rails.configuration.x.validate_swedish_ssn = false
    end
    let(:error_message) { I18n.t('errors.user.must_be_swedish_ssn') }

    it 'adds error if format of ssn is not valid' do
      user = FactoryBot.build(:user, ssn: '00012')
      user.validate

      message = user.errors.messages[:ssn]
      expect(message).to include(error_message)
    end

    it 'adds *no* error if ssn format is valid' do
      user = FactoryBot.build(:user, ssn: '8908030334')
      user.validate

      message = user.errors.messages[:ssn]
      expect(message || []).not_to include(error_message)
    end
  end

  describe '#validate_swedish_phone_number' do
    let(:error_message) { I18n.t('errors.user.must_be_swedish_phone_number') }

    it 'adds error if phone number is not Swedish' do
      user = FactoryBot.build(:user, phone: '+1123456789')
      user.validate

      message = user.errors.messages[:phone]
      expect(message).to include(error_message)
    end

    it 'adds *no* error if phone number is Swedish' do
      user = FactoryBot.build(:user)
      user.validate

      message = user.errors.messages[:phone]
      expect(message || []).not_to include(error_message)
    end
  end

  describe '#validate_swedish_bank_account' do
    it 'adds *no* error if bank account is valid' do
      user = FactoryBot.build(
        :user,
        account_clearing_number: '8000-2',
        account_number: '0000000000'
      )
      user.validate

      expect(user.errors.messages[:bank_account]).to be_empty
      expect(user.errors.messages[:bank_account]).to be_empty
    end

    it 'adds error if bank account is invalid' do
      user = FactoryBot.build(
        :user,
        account_clearing_number: '0',
        account_number: '8'
      )
      user.validate

      message = user.errors.messages[:bank_account]
      expect(message || []).not_to be_empty
    end

    it 'adds error for invalid bank account' do
      user = User.new
      user.bank_account = 'asd'

      user.validate_swedish_bank_account

      expect(user.errors.messages[:bank_account].length).not_to be_zero
    end

    it 'adds error if bank account is invalid (only one field set)' do
      user = FactoryBot.build(
        :user,
        account_clearing_number: '0'
      )
      user.validate

      message = user.errors.messages[:bank_account]
      expect(message || []).not_to be_empty
    end
  end

  describe '#validate_arrived_at_date' do
    let(:error_message) { I18n.t('errors.general.must_be_valid_date') }

    it 'adds error if arrived at is not a valid date' do
      user = FactoryBot.build(:user, arrived_at: '1')
      user.validate_arrived_at_date

      message = user.errors.messages[:arrived_at]
      expect(message).to include(error_message)
    end

    it 'adds *no* error if arrived at is a blank string' do
      user = FactoryBot.build(:user, arrived_at: ' ')
      user.validate_arrived_at_date

      message = user.errors.messages[:arrived_at]
      expect(message).not_to include(error_message)
    end

    it 'adds *no* error if arrived at is a valid date' do
      user = FactoryBot.build(:user, arrived_at: '2016-01-01')
      user.validate_arrived_at_date

      message = user.errors.messages[:arrived_at]
      expect(message || []).not_to include(error_message)
    end

    it 'adds *no* error if arrived at is nil' do
      user = FactoryBot.build(:user, arrived_at: nil)
      user.validate_arrived_at_date

      message = user.errors.messages[:arrived_at]
      expect(message || []).not_to include(error_message)
    end
  end

  describe '#find_token' do
    context 'valid token' do
      it 'returns token' do
        token = FactoryBot.create(:token)

        expect(User.find_token(token.token)).to eq(token)
      end
    end

    context 'expired token' do
      it 'returns nil' do
        token = FactoryBot.create(:expired_token)

        expect(User.find_token(token.token)).to be_nil
      end
    end
  end

  it 'has translations for all User statuses' do
    User::STATUSES.each_key do |status_name|
      name = I18n.t("user.statuses.#{status_name}", locale: :en)
      description = I18n.t("user.statuses.#{status_name}_description", locale: :en)

      expect(name).not_to include('translation missing')
      expect(description).not_to include('translation missing')
    end
  end
end

# == Schema Information
#
# Table name: users
#
#  id                               :integer          not null, primary key
#  email                            :string
#  phone                            :string
#  description                      :text
#  created_at                       :datetime         not null
#  updated_at                       :datetime         not null
#  latitude                         :float
#  longitude                        :float
#  language_id                      :integer
#  password_hash                    :string
#  password_salt                    :string
#  admin                            :boolean          default(FALSE)
#  street                           :string
#  zip                              :string
#  zip_latitude                     :float
#  zip_longitude                    :float
#  first_name                       :string
#  last_name                        :string
#  ssn                              :string
#  company_id                       :integer
#  banned                           :boolean          default(FALSE)
#  job_experience                   :text
#  education                        :text
#  one_time_token                   :string
#  one_time_token_expires_at        :datetime
#  ignored_notifications_mask       :integer
#  frilans_finans_id                :integer
#  frilans_finans_payment_details   :boolean          default(FALSE)
#  competence_text                  :text
#  current_status                   :integer
#  at_und                           :integer
#  arrived_at                       :date
#  country_of_origin                :string
#  managed                          :boolean          default(FALSE)
#  account_clearing_number          :string
#  account_number                   :string
#  verified                         :boolean          default(FALSE)
#  interview_comment                :text
#  next_of_kin_name                 :string
#  next_of_kin_phone                :string
#  arbetsformedlingen_registered_at :date
#  city                             :string
#  interviewed_by_user_id           :integer
#  interviewed_at                   :datetime
#  just_arrived_staffing            :boolean          default(FALSE)
#  super_admin                      :boolean          default(FALSE)
#  gender                           :integer
#  presentation_profile             :text
#  presentation_personality         :text
#  presentation_availability        :text
#  system_language_id               :integer
#  linkedin_url                     :string
#  has_welcome_app_account          :boolean          default(FALSE)
#  welcome_app_last_checked_at      :datetime
#  public_profile                   :boolean          default(FALSE)
#  anonymized_at                    :datetime
#  anonymization_requested_at       :datetime
#
# Indexes
#
#  index_users_on_company_id          (company_id)
#  index_users_on_email               (email) UNIQUE
#  index_users_on_frilans_finans_id   (frilans_finans_id) UNIQUE
#  index_users_on_language_id         (language_id)
#  index_users_on_one_time_token      (one_time_token) UNIQUE
#  index_users_on_system_language_id  (system_language_id)
#
# Foreign Keys
#
#  fk_rails_...                     (company_id => companies.id)
#  fk_rails_...                     (language_id => languages.id)
#  users_interviewed_by_user_id_fk  (interviewed_by_user_id => users.id)
#  users_system_language_id_fk      (system_language_id => languages.id)
#
