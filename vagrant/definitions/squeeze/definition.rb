$:.unshift File.expand_path('../../../lib', __FILE__)
require 'tails_build_settings'

Veewee::Session.declare({
  :cpu_count => '1',
  :memory_size=> VM_MEMORY_FOR_DISK_BUILDS,
  :disk_size => '10000', :disk_format => 'VDI', :hostiocache => 'off',
  :os_type_id => 'Debian_64',
  :iso_file => "mini.iso",
  :iso_src => "http://ftp.nl.debian.org/debian/dists/squeeze/main/installer-amd64/20110106+squeeze4/images/netboot/mini.iso",
  :iso_md5 => "a439afbff15328d50103330c615c7dc4",
  :iso_download_timeout => "1000",
  :boot_wait => "10", :boot_cmd_sequence => [
    '<Esc>',
    'install ',
    'preseed/url=http://%IP%:%PORT%/preseed.cfg ',
    'debian-installer=en_US ',
    'auto ',
    'locale=en_US ',
    'kbd-chooser/method=us ',
    'netcfg/get_hostname=%NAME% ',
    'netcfg/get_domain=vagrantup.com ',
    'fb=false ',
    'debconf/frontend=noninteractive ',
    'console-setup/ask_detect=false ',
    'console-keymaps-at/keymap=us ',
    '<Enter>'
  ],
  :kickstart_port => "7122",
  :kickstart_timeout => "10000",
  :kickstart_file => "preseed.cfg",
  :ssh_login_timeout => "10000",
  :ssh_user => "vagrant",
  :ssh_password => "vagrant",
  :ssh_key => "",
  :ssh_host_port => "7222",
  :ssh_guest_port => "22",
  :sudo_cmd => "echo '%p'|sudo -S sh '%f'",
  :shutdown_cmd => "halt -p",
  :postinstall_files => [ "postinstall.sh" ],
  :postinstall_timeout => "10000"
})
