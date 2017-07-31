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

VK_FRIENS_INFO = 'https://api.vk.com/method/friends.get?fields=bdate&access_token='.freeze
FIRST_AUTHENTICATE_MESSAGE = 'Authenticate first (Click Get Started)'.freeze
LOGOUT_MESSAGE = 'Successfully logged out'.freeze
LOGIN_MESSAGE = 'Succesfully logged in'.freeze
Dir.foreach('models') { |file| require_relative File.join('models', file) if file =~ /.+\.rb$/ }
HIGHLIGHTING = {notice: 'alert-success', error: 'alert-danger'}.freeze

use OmniAuth::Builder do
  provider :vkontakte, ENV['VK_CLIENT_ID'], ENV['VK_CLIENT_SECRET'], scope: 'offline'
end

enable :sessions
set :session_secret, ENV['SESSION_SECRET']

helpers do
  def get_friends_birthdate_info(friends_info)
    friends_info.each_with_object([]) do |friend, result|
      next unless friend['bdate']
      date = friend['bdate'].split('.')[0..1].join '.'
      fullname = "#{friend['first_name']} #{friend['last_name']}"
      result << {date: date, fullname: fullname}
    end
  end

  def sort_birthdates(friends_birthdate_info)
    friends_birthdate_info.sort! do |x, y|
      day_x, month_x = x[:date].split('.').map(&:to_i)
      day_y, month_y = y[:date].split('.').map(&:to_i)
      if month_x < month_y
        -1
      else
        month_x > month_y ? 1 : day_x <=> day_y
      end
    end
  end

  def get_full_friends_info(token)
    response = Net::HTTP.get URI(VK_FRIENS_INFO + token)
    JSON.parse(response)['response']
  end

  def get_birthdates_info(uid)
    user = User.find_by uid: uid
    token = user.access_token
    full_friends_info = get_full_friends_info token
    friends_birthdate_info = get_friends_birthdate_info full_friends_info
    sort_birthdates friends_birthdate_info
  end

  def get_fullname(full_info)
    first_name = full_info.dig 'info', 'first_name'
    last_name = full_info.dig 'info', 'last_name'
    "#{first_name} #{last_name}"
  end

  def create_new_user(full_info, uid)
    User.find_or_create_by(uid: uid) do |user|
      user.fullname = get_fullname full_info
      user.photo_url = full_info.dig 'info', 'image'
      user.access_token = full_info.dig 'credentials', 'token'
    end
  end
end

get '/' do
  @message_type = :error if flash[:error]
  @message_type = :notice if flash[:notice]
  erb :index
end

get '/logout' do
  session.clear
  redirect '/', notice: LOGOUT_MESSAGE
end

get '/auth/vkontakte' do
end

get '/friends' do
  @message_type = :notice
  uid = session[:uid]
  @user = User.find_by uid: uid
  redirect('/', error: FIRST_AUTHENTICATE_MESSAGE) unless uid
  @friends_info = get_birthdates_info uid
  erb :friends
end

get '/auth/vkontakte/callback' do
  uid = request.env['omniauth.auth']['uid']
  full_info = request.env['omniauth.auth']
  create_new_user full_info, uid
  session[:uid] = uid
  redirect :friends, notice: LOGIN_MESSAGE
end
