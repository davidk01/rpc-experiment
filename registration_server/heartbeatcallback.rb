class HeartbeatCallback
  
  def initialize(beat, wipe)
    @wipe = wipe; @machine = PartialReaderDSL::FiberReaderMachine.protocol do
      catch(:unrecognized_message) do
        loop do
          consume(2); buffer_transform do |ctx|
            if ctx.buffer == "OK"
              beat.call
            else
              $logger.error "Did not recognize heartbeat message: #{ctx.buffer}."
              wipe.call; throw :unrecognized_message
            end
          end
        end
      end
    end
  end
  
  def call(monitor)
    begin
      @machine.call(monitor.io)
    rescue EOFError
      @wipe.call; $logger.error "EOFError from #{monitor.io.remote_address}."
    end
  end
  
end
