require 'uri'

Given /^the only hosts in APT sources are "([^"]*)"$/ do |hosts_str|
  next if @skip_steps_while_restoring_background
  hosts = hosts_str.split(',')
  @vm.execute("cat /etc/apt/sources.list /etc/apt/sources.list.d/*").stdout.chomp.each_line { |line|
    next if ! line.start_with? "deb"
    source_host = URI(line.split[1]).host
    if !hosts.include?(source_host)
      raise "Bad APT source '#{line}'"
    end
  }
end

When /^I update APT using apt-get$/ do
  SystemTimer.timeout(30*60) do
    cmd = @vm.execute("echo #{@sudo_password} | " +
                      "sudo -S apt-get update", $live_user)
    if !cmd.success?
      STDERR.puts cmd.stderr
    end
  end
end

Then /^I should be able to install a package using apt-get$/ do
  package = "cowsay"
  SystemTimer.timeout(120) do
    cmd = @vm.execute("echo #{@sudo_password} | " +
                      "sudo -S apt-get install #{package}", $live_user)
    if !cmd.success?
      STDERR.puts cmd.stderr
    end
  end
  step "package \"#{package}\" is installed"
end

When /^I update APT using Synaptic$/ do
  # Upon start the interface will be frozen while Synaptic loads the
  # package list. Since the frozen GUI is so similar to the unfrozen
  # one there's no easy way to reliably wait for the latter. Hence we
  # spam reload until it's performed, which is easier to detect.
  try_for(20, :msg => "Failed to reload the package list in Synaptic") {
    @screen.type("r", Sikuli::KEY_CTRL)
    @screen.find('SynapticReloadPrompt.png')
  }
  @screen.waitVanish('SynapticReloadPrompt.png', 30*60)
end

Then /^I should be able to install a package using Synaptic$/ do
  package = "cowsay"
  # We do this after a Reload, so the interface will be frozen until
  # the package list has been loaded
  try_for(20, :msg => "Failed to open the Synaptic 'Find' window") {
    @screen.type("f", Sikuli::KEY_CTRL)  # Find key
    @screen.find('SynapticSearch.png')
  }
  @screen.type(package + Sikuli::KEY_RETURN)
  @screen.wait_and_click('SynapticCowsaySearchResult.png', 20)
  sleep 1
  @screen.type("i", Sikuli::KEY_CTRL)    # Mark for installation
  sleep 1
  @screen.type("p", Sikuli::KEY_CTRL)    # Apply
  @screen.wait('SynapticApplyPrompt.png', 20)
  @screen.type("a", Sikuli::KEY_ALT)     # Verify apply
  @screen.wait('SynapticChangesAppliedPrompt.png', 120)
  step "package \"#{package}\" is installed"
end
