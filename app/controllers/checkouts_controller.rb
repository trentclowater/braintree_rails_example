require 'sendgrid-ruby'

class CheckoutsController < ApplicationController
  include SendGrid

  TRANSACTION_SUCCESS_STATUSES = [
    Braintree::Transaction::Status::Authorizing,
    Braintree::Transaction::Status::Authorized,
    Braintree::Transaction::Status::Settled,
    Braintree::Transaction::Status::SettlementConfirmed,
    Braintree::Transaction::Status::SettlementPending,
    Braintree::Transaction::Status::Settling,
    Braintree::Transaction::Status::SubmittedForSettlement,
  ]

  def new
    @client_token = Braintree::ClientToken.generate
  end

  def show
    @transaction = Braintree::Transaction.find(params[:id])
    @result = _create_result_hash(@transaction)
  end

  def create
    amount = params["amount"] # In production you should not take amounts directly from clients
    nonce = params["payment_method_nonce"]

    result = Braintree::Transaction.sale(
      amount: amount,
      payment_method_nonce: nonce,
      :options => {
        :submit_for_settlement => true
      }
    )

    if result.success? || result.transaction
      redirect_to checkout_path(result.transaction.id)

      from = Email.new(email: 'commender-payments-demo@example.com')
      subject = 'Your Bayshore Pacific Hospitality Card!'
      to = Email.new(email: params['email'])
      content = Content.new(type: 'text/plain', value: 'Congratulations! You can now start enjoying a 20% discount!\n\nShow this confirmation email to your server at any Bayshore Pacific Hospitality restaurant to receive 20% off your bill.\n\nYour Bayshore Pacific Hospitality VIP confirmation number is: 123 456 789 101\n\nBayshore Pacific Hospitality brands include: TGI Fridays (Taiwan Only)\n\nTexas Roadhouse (Taiwan Only)\n\nDan Ryan\'s Chicago Grill\n\nAmaroni\'s New York Italian Cafe & Restaurant\n\nThanks for joining! The BPH Team\nwww.bayshorepacifichospitality.com\nVIP Card Terms & Conditions\nwww.bayshorepacifichospitality.com/terms.htm')
      mail = Mail.new(from, subject, to, content)

      sg = SendGrid::API.new(api_key: ENV['SENDGRID_API_KEY'])
      sg.client.mail._('send').post(request_body: mail.to_json)

    else
      error_messages = result.errors.map { |error| "Error: #{error.code}: #{error.message}" }
      flash[:error] = error_messages
      redirect_to new_checkout_path
    end
  end

  def _create_result_hash(transaction)
    status = transaction.status

    if TRANSACTION_SUCCESS_STATUSES.include? status
      result_hash = {
        :header => "You are a Bayshore Pacific Hospitality VIP!",
        :icon => "success",
        :message => "You will receive a confirmation email you can show to start receiving your 20% discount right away. A physical card will be provided to your credit card mailing address within 14 days."
      }
    else
      result_hash = {
        :header => "Sorry, there was a problem processing your transaction.",
        :icon => "fail",
        :message => "Your transaction has a status of #{status}. Please try again."
      }
    end
  end
end
