['../dispatchresponsepayload', '../dispatcherrorpayload'].each do |f|
  path = File.absolute_path(File.dirname(__FILE__) + '/' + f)
  puts "Requiring: #{path}."
  require path
end

Thread.abort_on_exception = true

class Dispatcher

  def initialize(extra_plugin_dir = nil)
    puts "Loading jar-file plugins."
    directory = File.dirname(__FILE__)
    plugin_directory = File.absolute_path(directory + "/../plugins")
    Dir[plugin_directory + '/*.rb'].each do |plugin| 
      begin
        puts "Loading plugin: #{plugin}."; require plugin
      rescue Exception => e
        puts "ERROR: Couldn't load plugin #{plugin}: #{e}."
      end
    end
    puts "Finished loading jar-file plugins."
    if extra_plugin_dir
      puts "Loading non-jar-file plugins."
      Dir[extra_plugin_dir + "/*.rb"].each do |plugin|
        begin
          puts "Loading external plugin: #{plugin}."; require plugin
        rescue Exception => e
          puts "ERROR: Couldn't load external plugin #{plugin}: #{e}."
        end
      end
      puts "Finished loading non-jar-file plugins."
    end
  end

  def dispatch(payload)
    unless (plugin = Plugins[payload.plugin])
      return ErrorResponse.new(:error_message => "#{payload.plugin} does not exist.")
    end
    unless (plugin.action_exists?(action = payload.action))
      return ErrorResponse.new(:error_message => "#{payload.plugin} does not support #{action}.")
    end
    begin
      puts "Getting response: plugin = #{payload.plugin}, action = #{action}."
      ResponsePayload.new(:plugin_response => plugin.act(action, payload.arguments))
    rescue Exception => e
      ErrorResponse.new(:error_message => e.message)
    end
  end

end
