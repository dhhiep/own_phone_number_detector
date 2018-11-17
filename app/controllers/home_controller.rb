require 'capybara'
require 'selenium-webdriver'
require 'chromedriver-helper'
require 'capybara-webkit'
require 'pry'
require 'rubygems'
require 'capybara/dsl'

class HomeController < ApplicationController
  include Capybara::DSL

  def index
    @search_form = params[:search].presence || {}
    if @search_form.present?
      @phones = @search_form[:phones].to_s.split(',').reject(&:blank?)
      if @phones.any?
         @phones.each do |phone|
          # Capybara.current_driver = :selenium
          # Capybara.app_host = 'http://www.google.com'
          driver = Selenium::WebDriver.for :chrome
          driver.navigate.to 'https://chat.zalo.me/'

          phone_field = driver.find_element(name: 'phone_num')
          phone_field.send_keys "0785286828"
          pass_field = driver.find_element(css: "input[placeholder='Mật khẩu']")
          pass_field.send_keys "xxxx"

          submit_button = driver.find_element(link: "Đăng nhập với mật khẩu")
          submit_button.click
         end
      end
    end
    
  end
end
