# encoding: utf-8

LOG_OUTPUT_DEBUG = false

LOG_LEVELS = {
  1 => 'ERROR',
  2 => 'WARN',
  3 => 'INFO',
  4 => 'DEBUG'
}

module Log

  def self.err(msg)
    log(1, msg)
  end

  def self.warn(msg)
    log(2, msg)
  end

  def self.info(msg)
    log(3, msg)
  end

  def self.debug(msg)
    log(4, msg)
  end

  def self.log(level, msg)

	if LOG_OUTPUT_DEBUG || level!=4
      outstr = "[#{DateTime.now}] #{LOG_LEVELS[level]} #{msg}"
      if level <= 2
        print "\e[31m"
      elsif level <= 3
        print "\e[32m"
      end
	  puts "#{outstr}"
      print "\e[0m"
	end

  end

end
