# Own Phone Number Detector
This is a simple app to detect current owner of phone number via Zalo.

Solution log:
1. Using Zalo API to get owner information => I cant do it, beacause Zalo never reach that API.
2. Use https://chat.zalo.me/ with selenium-webdriver to get owner information on searchbar => Blocked by captcha
3. Still https://chat.zalo.me/ with selenium-webdriver to get owner information on searchbar, login with QR code it work well.
  + Input phone number
  + Selenium start brower and capture the QR code, after that it send to ENV['EMAIL_RECEIVE_QR_CODE']
  + Open Zalo app and scan this QR code to login
  + Index page will show result

Environment Variables:
  + ENV['EMAIL_RECEIVE_QR_CODE']
  + ENV['SENDGRID_API_KEY']

TODO:
  Apply redis cache to increase search time
