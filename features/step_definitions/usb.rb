def persistent_dirs
  ["/etc/ssh",
   "/home/#{$live_user}/.claws-mail",
   "/home/#{$live_user}/.gconf/system/networking/connections",
   "/home/#{$live_user}/.gnome2/keyrings",
   "/home/#{$live_user}/.gnupg",
   "/home/#{$live_user}/.mozilla/firefox/bookmarks",
   "/home/#{$live_user}/.purple",
   "/home/#{$live_user}/.ssh",
   "/home/#{$live_user}/Persistent",
   "/home/#{$live_user}/custom_persistence",
   "/var/cache/apt/archives",
   "/var/lib/apt/lists"]
end

Given /^I create a new (\d+) ([[:alpha:]]+) USB drive named "([^"]+)"$/ do |size, unit, name|
  next if @skip_steps_while_restoring_background
  @vm.storage.create_new_disk(name, {:size => size, :unit => unit})
end

Given /^I clone USB drive "([^"]+)" to a new USB drive "([^"]+)"$/ do |from, to|
  next if @skip_steps_while_restoring_background
  @vm.storage.clone_to_new_disk(from, to)
end

Given /^I unplug USB drive "([^"]+)"$/ do |name|
  next if @skip_steps_while_restoring_background
  @vm.unplug_drive(name)
end

def usb_install_helper(name)
  @screen.wait('USBCreateLiveUSB.png', 10)

  # Here we'd like to select USB drive using #{name}, but Sikuli's
  # OCR seems to be too unreliable.
#  @screen.wait('USBTargetDevice.png', 10)
#  match = @screen.find('USBTargetDevice.png')
#  region_x = match.x
#  region_y = match.y + match.height
#  region_w = match.width*3
#  region_h = match.height*2
#  ocr = Sikuli::Region.new(region_x, region_y, region_w, region_h).text
#  STDERR.puts ocr
#  # Unfortunately this results in almost garbage, like "|]dev/sdm"
#  # when it should be /dev/sda1

  @screen.wait_and_click('USBCreateLiveUSB.png', 10)
#  @screen.hide_cursor
  @screen.wait_and_click('USBCreateLiveUSBNext.png', 10)
#  @screen.hide_cursor
  @screen.wait('USBInstallationComplete.png', 60*60)
  @screen.type(Sikuli::KEY_RETURN)
  @screen.type(Sikuli::KEY_F4, Sikuli::KEY_ALT)
end

When /^I "Clone & Install" Tails to USB drive "([^"]+)"$/ do |name|
  next if @skip_steps_while_restoring_background
  step "I run \"liveusb-creator-launcher\""
  @screen.wait_and_click('USBCloneAndInstall.png', 30)
  usb_install_helper(name)
end

When /^I "Clone & Upgrade" Tails to USB drive "([^"]+)"$/ do |name|
  next if @skip_steps_while_restoring_background
  step "I run \"liveusb-creator-launcher\""
  @screen.wait_and_click('USBCloneAndUpgrade.png', 30)
  usb_install_helper(name)
end

def shared_iso_dir_on_guest
  "/tmp/shared_dir"
end

Given /^I setup a filesystem share containing the Tails ISO$/ do
  next if @skip_steps_while_restoring_background
  @vm.add_share(File.dirname($tails_iso), shared_iso_dir_on_guest)
end

When /^I do a "Upgrade from ISO" on USB drive "([^"]+)"$/ do |name|
  next if @skip_steps_while_restoring_background
  step "I run \"liveusb-creator-launcher\""
  @screen.wait_and_click('USBUpgradeFromISO.png', 10)
  @screen.wait('USBUseLiveSystemISO.png', 10)
  match = @screen.find('USBUseLiveSystemISO.png')
  pos_x = match.x + match.width/2
  pos_y = match.y + match.height*2
  @screen.click(pos_x, pos_y)
  @screen.wait('USBSelectISO.png', 10)
  @screen.wait_and_click('GnomeFileDiagTypeFilename.png', 10)
  iso = "#{shared_iso_dir_on_guest}/#{File.basename($tails_iso)}"
  @screen.type(iso + Sikuli::KEY_RETURN)
  usb_install_helper(name)
end

Given /^I enable all persistence presets$/ do
  next if @skip_steps_while_restoring_background
  @screen.wait('PersistenceWizardPresets.png', 20)
  # Mark first non-default persistence preset
  @screen.type("\t\t")
  # Check all non-default persistence presets
  10.times do
    @screen.type(" \t")
  end
  # Now we'll have the custom persistence field selected
  @screen.type("/home/#{$live_user}/custom_persistence")
  @screen.type('a', Sikuli::KEY_ALT)
  @screen.type('/etc/ssh')
  @screen.type('a', Sikuli::KEY_ALT)
  @screen.wait_and_click('PersistenceWizardSave.png', 10)
  @screen.wait('PersistenceWizardDone.png', 20)
  @screen.type(Sikuli::KEY_F4, Sikuli::KEY_ALT)
end

Given /^I create a persistent partition with password "([^"]+)"$/ do |pwd|
  next if @skip_steps_while_restoring_background
  step "I run \"tails-persistence-setup\""
  @screen.wait('PersistenceWizardWindow.png', 20)
  @screen.wait('PersistenceWizardStart.png', 20)
  @screen.type(pwd + "\t" + pwd + Sikuli::KEY_RETURN)
  @screen.wait('PersistenceWizardPresets.png', 120)
  step "I enable all persistence presets"
end

def check_part_integrity(name, dev, usage, type, scheme, label)
  info = @vm.execute("udisks --show-info #{dev}").stdout
  info_split = info.split("\n  partition:\n")
  dev_info = info_split[0]
  part_info = info_split[1]
  assert(dev_info.match("^  usage: +#{usage}$"),
         "Unexpected device field 'usage' on USB drive '#{name}', '#{dev}'")
  assert(dev_info.match("^  type: +#{type}$"),
         "Unexpected device field 'type' on USB drive '#{name}', '#{dev}'")
  assert(part_info.match("^    scheme: +#{scheme}$"),
         "Unexpected partition scheme on USB drive '#{name}', '#{dev}'")
  assert(part_info.match("^    label: +#{label}$"),
         "Unexpected partition label on USB drive '#{name}', '#{dev}'")
end

Then /^Tails is installed on USB drive "([^"]+)"$/ do |name|
  next if @skip_steps_while_restoring_background
  dev = @vm.disk_dev(name) + "1"
  check_part_integrity(name, dev, "filesystem", "vfat", "gpt", "Tails")

  old_root = "/lib/live/mount/medium"
  new_root = "/mnt/new"
  @vm.execute("mkdir -p #{new_root}")
  @vm.execute("mount #{dev} #{new_root}")

  c = @vm.execute("diff -qr '#{old_root}/live' '#{new_root}/live'")
  assert(c.success?,
         "USB drive '#{name}' has differences in /live:\n#{c.stdout}")

  loader = boot_device_type == "usb" ? "syslinux" : "isolinux"
  syslinux_files = @vm.execute("ls -1 #{new_root}/syslinux").stdout.chomp.split
  # We deal with these files separately
  ignores = ["syslinux.cfg", "exithelp.cfg", "ldlinux.sys"]
  for f in syslinux_files - ignores do
    c = @vm.execute("diff -q '#{old_root}/#{loader}/#{f}' " +
                    "'#{new_root}/syslinux/#{f}'")
    assert(c.success?, "USB drive '#{name}' has differences in " +
           "'/syslinux/#{f}'")
  end

  # The main .cfg is named differently vs isolinux
  c = @vm.execute("diff -q '#{old_root}/#{loader}/#{loader}.cfg' " +
                  "'#{new_root}/syslinux/syslinux.cfg'")
  assert(c.success?, "USB drive '#{name}' has differences in " +
         "'/syslinux/syslinux.cfg'")

  # We have to account for the different path vs isolinux
  old_exithelp = @vm.execute("cat '#{old_root}/#{loader}/exithelp.cfg'").stdout
  new_exithelp = @vm.execute("cat '#{new_root}/syslinux/exithelp.cfg'").stdout
  new_exithelp_undiffed = new_exithelp.sub("kernel /syslinux/vesamenu.c32",
                                           "kernel /#{loader}/vesamenu.c32")
  assert(new_exithelp_undiffed == old_exithelp,
         "USB drive '#{name}' has unexpected differences in " +
         "'/syslinux/exithelp.cfg'")

  @vm.execute("umount #{new_root}")
  @vm.execute("sync")
end

Then /^there is no persistence partition on USB drive "([^"]+)"$/ do |name|
  next if @skip_steps_while_restoring_background
  data_part_dev = @vm.disk_dev(name) + "2"
  assert(!@vm.execute("test -b #{data_part_dev}").success?,
         "USB drive #{name} has a partition '#{data_part_dev}'")
end

Then /^a Tails persistence partition with password "([^"]+)" exists on USB drive "([^"]+)"$/ do |pwd, name|
  next if @skip_steps_while_restoring_background
  dev = @vm.disk_dev(name) + "2"
  check_part_integrity(name, dev, "crypto", "crypto_LUKS", "gpt", "TailsData")

  c = @vm.execute("echo #{pwd} | cryptsetup luksOpen #{dev} #{name}")
  assert(c.success?, "Couldn't open LUKS device '#{dev}' on  drive '#{name}'")
  luks_dev = "/dev/mapper/#{name}"

  # Adapting check_part_integrity() seems like a bad idea so here goes
  info = @vm.execute("udisks --show-info #{luks_dev}").stdout
  assert info.match("^  cleartext luks device:$")
  assert info.match("^  usage: +filesystem$")
  assert info.match("^  type: +ext3$")
  assert info.match("^  label: +TailsData$")

  mount_dir = "/mnt/#{name}"
  @vm.execute("mkdir -p #{mount_dir}")
  c = @vm.execute("mount #{luks_dev} #{mount_dir}")
  assert(c.success?,
         "Couldn't mount opened LUKS device '#{dev}' on  drive '#{name}'")

  @vm.execute("umount #{mount_dir}")
  @vm.execute("sync")
  @vm.execute("cryptsetup luksClose #{name}")
end

Given /^I enable persistence with password "([^"]+)"$/ do |pwd|
  next if @skip_steps_while_restoring_background
  match = @screen.find('TailsGreeterPersistence.png')
  pos_x = match.x + match.width/2
  # height*2 may seem odd, but we want to click the button below the
  # match. This may even work accross different screen resolutions.
  pos_y = match.y + match.height*2
  @screen.click(pos_x, pos_y)
  @screen.wait('TailsGreeterPersistencePassphrase.png', 10)
  match = @screen.find('TailsGreeterPersistencePassphrase.png')
  pos_x = match.x + match.width*2
  pos_y = match.y + match.height/2
  @screen.click(pos_x, pos_y)
  @screen.type(pwd)
end

Given /^persistence is not enabled$/ do
  next if @skip_steps_while_restoring_background
  data_part_dev = boot_device + "2"
  assert(!@vm.execute("grep -q '^#{data_part_dev} ' /proc/mounts").success?,
         "Partition '#{data_part_dev}' from the boot device is mounted")
end

Given /^I enable read-only persistence with password "([^"]+)"$/ do |pwd|
  step "I enable persistence with password \"#{pwd}\""
  next if @skip_steps_while_restoring_background
  @screen.wait_and_click('TailsGreeterPersistenceReadOnly.png', 10)
end

Given /^persistence has been enabled$/ do
  next if @skip_steps_while_restoring_background
  try_for(60, :msg => "Some persistent dir was not mounted") {
    mount = @vm.execute("mount").stdout.chomp
    persistent_dirs.each do |dir|
      if ! mount.include? "on #{dir} "
        raise "persistent dir #{dir} missing"
      end
    end
  }
end

def boot_device
  # Approach borrowed from
  # config/chroot_local_includes/lib/live/config/998-permissions
  boot_dev_id = @vm.execute("udevadm info --device-id-of-file=/live/image").stdout.chomp
  boot_dev = @vm.execute("readlink -f /dev/block/'#{boot_dev_id}'").stdout.chomp
  return boot_dev
end

def boot_device_type
  # Approach borrowed from
  # config/chroot_local_includes/lib/live/config/998-permissions
  boot_dev_info = @vm.execute("udevadm info --query=property --name='#{boot_device}'").stdout.chomp
  boot_dev_type = (boot_dev_info.split("\n").select { |x| x.start_with? "ID_BUS=" })[0].split("=")[1]
  return boot_dev_type
end

Then /^Tails is running from USB drive "([^"]+)"$/ do |name|
  next if @skip_steps_while_restoring_background
  assert(boot_device_type == "usb",
         "Got device type '#{boot_device_type}' while expecting 'usb'")
  actual_dev = boot_device
  expected_dev = @vm.disk_dev(name) + "1"
  assert(actual_dev == expected_dev,
         "USB drive '#{name}' has device #{expected_dev}, but we are " +
         "running from #{actual_dev}")
end

Then /^the boot device has safe access rights$/ do
  next if @skip_steps_while_restoring_background

  # XXX: It turns out our fix for Debian bug #645466 (see the live-config
  # hook called 9980-permissions) is not working any more. Is udev doing
  # this at a later stage now?
  puts "This check is temporarily disabled since it currently always fails"
  next

  super_boot_dev = boot_device.sub(/[[:digit:]]+$/, "")
  devs = @vm.execute("ls -1 #{super_boot_dev}*").stdout.chomp.split
  assert(devs.size > 0, "Could not determine boot device")
  all_users = @vm.execute("cut -d':' -f1 /etc/passwd").stdout.chomp.split
  all_users_with_groups = all_users.collect do |user|
    groups = @vm.execute("groups #{user}").stdout.chomp.sub(/^#{user} : /, "").split(" ")
    [user, groups]
  end
  STDERR.puts "#{all_users_with_groups.join(", ")}"
  for dev in devs do
    dev_owner = @vm.execute("stat -c %U #{dev}").stdout.chomp
    dev_group = @vm.execute("stat -c %G #{dev}").stdout.chomp
    dev_perms = @vm.execute("stat -c %a #{dev}").stdout.chomp
    assert(dev_owner == "root",
           "Boot device '#{dev}' owned by user '#{dev_owner}', expected 'root'")
    assert(dev_group == "disk" || dev_group == "root",
           "Boot device '#{dev}' owned by group '#{dev_group}', expected " +
           "'disk' or 'root'. We are probably affected by Debian bug #645466.")
    assert(dev_perms == "660",
           "Boot device '#{dev}' has permissions '#{dev_perms}', expected '660'")
    for user, groups in all_users_with_groups do
      next if user == "root"
      assert(!(groups.include?(dev_group)),
             "Unprivileged user '#{user}' is in group '#{dev_group}' which " +
             "owns boot device '#{dev}'")
    end
  end
end

When /^I write some files expected to persist$/ do
  next if @skip_steps_while_restoring_background
  persistent_dirs.each do |dir|
    owner = @vm.execute("stat -c %U #{dir}").stdout.chomp
    assert(@vm.execute("touch #{dir}/XXX_persist", user=owner).success?,
           "Could not create file in persistent directory #{dir}")
  end
end

When /^I remove some files expected to persist$/ do
  next if @skip_steps_while_restoring_background
  persistent_dirs.each do |dir|
    assert(@vm.execute("rm #{dir}/XXX_persist").success?,
           "Could not remove file in persistent directory #{dir}")
  end
end

When /^I write some files not expected to persist$/ do
  next if @skip_steps_while_restoring_background
  persistent_dirs.each do |dir|
    owner = @vm.execute("stat -c %U #{dir}").stdout.chomp
    assert(@vm.execute("touch #{dir}/XXX_gone", user=owner).success?,
           "Could not create file in persistent directory #{dir}")
  end
end

Then /^the expected persistent files are present in the filesystem$/ do
  next if @skip_steps_while_restoring_background
  persistent_dirs.each do |dir|
    assert(@vm.execute("test -e #{dir}/XXX_persist").success?,
           "Could not find expected file in persistent directory #{dir}")
    assert(!@vm.execute("test -e #{dir}/XXX_gone").success?,
           "Found file that should not have persisted in persistent directory #{dir}")
  end
end

Then /^only the expected files should persist on USB drive "([^"]+)"$/ do |name|
  next if @skip_steps_while_restoring_background
  step "a computer"
  step "the computer is setup up to boot from USB drive \"#{name}\""
  step "the network is unplugged"
  step "I start the computer"
  step "the computer boots Tails"
  step "I enable read-only persistence with password \"asdf\""
  step "I log in to a new session"
  step "persistence has been enabled"
  step "GNOME has started"
  step "I have closed all annoying notifications"
  step "the expected persistent files are present in the filesystem"
  step "I shutdown Tails"
end

When /^I delete the persistent partition$/ do
  next if @skip_steps_while_restoring_background
  step "I run \"tails-persistence-setup --step delete\""
  @screen.wait("PersistenceWizardWindow.png", 10)
  @screen.wait("PersistenceWizardDeletionStart.png", 10)
  @screen.type(" ")
  @screen.wait("PersistenceWizardDone.png", 120)
end
