require "erb"

class Mailer
  def initialize(postman)
    @postman = postman
  end

  def send_payment_confirmation_mail order
    body = <<-EOS
Guten Tag!

Wir haben Ihre Zahlung in Höhe von

<%= format_price order.total_cost %>

mit der Referenznummer

<%= order.number %>

für Ihre Eintrittskarten zu „FLASHDANCE – The Musical“ erhalten.

<% if order.delivery? %>
Die Tickets werden Ihnen in den nächsten Tagen an folgende Adresse zugesandt:
<%= order.address.street %>
<%= order.address.postal_code %> <%= order.address.city %>
<% else %>
Sie können Ihre Karten entweder am Tag der Aufführung an der Abendkasse oder vorab an der HGR abholen (Mo. – Fr., 13.00 – 14.30 Uhr, Raum 234).
Bitte halten Sie einen Ausdruck dieser E-Mail bei der Abholung bereit.
<% end %>

Das Team der HGR Musical AG bedankt sich und wünscht Ihnen viel Spaß in den Eighties mit „FLASHDANCE“!



Die Musical-AG der
Hermann-Greiner-Realschule Neckarsulm
Steinachstraße 70
74172 Neckarsulm

ticketing@hgr-musical.de
www.hgr-musical.de
EOS
    body = ERB.new(body).result(binding)

    @postman.mail(to: order.email, from: "ticketing@hgr-musical.de", bcc: "ticketing@hgr-musical.de", subject: "Bestätigung Zahlungseingang für Ihre Tickets zu „FLASHDANCE – The Musical“", body: body)
  end

  def send_confirmation_mail order
    return if order.email.nil? || order.email.empty?

    body = <<-EOS
Vielen Dank für Ihre Kartenreservierung zu „FLASHDANCE – The Musical“ der HGR Musical AG.

Bitte holen Sie Ihre Karten in den kommenden Tagen oder an der Abendkasse gegen Barzahlung des Betrags von

<%= format_price order.total_cost %>

unter Angabe der Nummer

<%= order.number %>

ab.



Die Musical-AG der
Hermann-Greiner-Realschule Neckarsulm
Steinachstraße 70
74172 Neckarsulm

ticketing@hgr-musical.de
www.hgr-musical.de
    EOS

    body = ERB.new(body).result(binding)

    @postman.mail(to: order.email, from: "ticketing@hgr-musical.de", bcc: "ticketing@hgr-musical.de", subject: "Ihre Ticket-Bestellung für „FLASHDANCE – The Musical“", body: body)
  end

  private
    def format_price(price)
      ("%.2f" % price.fdiv(100)) + " €"
    end
end
