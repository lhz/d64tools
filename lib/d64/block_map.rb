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

    def allocate_with_interleave(prev = nil, interleave = 10)
      tn, sn = (prev ? [prev.track, prev.sector] : [1, 0])
      logger.info "Allocating with interleave #{interleave} relative to #{'[%02X:%02X]' % [tn, sn]}"
      block = D64::Image.interleaved_blocks(tn, interleave, sn || 0).find do |b|
        free_on_track(tn)[b.sector]
      end
      logger.info "Found free block #{block}"
      if block
        allocate block: block
      elsif tn < 35
        tnext = (tn == 17 ? 19 : tn + 1)
        sn = (sn + interleave + 5) % D64::Image.sectors_per_track(tnext)
        allocate_with_interleave Block.new(tnext, sn), interleave
      else
        fail "No room on disk!"
      end
    end

    def allocate(opts = {})
      if opts[:block]
        tn = opts[:block].track
        sn = opts[:block].sector
        free_on_track(tn)[sn] or
          fail "Can't allocate used sector [%s %02X:%02X]." % [@image.name, tn, sn]
      else
        tracks = (1..35).to_a
        if tn = opts[:trackpref]
          tracks.delete  opts[:trackpref]
          tracks.unshift opts[:trackpref]
        end
        tn = nil
        sn = nil
        tracks.each do |t|
          tn = t
          if sn && opts[:interleave]
            logger.debug "determine optimal track interleave from #{Block.new(tn - 1, sn)}"
            sn += 5 - opts[:interleave]
            sn += D64::Image.sectors_per_track(tn) if sn < 0
            logger.debug "jumped to #{Block.new(tn, sn)}"
          end
          if opts[:interleave]
            block = D64::Image.interleaved_blocks(tn, opts[:interleave], sn || 0).find do |block|
              free_on_track(tn)[block.sector]
            end
            sn = block.sector if block
          else
            sn = free_on_track(tn).index(true)
          end
          break if sn
        end
        return nil unless sn
      end
      mark_as_used tn, sn
      free_on_track(tn)[sn] and
        fail "Failed to mark as used!"
      block = Block.new(tn, sn)
      logger.debug "Allocated block #{block}"
      block
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

    def format(title, disk_id)
      title   = title.bytes[0, 16]
      disk_id = (disk_id + "  ").bytes[0, 2]
      dos_ver = "A".ord
      dos_id  = "2A".bytes
      @bytes[0x00, 2] = [18, 1]
      @bytes[0x02] = dos_ver
      @bytes[0x90, 27] = [0xA0] * 27
      @bytes[0x90, title.size] = title
      @bytes[0xA2, 2] = disk_id
      @bytes[0xA5, 2] = dos_id
      (1..35).each do |tn|
        D64::Image.sectors_per_track(tn).times do |sn|
          mark_as_unused tn, sn unless tn == 18 && sn < 2
        end
      end
      commit
    end

    def next_free_block
      @free_blocks ||= all_blocks
      block = @free_blocks.shift or
        fail "No free blocks left, disk full!"
      block.tap do |b|
        mark_as_used b.track, b.sector
      end
    end

    def next_free_dir_block
      @free_dir_blocks ||= all_dir_blocks
      block = @free_dir_blocks.shift or
        fail "No free directory blocks left!"
      block.tap do |b|
        mark_as_used b.track, b.sector
      end
    end

    def blocks_free
      @free_blocks.size
    end

    # private

    def all_blocks
      sn = 0
      tracks = [*1..35] - [18] + [nil] # FIXME: Don't hardcode dirtrack
      tracks.each_cons(2).with_object([]) do |(tn, tnext), blocks|
        tblocks = D64::Image.interleaved_blocks(tn, image.interleave, sn)
        if tnext
          sn = (tblocks.last.sector + image.interleave + 5) % D64::Image.sectors_per_track(tnext)
        end
        tblocks.each { |b| blocks << b } # blocks += tblocks won't work, why?
      end
    end

    def all_dir_blocks
      D64::Image.interleaved_blocks(18, 3, 1) # FIXME: Don't hardcode dirtrack
    end

    def track_value(tn)
      a, b, c = bytes[4 * tn + 1, 3]
      (c << 16) + (b << 8) + a
    end

    def logger
      D64.logger
    end
  end
end
