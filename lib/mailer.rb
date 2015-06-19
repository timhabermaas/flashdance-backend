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
<% elsif order.pick_up_beforehand? %>
Falls noch nicht geschehen, können Sie Ihre Karten an der HGR abholen (Mo. – Fr., 13.00 – 14.30 Uhr, Raum 234).
Bitte halten Sie einen Ausdruck dieser E-Mail bei der Abholung bereit.
<% else %>
Die Tickets werden am Aufführungstag auf Ihren Namen an der Abendkasse für Sie hinterlegt.
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

<% if order.pick_up_beforehand? %>
Bitte holen Sie Ihre Karten gegen Barzahlung innerhalb der nächsten 5 Werktage an der HGR, Raum 234 ab oder
überweisen Sie den Betrag von
<% else %>
Bitte überweisen Sie den Betrag von
<% end %>

<%= format_price order.total_cost %>

innerhalb der nächsten 5 Werktage unter Angabe der Nummer

<%= order.number %>

als Betreff auf folgendes Konto:

Förderverein der Hermann-Greiner-Realschule Neckarsulm
IBAN DE64 6205 0000 0001 3930 60
BIC HEISDE66XXX
KSK Heilbronn

Bitte achten Sie bei der Bezahlung auf die Einhaltung des Zeitfensters, da ihre Reservierung ansonsten erlischt.
Das Team der HGR Musical AG bedankt sich und wünscht Ihnen viel Spaß in den Eighties mit „FLASHDANCE“!



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
