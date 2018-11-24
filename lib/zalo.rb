require 'selenium-webdriver'
require 'chromedriver-helper'
require 'rubygems'
# require 'pry'
require 'sendgrid-ruby'
require 'base64'
require 'fileutils'
# require 'dotenv/load'
require 'redis'

class Zalo
  include SendGrid

  @@driver = nil
  @@redis = nil

  def self.current_session
    if @@driver
      puts "Using previous brower session"
    else
      puts "Create a new brower session"
    end

    return @@driver if @@driver

    capabilities = Selenium::WebDriver::Remote::Capabilities.chrome(chromeOptions: { args: %w(headless no-sandbox start-maximized disable-infobars disable-extensions) } )
    # @@driver = Selenium::WebDriver.for :remote, url: "http://127.0.0.1:4444/wd/hub", desired_capabilities: capabilities
    @@driver = Selenium::WebDriver.for :chrome, desired_capabilities: capabilities # for destop
    @@driver.navigate.to 'https://chat.zalo.me/'
    sleep(3)

    @@driver
  end

  def self.get_owner_info(phone)
    puts "\n= = = = Fetching data of #{phone} = = = =\n"
    data = load(phone)

    if data
      puts "Load data from cache instead of from Zalo server for #{phone}"
      return data
    end

    prepare_zalo_search_from

    clear_search_fields

    search_field = current_session.find_element(css: '[data-translate-placeholder="STR_INPUT_PHONE_NUMBER"]') rescue nil
    search_field.send_key(phone) if search_field

    # Click btn find
    current_session.find_element(css: '[data-translate-inner="STR_FIND_FRIEND"]').click  rescue nil
    sleep(1)

    username = current_session.find_element(class: 'usname').text rescue nil

    owner_info =
      if username
        gender = current_session.find_element(css: '[data-translate-inner="STR_GENDER_MALE"]') rescue nil
        gender = gender ? 'Nam' : 'Nữ'
        
        avatar = current_session.find_element(css: '.avatar.avatar--profile.clickable .avatar-img.outline') rescue nil
        avatar = avatar.css_value('background-image').scan(/https:\/\/.*\"/).first.gsub("\"", '') rescue ''
        
        clear_search_fields
        store phone, { avatar: avatar, phone: phone, name: username, gender: gender }
      else
        puts 'Not Found'
        JSON.parse({ 'avatar': 'https://www.gravatar.com/avatar/xxx.jpg', 'phone': phone, 'name': 'Unknown', 'gender': 'Unknown' }.to_json)
      end

    puts "\n= = = = Fetched data of #{phone} - #{owner_info} = = = =\n"
    owner_info
  end

  def self.login
    # Change to QR tab
    qr_tab = current_session.find_element(css: '.body-container > div > .tabs > ul > li:last-child a') rescue nil
    if qr_tab
      qr_tab.click
    else
      puts 'Using previous user session'
      return
    end

    @@folder_path = File.join(File.dirname(__FILE__), "zalo_qr_codes")
    FileUtils.remove_dir(@@folder_path, true)
    FileUtils.mkdir_p(@@folder_path)
    
    capture_qr_code_and_send_email

    until (current_session.find_element(id: 'inviteBtn') rescue nil)
      sleep(3)
      qr_expired = current_session.find_element(css: '.qrcode-expired') rescue nil
      if qr_expired && qr_expired.css_value('display') == 'block'
        qr_expired.click if qr_expired
        capture_qr_code_and_send_email
        puts 'Reload QR Code'
      end
    end
  end

  def self.clear_search_fields
    # Clear
    current_session.find_element(css: '.btn.clearBtn.flx-fix.fa.fa-clear').click rescue ''    

    # fill phone number
    search_field = current_session.find_element(css: '[data-translate-placeholder="STR_INPUT_PHONE_NUMBER"]') rescue nil
    20.times { search_field.send_key(Selenium::WebDriver::Keys::KEYS[:backspace]) } if search_field
  end

  def self.capture_qr_code_and_send_email
    # Save screenshot QR code and send to email
    qr_name = "qr_code_#{Time.now.to_i}.png"
    file_path = File.join(@@folder_path, qr_name)
    current_session.manage.window.resize_to(350, 600)
    current_session.save_screenshot(file_path)
    current_session.manage.window.resize_to(1400, 700)
    send_email_qr_code(file_path).to_json
  end

  def self.prepare_zalo_search_from
    login # login follow
    until (current_session.find_element(css: '.modal.animated.fadeIn.appear') rescue nil)
      current_session.find_element(id: 'inviteBtn').click rescue nil
      sleep(3)
    end
  end

  def self.send_email_qr_code(file_path)
    puts 'Sending email with QR code ...'
    from = SendGrid::Email.new(email: 'zalo_qr_code@hiepdinh.info')
    to = SendGrid::Email.new(email: ENV['EMAIL_RECEIVE_QR_CODE'])
    subject = 'Zalo QR Code Login'
    content = SendGrid::Content.new(type: 'text/plain', value: 'Using Zalo App scan this QR code to login your account')
    mail = SendGrid::Mail.new(from, subject, to, content)

    attachment = Attachment.new
    attachment.content = Base64.strict_encode64(open(file_path).to_a.join)
    attachment.type = 'image/png'
    attachment.filename = file_path.split('/')[-1]
    attachment.disposition = 'attachment'
    attachment.content_id = 'QR Code'
    mail.add_attachment(attachment)

    sg = SendGrid::API.new(api_key: ENV['SENDGRID_API_KEY'])
    response = sg.client.mail._('send').post(request_body: mail.to_json)
    response
  end

  def self.redis_connection
    @@redis ||= Redis.new(url: ENV['REDIS_URL']) 
  end

  def self.store(phone, data)
    puts "Storing data for #{phone} ... OK"
    data = data.to_json if data.is_a?(Hash)
    redis_connection.set(phone, data)
    load(phone)
  end

  def self.load(phone)
    print "Loading data for #{phone} ... "
    data = redis_connection.get(phone)
    
    if data
      print "OK\n"
      JSON.parse(data)
    else
      print "Fail (maybe key not existed)\n"
    end
  end
end
