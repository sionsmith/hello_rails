# frozen_string_literal: true

# Controller for pages
class PagesController < ApplicationController
  def home
    @greeting = 'Hello World!'
    @version = HelloRails::Application::VERSION
  end
end
