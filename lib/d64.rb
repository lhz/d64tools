module D64
  class << self
    attr_writer :logger

    def logger
      @logger ||= Logger.new($stdout).tap do |log|
        log.progname = 'd64tools'
      end
    end
  end
end
