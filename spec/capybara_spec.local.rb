require 'spec_helper'
require 'sauce_whisk'
require 'capybara/rspec'
require 'selenium-webdriver'

RSpec.configure do |config|
  config.include Capybara::DSL
end

describe 'a browser', :js => true do
  before do |scenario|
    Capybara.app = SequenceServer.init
    Capybara.server = :webrick
    Capybara.javascript_driver = :selenium
    Capybara.default_max_wait_time = 10

    options = ::Selenium::WebDriver::Firefox::Options.new
    options.args << '--headless'
    Capybara.register_driver :selenium do |app|
      Capybara::Selenium::Driver.new(app, browser: :firefox, options: options)
    end
  end

  it 'properly controls blast button' do
    visit '/'

    fill_in('sequence', with: nucleotide_query)
    page.evaluate_script("$('#method').is(':disabled')").should eq(true)

    check(nucleotide_databases.first)
    page.evaluate_script("$('#method').is(':disabled')").should eq(false)
  end

  it 'properly controls interaction with database listing' do
    visit '/'
    fill_in('sequence', with: nucleotide_query)
    check(nucleotide_databases.first)
    page.evaluate_script("$('.protein .database').first().hasClass('disabled')")
      .should eq(true)
  end

  it 'shows a dropdown menu when other blast methods are available' do
    visit '/'
    fill_in('sequence', with: nucleotide_query)
    check(nucleotide_databases.first)
    page.save_screenshot('screenshot.png')
    page.has_css?('button.dropdown-toggle').should eq(true)
  end

  it 'can run a simple blastn search' do
    perform_search query: nucleotide_query,
      databases: nucleotide_databases
  end

  it 'can run a simple blastp search' do
    perform_search query: protein_query,
      databases: protein_databases
  end

  it 'can run a simple blastx search' do
    perform_search query: nucleotide_query,
      databases: protein_databases
  end

  it 'can run a simple tblastx search' do
    perform_search query: nucleotide_query,
      databases: nucleotide_databases,
      method: 'tblastx'
  end

  it 'can run a simple tblastn search' do
    perform_search query: protein_query,
      databases: nucleotide_databases
  end

  ### Test more aspects of the generated report.

  it 'disables sequence viewer links if hits are longer than 10kb' do
    # Do a BLASTN search.
    perform_search query: nucleotide_query, databases: nucleotide_databases

    # The above function has already tested that the report loaded.
    # Additionally check that the sequence viewer links are disabled.
    page.evaluate_script("$('.view-sequence').is(':disabled')").should eq(true)
    page.evaluate_script("$('.view-sequence').is('.disabled')").should eq(true)
  end

  ## Helpers ##

  def perform_search(query: , databases: , method: nil)
    # Load search form.
    visit '/'

    # Fill in query, select databases, submit form.
    fill_in('sequence', with: query)
    databases.each { |db| check db }
    if method == 'tblastx'
      find('.dropdown-toggle').click
      find('.dropdown-menu li').click
    end
    click_button('method')

    # switch to new window because link opens in new window
    page.driver.browser.switch_to.window(page.driver.browser.window_handles.last)

    # Check that results loaded.
    page.should have_content('Query')
  end

  def nucleotide_query
    File.read File.join __dir__, 'nucleotide_query.fa'
  end

  def protein_query
    File.read File.join __dir__, 'protein_query.fa'
  end

  def nucleotide_databases
    [
      'Solenopsis invicta gnG subset',
      'Sinvicta 2-2-3 cdna subset'
    ]
  end

  def protein_databases
    [
      'Sinvicta 2-2-3 prot subset',
      '2018-04 Swiss-Prot insecta'
    ]
  end
end
