desc "This task is called by Heroku scheduler add-on"
task :update_feed => :enviroment do
  require 'line/bot'
  require 'open-uri'
  require 'kconv'
  require 'rexml/document'

  client ||= Line::Bot::Client.new { |config|
    config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
    config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
  }

  url = "https://www.drk7.jp/weather/xml/27.xml"

  xml = open( url ).read.toutf8
  doc = REXML::Document.new(xml)

  xpath = 'weatherforecast/pref/area[1]/info/rainfallchance/'

  per06to12 = doc.elements[xpath + 'period[2]'].text
  per12to18 = doc.elements[xpath + 'period[3]'].text
  per18to24 = doc.elements[xpsth + 'period[4]'].text

  min_per = 20
  if per06to12.to_i >= min_per || per12to18.to_i >= min_per || per18to24.to_i >= min_per
    word1 =
      ["おはようございます!",
       "今日も1日頑張りましょう！！",
       "昨日は良い1日でしたか？",
       "今日の段取りを考えよう"].sample
    word2 =
      ["今日も良い1日でありますように"
       "体調管理に気をつけてください"
       "ゆとりをもった段取りを心がけてください"
       "楽しい事がありますように"].sample
    mid_per = 50
    if per06to12.to_i >= mid_per || per12to18.to_i >= mid_per || per18to24.to_i >= mid_per
      word3 = "今日は雨が降りそう！傘を忘れないでください！"
    begin
      word3 = "今日は雨が降るかもしれないから折り畳み傘がを持っていった方がいいですよ!"
    end

    push =
      "#{word1}\n#{word3}\n今日の降水確率は\n 6〜12時 #{per06to12}%\n 12〜18時 #{per12to18}%\n 18〜24時 #{per18to24}%\n#{word2}"
    user_ids = User.all.pluck(:line_id)
    message = {
      type: 'text',
      text: push
    }
    response = client.multicast(user_ids, message)
  end
  "OK"
end
