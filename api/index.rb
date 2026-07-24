require 'net/http'
require 'json'
require 'uri'

Handler = Proc.new do |request, response|
  response.status = 200
  response['Content-Type'] = 'application/json; charset=utf-8'

  # Jika diakses via GET (buka link di browser)
  if request.request_method == 'GET'
    response.body = { status: 'Vercel Ruby AI Bridge is running! 🚀' }.to_json
    next
  end

  # Jika diakses via POST (dari bot Node.js)
  begin
    # Tangani request.body apakah berupa String atau objek Stream
    raw_body = if request.body.respond_to?(:read)
                 request.body.read
               else
                 request.body.to_s
               end

    request_payload = JSON.parse(raw_body) rescue {}
    prompt = request_payload['prompt']

    if prompt.nil? || prompt.strip.empty?
      response.status = 400
      response.body = { error: 'Prompt tidak boleh kosong!' }.to_json
      next
    end

    groq_api_key = ENV['GROQ_API_KEY']
    unless groq_api_key
      response.status = 500
      response.body = { error: 'Groq API Key belum disetting di Environment Variables Vercel!' }.to_json
      next
    end

    uri = URI('https://api.groq.com/openai/v1/chat/completions')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    req = Net::HTTP::Post.new(uri)
    req['Authorization'] = "Bearer #{groq_api_key}"
    req['Content-Type'] = 'application/json'

    req.body = {
      model: 'llama-3.3-70b-versatile',
      messages: [
        { role: 'system', content: 'Kamu adalah AIKO, asisten virtual WhatsApp yang cerdas, ramah, dan membantu.' },
        { role: 'user', content: prompt }
      ],
      temperature: 0.7
    }.to_json

    api_response = http.request(req)

    if api_response.is_a?(Net::HTTPSuccess)
      data = JSON.parse(api_response.body)
      reply_text = data.dig('choices', 0, 'message', 'content')
      response.body = { status: 'success', response: reply_text }.to_json
    else
      response.status = 500
      response.body = { error: "Groq API Error: #{api_response.code}" }.to_json
    end

  rescue StandardError => e
    response.status = 500
    response.body = { error: "Ruby Error: #{e.message}" }.to_json
  end
end
