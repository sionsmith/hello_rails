# frozen_string_literal: true

# Rails default mailer config
class ApplicationMailer < ActionMailer::Base
  default from: 'from@example.com'
  layout 'mailer'
end
