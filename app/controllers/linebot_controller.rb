class LinebotController < ApplicationController
  require 'line/bot'
  require 'open-uri'
  require 'kconv'
  require 'rexml/document'
  # クロスサイトリクエストフォージェリ (CSRF)への対応策のコード
  protect_from_forgery :except => [:callback]

  def callback
    body = request.body.read
    signature = request.env['HTTP_X_LINE_SIGNATURE']
    unless client.validate_signature(body, sinature)
      return head :bad_request
    end
    events = client.parse_events_form(body)
    events.each { |event|
      case event
        # メッセージが送信された場合の対応（機能①）
      when Line::Bot::Event::Message
        case event.type
          # ユーザーからテキスト形式のメッセージが送られて来た場合
        when Line::Bot::Event::MessageType::Text
          # event.message['text']：ユーザーから送られたメッセージ
          input = event.message['text']
          url = "https://www.drk7.jp/weather/xml/27.xml"
          xml = open( url ).read.toutf8
          doc = REXML::Document.new(xml)
          xpath = 'weatherforecast/pref/area[4]/'
          min_per =30
          case input
          when /.*(明日|あした).*/
            # info[2]:明日の天気
            per06to12 = doc.elements[xpath + 'info[2]/rainfallchance/period[2]'].text
            per12to18 = doc.elements[xpath + 'info[2]/rainfallchance/period[3]'].text
            per18to24 = doc.elements[xpath + 'info[2]/rainfallchance/period[4]'].text
            if per06to12.to_i >= min_per || per12to18.to_i >= min_per || per18to24.to_i >= min_per
              push =
                "明日の天気は、\雨が降りそうです。\n今のところ降水確率は\n 6〜12時 #{per06to12}%\n 12〜18時 #{per12to18}%\n 18〜24時 #{per18to24}%\nまた明日の朝の最新の天気予報を確認してください"
            else
              push =
                "明日の天気は\n明日は雨が降らない予定です\nまた明日の朝の最新の天気予報を確認してください"
            end
          when /.*(明後日|あさって).*/
            per06to12 = doc.elements[xpath + 'info[3]/rainfallchance/period[2]'].text
            per12to18 = doc.elements[xpath + 'info[3]/rainfallchance/period[3]'].text
            per18to24 = doc.elements[xpath + 'info[3]/rainfallchance/period[4]'].text
            if per06to12.to_i >= min_per || per12to18.to_i >= min_per || per18to24.to_i >= min_per
              push =
                "明後日の天気は、\雨が降りそうです。\n今のところ降水確率は\n 6〜12時 #{per06to12}%\n 12〜18時 #{per12to18}%\n 18〜24時 #{per18to24}%\nまた当日の朝の最新の天気予報を確認してください"
            else
              push =
                "明後日の天気は\n雨が降らない予定です\nまた当日の朝の最新の天気予報を確認してください"
            end
          when /.*(かわいい|可愛い|カワイイ|きれい|綺麗|キレイ|素敵|ステキ|すてき|面白い|おもしろい|ありがと|すごい|スゴイ|スゴい|好き|頑張|がんば|ガンバ|ありがとう|有り難う|有難う).*/
            push =
              "ありがとうございます！\n優しい言葉をかけてくれるあなたはとても素敵です"
          when /.*(こんにちは|こんばんは|初めまして|はじめまして|おはよう).*/
            push =
              "こんにちは。\n声をかけてくれてありがとうございます\n今日があなたにとっていい日になりますように"
          else
            per06to12 = doc.elements[xpath + 'info/rainfallchance/period[2]l'].text
            per12to18 = doc.elements[xpath + 'info/rainfallchance/period[3]l'].text
            per18to24 = doc.elements[xpath + 'info/rainfallchance/period[4]l'].text
            if per06to12.to_i >= min_per || per12to18.to_i >= min_per || per18to24.to_i >= min_per
              word =
                ["雨の音っていいですよね",
                 "雨も降らないと水不足になりますから",
                 "天気は雨ですけど、気分は晴れで行きましよう"].sample
              push =
                "今日の天気は\n雨が降りそうだから傘があった方が安心ですね\n 6〜12時 #{per06to12}%\n 12〜18時 #{per12to18}%\n 18〜24時 #{per18to24}%\n{word}"
            else
              word =
                ["今日は天気が良いですね！少し散歩をしてはいかがでしょうか？",
                 "天気が良いと気分も晴れてきますね",
                 "こんな天気が良いのに、良い日にならない訳がないですね",
                 "今日は全てが上手くいく気がしますね"].sample
              push =
                "今日の天気は\n気分は晴れです(笑)\n#{word}"
            end
          end
          # テキスト以外(画像等)のメッセージが送られた場合
        else
          push = "テキスト以外は答えられません。。"
        end
        message = {
          type: 'text',
          text: push
        }
        client.teply_message(event['replyToken'], message)
        # LINEお友達追加された場合(機能②)
      when Line::Bot::Event::Follow
        # 登録したユーザーのidをユーザーテーブルに格納
        line_id = event['source']['userId']
        User.create(line_id: line_id)
        # LINEお友達解除された場合(機能③)
      when Line::Bot::Event::Unfollow
        # お友達解除したユーザーのデータをユーザーテーブルから削除
        line_id = event['source']['userId']
        User.create(line_id: line_id)
        # お友達解除したユーザーのデータをユーザーテーブルから削除
        line_id = event['source']['userId']
        User.find_by(line_id: line_id).destroy
      end
    }
    head :ok
  end

  private

  def client
    @client ||= Line::Bot::Client.new { |config|
      config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
      config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
    }
  end
end
