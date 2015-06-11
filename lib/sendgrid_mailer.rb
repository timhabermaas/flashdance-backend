require "pony"
require "erb"

class SendgridMailer
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

  def send_confirmation_mail order
    return if order.email.nil? || order.email.empty?

    body = <<-EOS
Vielen Dank für Ihre Kartenreservierung zu „FLASHDANCE – The Musical“ der HGR Musical AG.

Bitte überweisen Sie den Betrag von

<%= "%.2f" % order.total_cost.fdiv(100) %> €

innerhalb der nächsten 5 Werktage unter Angabe der Nummer

<%= order.number %>

als Betreff auf folgendes Konto:

Förderverein der Hermann-Greiner-Realschule Neckarsulm
IBAN DE64 6205 0000 0001 3930 60
BIC HEISDE66XXX
KSK Heilbronn


Das Team der HGR Musical AG bedankt sich und wünscht Ihnen viel Spaß in den Eighties mit „FLASHDANCE“!



Die Musical-AG der
Hermann-Greiner-Realschule Neckarsulm
Steinachstraße 70
74172 Neckarsulm

ticketing@hgr-musical.de
www.hgr-musical.de
    EOS

    body = ERB.new(body).result(binding)

    Pony.mail(to: order.email, from: "ticketing@hgr-musical.de", subject: "Ihre Ticket-Bestellung für „FLASHDANCE – The Musical“", body: body)
  end
end
