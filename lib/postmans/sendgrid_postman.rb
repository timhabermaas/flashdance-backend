require "pony"

class SendgridPostman
  def initialize(username, password)
    Pony.options = {
      :via => :smtp,
      :charset => 'UTF-8',
      :via_options => {
        :address => 'smtp.sendgrid.net',
        :port => '587',
        :domain => 'heroku.com',
        :user_name => username,
        :password => password,
        :authentication => :plain,
        :enable_starttls_auto => true
      }
    }
  end

  def mail options={}
    Pony.mail(options)
  end
end
