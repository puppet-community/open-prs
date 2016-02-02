require 'sinatra'
require 'sinatra/flash'
require 'octokit'
require 'httparty'
require 'faraday-http-cache'
require 'json'
require './app_helpers'

enable :sessions
set :session_secret, (ENV["SESSION_SECRET"] || "this is session secret")

stack = Faraday::RackBuilder.new do |builder|
  builder.use Faraday::HttpCache
  builder.use Octokit::Response::RaiseError
  builder.adapter Faraday.default_adapter
end
Octokit.middleware = stack

get '/' do
  erb :'index'
end

get '/pulls' do
  client = set_client
  # user_login = client.user.login
  user_login = session[:user]
  query = "user:voxpupuli is:pr is:open created:>2014-01-01"
  issues = [Thread.new { client.search_issues(query).items }]
  url_regex = /.+repos\/(?<org>.+)\/(?<repo>.+)\/pulls\/(?<number>\d+)/
  @pulls = issues.flat_map { |issue|
    issue.value.each { |pull|
      captures = pull.pull_request.url.match(url_regex)
      pull[:org] = captures[:org]
      pull[:repo] = captures[:repo]
      pull[:number] = captures[:number]
    }
  }
  @pulls = @pulls.sort_by { |p|
    p[:org]
  }.group_by { |p|
    p[:org]
  }
  erb :'pulls'
end

get '/about' do
  erb :'about'
end

get '/pull_icons' do
  pull = {}
  client = set_client
  pull[:issue_comments] = begin
     client.issue_comments(
      "#{params[:org]}/#{params[:repo]}",
      "#{params[:number]}"
    )
  rescue
     []
  end
  pull[:pull_comments] = begin
    client.pull_comments(
      "#{params[:org]}/#{params[:repo]}",
      "#{params[:number]}"
    )
  rescue
    []
  end

  erb :'_pull_icons', layout: false, locals: { pull: pull }
end
