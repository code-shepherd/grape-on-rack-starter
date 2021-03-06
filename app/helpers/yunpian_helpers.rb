module YunpianHelpers
  include ::NetHelpers

  def template(code)
    "您的验证码是#{code}。如非本人操作，请忽略本短信"
  end

  def apikey
    ENV["YUNPIAN_API_KEY"]
  end

  def expires_in
    ENV["SMS_CODE_EXPIRES_IN"].to_i
  end

  def sendmsg_url
    "https://sms.yunpian.com/v2/sms/single_send.json"
  end

  def zone 
    params[:zone] ? "+#{params[:zone]}" : ""
  end

  def mobile
    "#{zone}#{params[:phone]}"
  end

  def respond(resp)
    {code: resp["code"], message: resp["msg"] || resp["detail"]}
  end

  def send_sms(phone:, channel:, action:)
    # generate code
    code = [*10000..99999].sample

    # send sms
    resp = post_https(sendmsg_url, { 
      apikey: apikey,
      mobile: mobile,
      text: template(code)
    })

    # write record
    SmsRecord.create(
      mobile: phone,
      code: code,
      result: resp,
      channel: channel,
      action: action,
      expired_at: Time.now + expires_in
    )

    respond(resp)
  end

  # phone => phone number
  # code => sms code
  def verify_sms!(phone:, code:)
    # query sms code by mobile number
    record = SmsRecord
      .where(mobile: phone, verified_at: nil)
      .order('created_at desc')
      .first

    raise V1::Errors::SendSmsCodeFirstError if record.nil?
    valid = (record.code == code && record.expired_at > Time.now)
    raise V1::Errors::SmsCodeWrongOrExpiredError if !valid
    record.update(verified_at: Time.now)
  end

end
