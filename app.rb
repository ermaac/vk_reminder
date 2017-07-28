require 'sinatra'
require 'dotenv/load'
require 'sinatra/activerecord'
require 'omniauth'
require 'omniauth-vkontakte'
require_relative 'config/environment.rb'
require 'net/http'
require 'json'
require 'sinatra/flash'
require 'sinatra/redirect_with_flash'

VK_FRIENS_INFO = "https://api.vk.com/method/friends.get?fields=bdate&access_token="
FIRST_AUTHENTICATE_MESSAGE = "Authenticate first (Click Get Started)"
LOGOUT_MESSAGE = "Successfully logged out"
LOGIN_MESSAGE = "Succesfully logged in"
Dir.foreach('models') { |file| require_relative File.join('models', file) if file =~ /.+\.rb$/ }

use OmniAuth::Builder do
  provider :vkontakte, ENV['VK_CLIENT_ID'], ENV['VK_CLIENT_SECRET'], scope: 'offline'
end

enable :sessions
set :session_secret, ENV['SESSION_SECRET']

helpers do
  def get_friends_birthdate_info friends_info
    result = []
    friends_info.each do |friend|
      if friend['bdate']
        date = friend['bdate'].split('.')[0..1].join '.'
        fullname = "#{friend['first_name']} #{friend['last_name']}"
        result << {date: date, fullname: fullname}
      end
    end
    result
  end

  def sort_birthdates friends_birthdate_info
    friends_birthdate_info.sort! do |x, y|
      day_x, month_x = x[:date].split('.').map { |num| num.to_i }
      day_y, month_y = y[:date].split('.').map { |num| num.to_i }
      if month_x < month_y
        -1
      else
        month_x > month_y ? 1 : day_x <=> day_y
      end
    end
  end

  def get_full_friends_info token
    response = Net::HTTP.get URI(VK_FRIENS_INFO + token)
    JSON.parse(response)['response']
  end

  def get_birthdates_info uid
    user = User.find_by uid: uid
    token = user.access_token
    full_friends_info = get_full_friends_info token
    friends_birthdate_info  = get_friends_birthdate_info full_friends_info
    sort_birthdates friends_birthdate_info
  end

  def get_fullname full_info
    first_name = full_info['info']['first_name']
    last_name = full_info['info']['last_name']
    "#{first_name} #{last_name}"
  end

  def create_new_user full_info, uid
    User.find_or_create_by(uid: uid) do |user|
      user.fullname = get_fullname full_info
      user.photo_url = full_info['info']['image']
      user.access_token = full_info['credentials']['token']
    end
  end
end

get '/' do
  erb(:index)
end

get '/logout' do
  session.clear
  redirect '/', notice: LOGOUT_MESSAGE
end

get '/auth/vkontakte' do
end

get '/friends' do
  uid = session[:uid]
  user = User.find_by uid: uid
  redirect('/', error: FIRST_AUTHENTICATE_MESSAGE) unless uid
  friends_birthdate_info = get_birthdates_info uid
  erb :friends, locals: {friends_info: friends_birthdate_info, fullname: user.fullname, photo_url: user.photo_url}
end

get '/auth/vkontakte/callback' do
  uid = request.env['omniauth.auth']['uid']
  full_info = request.env['omniauth.auth']
  create_new_user full_info, uid
  session[:uid] = uid
  redirect :friends, notice: LOGIN_MESSAGE
end
