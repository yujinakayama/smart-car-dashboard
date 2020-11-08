# frozen_string_literal: true

class RaspividOptions
  Error = Class.new(StandardError)
  ValidationError = Class.new(Error)

  OptionValidator = Struct.new(:name, :type, :matcher) do
    def validate!(value)
      unless value.is_a?(type)
        raise ValidationError, "\"#{name}\" must be a value of #{type}"
      end

      return unless matcher

      matching =
        if matcher.respond_to?(:include?)
          matcher.include?(value)
        elsif matcher.respond_to?(:call)
          matcher.call(value)
        else
          raise
        end

      unless matching
        raise ValidationError, "\"#{name}\" value #{value.inspect} doesn't match #{matcher.inspect}"
      end
    end
  end

  def self.all_option_names
    @all_option_names ||= []
  end

  def self.define_option(name, type, matcher = nil)
    if type == String && matcher.nil?
      raise "A string option must have a validation matcher since it's extremely insecure"
    end

    name = name.to_sym

    validator = OptionValidator.new(name, type, matcher)

    attr_reader name

    define_method("#{name}=") do |value|
      validator.validate!(value)
      instance_variable_set("@#{name}", value)
    end

    all_option_names << name
  end

  # https://www.raspberrypi.org/documentation/raspbian/applications/camera.md

  define_option :sharpness, Integer, -100..100
  define_option :contrast, Integer, -100..100
  define_option :brightness, Integer, 0..100
  define_option :saturation, Integer, -100..100
  define_option :ISO, Integer, 100..800
  define_option :vstab, TrueClass
  define_option :ev, Integer, -10..10
  define_option :exposure, String, %w[auto night nightpreview backlight spotlight sports snow beach verylong fixedfps antishake fireworks]
  define_option :flicker, String, %w[off auto 50hz 60hz]
  define_option :awb, String, %w[off auto sun cloud shade tungsten fluorescent incandescent flash horizon greyworld]
  define_option :imxfx, String, %w[none negative solarise posterise whiteboard blackboard sketch denoise emboss oilpaint hatch gpen pastel watercolour film blur saturation colourswap washedout colourpoint colourbalance cartoon]
  define_option :colfx, String, proc { |string| string.match(/\A(\d+):(\d+)\z/)&.captures&.all? { |capture| capture.to_i.between?(0, 255) } }
  define_option :metering, String, %w[average spot backlit matrix]
  define_option :rotation, Integer, 0..359
  define_option :hflip, TrueClass
  define_option :vflip, TrueClass
  define_option :roi, String, proc { |string| string.match(/\A([01]\.\d+),([01]\.\d+),([01]\.\d+),([01]\.\d+)\z/)&.captures&.all? { |capture| capture.to_f.between?(0.0, 1.0) } }
  define_option :shutter, Integer, 0..nil
  define_option :drc, String, %w[off low med high]
  define_option :stats, TrueClass
  define_option :awbgains, String, proc { |string| string.match(/\A(\d\.\d+),(\d\.\d+)\z/)&.captures&.all? { |capture| capture.to_f.positive? } }
  define_option :analoggain, Float, 1.0..12.0
  define_option :digitalgain, Float, 1.0..64.0
  define_option :mode, Integer, 0..7

  define_option :width, Integer, 64..nil
  define_option :height, Integer, 64..nil
  define_option :bitrate, Integer, 0..nil
  define_option :framerate, Integer, 1..nil
  define_option :intra, Integer, 0..nil
  define_option :qp, Integer, 0..nil
  define_option :profile, String, %w[baseline main high]
  define_option :level, String, %w[4 4.1 4.2]
  define_option :irefresh, String, %w[cyclic adaptive both cyclicrows]
  define_option :inline, TrueClass
  define_option :spstimings, TrueClass
  # define_option :codec, String, %w[H264 MJPEG] # Support MJPEG in the future

  def initialize(hash)
    hash.each do |name, value|
      raise ValidationError, "No such option \"#{name}\"" unless respond_to?("#{name}=")
      __send__("#{name}=", value)
    end
  end

  def to_cli_args
    self.class.all_option_names.flat_map do |name|
      value = __send__(name)
      next nil unless value

      if value == true
        "--#{name}"
      else
        ["--#{name}", value.to_s]
      end
    end.compact
  end
end
