require 'sinatra'
require 'net/http'
require 'json'
require 'uri'

class RubyAIApp < Sinatra::Base
  post '/' do
    content_type :json
    
    request.body.rewind
    request_payload = JSON.parse(request.body.read) rescue {}
    prompt = request_payload['prompt']

    halt 400, { error: 'Prompt tidak boleh kosong!' }.to_json if prompt.nil? || prompt.strip.empty?

    groq_api_key = ENV['GROQ_API_KEY']
    halt 500, { error: 'Groq API Key belum disetting di Vercel!' }.to_json unless groq_api_key

    uri = URI('https://api.groq.com/openai/v1/chat/completions')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{groq_api_key}"
    request['Content-Type'] = 'application/json'

    request.body = {
      model: 'llama-3.3-70b-versatile',
      messages: [
        { role: 'system', content: 'Kamu adalah AIKO, asisten virtual WhatsApp yang cerdas, ramah, dan membantu.' },
        { role: 'user', content: prompt }
      ],
      temperature: 0.7
    }.to_json

    begin
      response = http.request(request)
      if response.is_a?(Net::HTTPSuccess)
        data = JSON.parse(response.body)
        reply_text = data.dig('choices', 0, 'message', 'content')
        { status: 'success', response: reply_text }.to_json
      else
        status 500
        { error: "Groq API Error: #{response.code}" }.to_json
      end
    rescue StandardError => e
      status 500
      { error: "Ruby Error: #{e.message}" }.to_json
    end
  end

  get '/' do
    { status: 'Vercel Ruby Sinatra AI Bridge is running! 🚀' }.to_json
  end
end

# Jalankan app untuk Vercel Serverless
object = RubyAIApp.new
object.call(Env.to_h) if defined?(Env)
