RubyNative.configure do |config|
    config.current_user_resolver = -> { Current.user }
end