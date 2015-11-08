# D64tools

A Ruby gem with tools for working with D64 images (dumps of Commodore 1541 floppy disks.)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'd64tools', github: 'lhz/d64tools'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install d64tools

## Usage

There are several tools installed with this gem:

```
d64reserve <d64-image>
```
This tool will reserve track 35 in the BAM of the given d64 image, to avoid other tools adding files to the image using that track.

```
d64unreserve <d64-image>
```
This tool will free up track 35 in the BAM of the given d64 image, so that other tools may utilize that track again.

```
d64hide <d64-source-image> <d64-dirart-image> <d64-target-image>
```
This tool will move the directory from track 18 on the source image over to track 35, copy the directory from track 18 on the dirart image on to track 18 and store the result in the target image.

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/d64tools.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

