require "test_helper"
require "yaml"

class RubyNativeTabsTest < ActiveSupport::TestCase
  test "tab bar has Home, Calendário, Categorias and Profile, and no Settings" do
    config = YAML.load_file(Rails.root.join("config/ruby_native.yml"))
    titles = config["tabs"].map { |tab| tab["title"] }

    assert_equal ["Home", "Calendário", "Categorias", "Profile"], titles
  end
end
