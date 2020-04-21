require 'uuid'
require 'open-uri'
require 'data_uri'
require 'base64'

PROCESSING_SERVER = 384837878275899394

bot = Discordrb::Bot.new token: ENV["BOT_TOKEN"]

puts "This bot's invite URL is #{bot.invite_url(permission_bits: 1074064448)}."

lock = Mutex.new

def download_file(string)
  filename = "/tmp/emote" + string.match(/\.\w+$/)[0]
  open(filename, "wb") do |file|
    open(string) do |uri|
      file.write(uri.read)
    end
  end
  return filename
end

bot.message do |event|
  if event.channel.name == "emote_submissions"
    attachments = event.message.attachments
    if attachments.size == 1
      image = attachments[0]
      if image.image?
        lock.synchronize do
          filepath = download_file(image.url)
          # system "gm convert #{filepath} -resize 128x128^ -gravity center -extent 128x128  #{filepath}"
          system "gm convert #{filepath} -resize 128x128^ #{filepath}"
          encode_type = case filepath.match(/\w$/)[0]
                        when "jpg", "jpeg"
                          "jpeg"
                        when "png"
                          "png"
                        when "gif"
                          "gif"
                        else
                          ""
                        end
          if File.size(filepath) > 256000
            event.channel.send_message("File too beeg! #{File.size(filepath) / 2560}% of the maximum file size!")
          else
            data_uri = "data:image/#{encode_type};base64," + Base64.encode64(File.open(filepath, "r").read).to_s
            Discordrb::API::Server.add_emoji(bot.token, event.channel.server.id, data_uri, "preview")
            sleep 1
            previews = event.channel.server.emoji.select{|i, e| e.name == "preview"}
            event.channel.send_message(previews.values.first.to_s)
            previews.keys.each do |e|
              Discordrb::API::Server.delete_emoji(bot.token, event.channel.server.id, e)
            end
          end
          File.delete(filepath)
        end
      end
    end
  end
end

bot.reaction_add do |event|
  if event.channel.name == "emote_submissions" && event.emoji == "⭐"
    lock.synchronize do
      attachments = event.message.attachments
      if attachments.size == 1
        image = attachments[0]
        if image.image?
          filepath = download_file(image.url)
          # system "gm convert #{filepath} -resize 128x128^ -gravity center -extent 128x128  #{filepath}"
          system "gm convert #{filepath} -resize 128x128^ #{filepath}"
          if event.user
            event.user.send_file(File.open(filepath, "r"))
          end
          File.delete(filepath)
        end
      end
    end
  end
end

bot.run
