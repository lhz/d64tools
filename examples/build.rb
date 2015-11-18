#!/usr/bin/env ruby

$: << '../lib'

require 'd64tools'
require 'logger'

D64.logger.level = Logger::DEBUG

image = D64::Image.new(name: 'test', interleave: 7)
image.format 'EXAMPLE DISK', '64'

sizes = [3000]#, 5000, 1000, 16000, 7000, 2000, 800, 1500, 21000, 38000, 4000, 9000]
sizes.each_with_index do |len, i|
  image.add_file "TEST #{i}", [0x0D, 0x08] + len.times.map { rand 256 }
end

# image.directory.entries.first.dump

image.write 'test.d64'
