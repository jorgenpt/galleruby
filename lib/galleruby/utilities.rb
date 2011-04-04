require 'date'

class Time
  def to_datetime
    # Convert seconds + microseconds into a fractional number of seconds
    seconds = sec + Rational(usec, 10**6)

    # Convert a UTC offset measured in minutes to one measured in a
    # fraction of a day.
    offset = Rational(utc_offset, 60 * 60 * 24)
    DateTime.new(year, month, day, hour, min, seconds, offset)
  end
end

# Class to easily instantiate an object when needed.
# Similar to using (object ||= Foo.new).bar, but stores the initialization code to make
# the code cleaner.
class LazyObject
    @object = nil
    def initialize(&code)
        @init = code
    end

    def was_initialized?
        not @object.nil?
    end

    def method_missing(m, *args, &block)
        if not was_initialized? then
            @object = @init.call
            @object.public_methods(false).each do |meth|
                (class << self; self; end).class_eval do
                    define_method meth do |*args|
                        @object.send meth, *args
                    end
                end
            end
            @object.send m, *args, &block
        else
            super.method_missing m, *args, &block
        end
    end
end

