require "d64/block"
require "d64/sector"

module D64
  class BlockMap < Sector

    def dump_map
      puts (1..35).map { |tn|
        ("%2s " % tn) << free_on_track(tn).map { |v| v ? '[ ]' : '[x]' }.join
      }.join "\n";
    end
    
    def free_on_track(tn)
      tv = track_value(tn)
      Image.sectors_per_track(tn).times.map do |sn|
        tv & (2 ** sn) != 0
      end
    end

    def free_blocks
      35.times.map { |i| bytes[4 * i + 4] }.reduce :+
    end

    def allocate(opts = {})
      if opts[:block]
        tn = opts[:block].track
        sn = opts[:block].sector
        free_on_track(tn)[sn] or
          fail "Can't allocate used sector [%s %02d:%02d]." % [@image.name, tn, sn]
      else
        tracks = (1..35).to_a
        if tn = opts[:trackpref]
          tracks.delete  opts[:trackpref]
          tracks.unshift opts[:trackpref]
        end
        sn = nil
        tracks.each do |tn|
          sn = free_on_track(tn).index(true)
          break if sn
        end
        return nil unless sn
      end
      mark_as_used tn, sn
      free_on_track(tn)[sn] and
        fail "Failed to mark as used!"
      puts 'Allocated sector [%s %02d:%02d]' % [@image.name, tn, sn] if ENV['DEBUG']
      Block.new(tn, sn)
    end

    def mark_as_used(tn, sn)
      byte, bit = sn.divmod(8)
      @bytes[4 * tn + 1 + byte] &= (255 - 2 ** bit)
      @bytes[4 * tn] -= 1
    end

    def mark_as_unused(tn, sn)
      byte, bit = sn.divmod(8)
      @bytes[4 * tn + 1 + byte] |= (2 ** bit)
      @bytes[4 * tn] += 1
    end

    def commit
      image.commit_bam
    end

    private

    def track_value(tn)
      a, b, c = bytes[4 * tn + 1, 3]
      (c << 16) + (b << 8) + a
    end
  end
end
