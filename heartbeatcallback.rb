class HeartbeatCallback
  
  def initialize(beat, wipe)
    @beat, @wipe = beat, wipe
  end
  
  def call(monitor)
    $logger.debug "Reading heartbeat data."
    heartbeat = (monitor.io.readpartial(2) rescue nil || "")
    if heartbeat == "OK"
      $logger.debug "#{monitor.io.remote_address} is OK."; @beat.call
    else
      $logger.error "Message from #{monitor.io.remote_address}: #{heartbeat}."; @wipe.call
    end
  end
  
end