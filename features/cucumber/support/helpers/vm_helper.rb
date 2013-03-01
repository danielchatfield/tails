require 'libvirt'
require 'rexml/document'

class VM

  # These class attributes will be lazily initialized during the first
  # instantiation:
  # This is the libvirt connection, of which we only want one and
  # which can persist for different VM instances (even in parallel)
  @@virt = nil
  # This is a storage helper that deals with volume manipulation. The
  # storage it deals with persist across VMs, by necessity.
  @@storage = nil

  def storage
    return @@storage
  end

  attr_reader :domain, :display, :ip, :ip6, :net

  def initialize(xml_path, x_display)
    @@virt ||= Libvirt::open("qemu:///system")
    @xml_path = xml_path
    default_domain_xml = File.read("#{@xml_path}/default.xml")
    update_domain(default_domain_xml)
    default_net_xml = File.read("#{@xml_path}/default_net.xml")
    update_net(default_net_xml)
    @display = Display.new(@domain_name, x_display)
    set_cdrom_boot($tails_iso)
    plug_network
    # unlike the domain and net the storage pool should survive VM
    # teardown (so a new instance can use e.g. a previously created
    # USB drive), so we only create a new one if there is none.
    @@storage ||= VMStorage.new(@@virt, xml_path)
  end

  def update_domain(xml)
    domain_xml = REXML::Document.new(xml)
    @domain_name = domain_xml.elements['domain/name'].text
    clean_up_domain
    @domain = @@virt.define_domain_xml(xml)
  end

  def update_net(xml)
    net_xml = REXML::Document.new(xml)
    @net_name = net_xml.elements['network/name'].text
    @ip = net_xml.elements['network/ip/dhcp/host/'].attributes['ip']
    net_xml.elements.each('network/ip') do |e|
      if e.attribute('family').to_s == "ipv6"
        @ip6 = e.attribute('address').to_s
      end
    end
    clean_up_net
    @net = @@virt.define_network_xml(xml)
    @net.create
  end

  def clean_up_domain
    begin
      domain = @@virt.lookup_domain_by_name(@domain_name)
      domain.destroy if domain.active?
      domain.undefine
    rescue
    end
  end

  def clean_up_net
    begin
      net = @@virt.lookup_network_by_name(@net_name)
      net.destroy if net.active?
      net.undefine
    rescue
    end
  end

  def set_network_link_state(state)
    domain_xml = REXML::Document.new(@domain.xml_desc)
    domain_xml.elements['domain/devices/interface/link'].attributes['state'] = state
    if is_running?
      @domain.update_device(domain_xml.elements['domain/devices/interface'].to_s)
    else
      update_domain(domain_xml.to_s)
    end
  end

  def plug_network
    set_network_link_state('up')
  end

  def unplug_network
    set_network_link_state('down')
  end

  def set_cdrom_tray_state(state)
    domain_xml = REXML::Document.new(@domain.xml_desc)
    domain_xml.elements.each('domain/devices/disk') do |e|
      if e.attribute('device').to_s == "cdrom"
        e.elements['target'].attributes['tray'] = state
        if is_running?
          @domain.update_device(e.to_s)
        else
          update_domain(domain_xml.to_s)
        end
      end
    end
  end

  def eject_cdrom
    set_cdrom_tray_state('open')
  end

  def close_cdrom
    set_cdrom_tray_state('closed')
  end

  def set_boot_device(dev)
    if is_running?
      raise "boot settings can only be set for inactive vms"
    end
    domain_xml = REXML::Document.new(@domain.xml_desc)
    domain_xml.elements['domain/os/boot'].attributes['dev'] = dev
    update_domain(domain_xml.to_s)
  end

  def set_cdrom_image(image)
    if is_running?
      raise "boot settings can only be set for inactice vms"
    end
    domain_xml = REXML::Document.new(@domain.xml_desc)
    domain_xml.elements.each('domain/devices/disk') do |e|
      if e.attribute('device').to_s == "cdrom"
        if ! e.elements['source']
          e.add_element('source')
        end
        e.elements['source'].attributes['file'] = image
        if is_running?
          @domain.update_device(e.to_s)
        else
          update_domain(domain_xml.to_s)
        end
      end
    end
  end

  def remove_cdrom
    set_cdrom_image('')
  end

  def set_cdrom_boot(image)
    set_boot_device('cdrom')
    set_cdrom_image(image)
    close_cdrom
  end

  def plug_usb_drive(name)
    # Get the next free /dev/sdX on guest
    used_devs = []
    domain_xml = REXML::Document.new(@domain.xml_desc)
    domain_xml.elements.each('domain/devices/disk/target') do |e|
      used_devs <<= e.attribute('dev').to_s
    end
    letter = 'a'
    dev = "sd" + letter
    while used_devs.include? dev
      letter = (letter[0].ord + 1).chr
      dev = "sd" + letter
    end
    assert letter <= 'z'

    xml = REXML::Document.new(File.read("#{@xml_path}/usb_disk.xml"))
    xml.elements['disk/source'].attributes['file'] = @@storage.usb_drive_path(name)
    xml.elements['disk/target'].attributes['dev'] = dev
    @domain.attach_device(xml.to_s)
  end

  def usb_drive_xml_desc(name)
    domain_xml = REXML::Document.new(@domain.xml_desc)
    domain_xml.elements.each('domain/devices/disk') do |e|
      begin
        if e.elements['source'].attribute('file').to_s == @@storage.usb_drive_path(name)
          return e.to_s
        end
      rescue
        next
      end
    end
    return nil
  end

  def unplug_usb_drive(name)
    xml = usb_drive_xml_desc(name)
    @domain.detach_device(xml)
  end

  def usb_drive_dev(name)
    xml = REXML::Document.new(usb_drive_xml_desc(name))
    return "/dev/" + xml.elements['disk/target'].attribute('dev').to_s
  end

  def set_usb_boot(name)
    if is_running?
      raise "boot settings can only be set for inactive vms"
    end
    # Unfortunately libvirt doesn't allow setting the removable property,
    # which Tails requires of its boot/persistence media. We work around
    # this by appending the device via raw QEMU command line options.
    image = @@storage.usb_drive_path(name)
    xml = <<EOF
  <qemu:commandline xmlns:qemu='http://libvirt.org/schemas/domain/qemu/1.0'>
    <qemu:arg value='-drive'/>
    <qemu:arg value='file=#{image},if=none,id=drive-usb-boot-disk,format=qcow2'/>
    <qemu:arg value='-device'/>
    <qemu:arg value='usb-storage,drive=drive-usb-boot-disk,id=usb-boot-disk,removable=on'/>
  </qemu:commandline>
EOF
    # Of course libvirt won't set the ownership of the disk image
    # correctly when using raw qemu cmdline passthrough, so we also plug
    # the stick via libvirt's normal channels (attach_device() in this
    # case) to deal with ownership. Note that we have to make sure that
    # the drive/disk ids are different to avoid collisions. libvirt
    # sets them to 'drive-usb-diskX' and 'usb-diskX' respectively, so
    # that's why we set them to something different ('drive-usb-boot-disk'
    # and 'usb-boot-disk') in the XML above.
    plug_usb_drive(name)

    domain_xml = REXML::Document.new(@domain.xml_desc)
    domain_xml.elements['domain'].add_element(REXML::Document.new(xml))
    update_domain(domain_xml.to_s)
    set_boot_device('hd')
    # FIXME: For some reason setting the boot device doesn't prevent
    # cdrom boot unless it's empty
    remove_cdrom
  end

  def add_share(source, tag)
    if is_running?
      raise "shares can only be added to inactice vms"
    end
    xml = REXML::Document.new(File.read("#{@xml_path}/fs_share.xml"))
    xml.elements['filesystem/source'].attributes['dir'] = source
    xml.elements['filesystem/target'].attributes['dir'] = tag
    domain_xml = REXML::Document.new(@domain.xml_desc)
    domain_xml.elements['domain/devices'].add_element(xml)
    update_domain(domain_xml.to_s)
  end

  def list_shares
    list = []
    domain_xml = REXML::Document.new(@domain.xml_desc)
    domain_xml.elements.each('domain/devices/filesystem') do |e|
      list << e.elements['target'].attribute('dir').to_s
    end
    return list
  end

  def set_ram_size(size, unit = "KiB")
    raise "System memory can only be added to inactice vms" if is_running?
    domain_xml = REXML::Document.new(@domain.xml_desc)
    domain_xml.elements['domain/memory'].text = size
    domain_xml.elements['domain/memory'].attributes['unit'] = unit
    domain_xml.elements['domain/currentMemory'].text = size
    domain_xml.elements['domain/currentMemory'].attributes['unit'] = unit
    update_domain(domain_xml.to_s)
  end

  def get_ram_size_in_bytes
    domain_xml = REXML::Document.new(@domain.xml_desc)
    unit = domain_xml.elements['domain/memory'].attribute('unit').to_s
    size = domain_xml.elements['domain/memory'].text.to_i
    return convert_to_bytes(size, unit)
  end

  def set_arch(arch)
    raise "System architecture can only be set to inactice vms" if is_running?
    domain_xml = REXML::Document.new(@domain.xml_desc)
    domain_xml.elements['domain/os/type'].attributes['arch'] = arch
    update_domain(domain_xml.to_s)
  end

  def add_hypervisor_feature(feature)
    raise "Hypervisor features can only be added to inactice vms" if is_running?
    domain_xml = REXML::Document.new(@domain.xml_desc)
    domain_xml.elements['domain/features'].add_element(feature)
    update_domain(domain_xml.to_s)
  end

  def drop_hypervisor_feature(feature)
    raise "Hypervisor features can only be fropped from inactice vms" if is_running?
    domain_xml = REXML::Document.new(@domain.xml_desc)
    domain_xml.elements['domain/features'].delete_element(feature)
    update_domain(domain_xml.to_s)
  end

  def disable_pae_workaround
    # add_hypervisor_feature("nonpae") results in a libvirt error, and
    # drop_hypervisor_feature("pae") alone won't disable pae. Hence we
    # use this workaround.
    xml = <<EOF
  <qemu:commandline xmlns:qemu='http://libvirt.org/schemas/domain/qemu/1.0'>
    <qemu:arg value='-cpu'/>
    <qemu:arg value='pentium,-pae'/>
  </qemu:commandline>
EOF
    domain_xml = REXML::Document.new(@domain.xml_desc)
    domain_xml.elements['domain'].add_element(REXML::Document.new(xml))
    update_domain(domain_xml.to_s)
  end

  def is_running?
    begin
      return @domain.active?
    rescue
      return false
    end
  end

  def execute(cmd, user = "root")
    return VMCommand.new(self, cmd, { :user => user, :spawn => false })
  end

  def spawn(cmd, user = "root")
    return VMCommand.new(self, cmd, { :user => user, :spawn => true })
  end

  def wait_until_remote_shell_is_up(timeout = 30)
    VMCommand.wait_until_remote_shell_is_up(self, timeout)
  end

  def host_to_guest_time_sync
    host_time= DateTime.now.strftime("%s").to_s
    execute("date -s '@#{host_time}'").success?
  end

  def has_network?
    return execute("/sbin/ifconfig eth0 | grep -q 'inet addr'").success?
  end

  def has_process?(process)
    return execute("pidof " + process).success?
  end

  def save_snapshot(path)
    @domain.save(path)
    @display.stop
  end

  def restore_snapshot(path)
    # Clean up current domain so its snapshot can be restored
    clean_up_domain
    Libvirt::Domain::restore(@@virt, path)
    @domain = @@virt.lookup_domain_by_name(@domain_name)
    @display.start
  end

  def start
    return if is_running?
    @domain.create
    @display.start
  end

  def power_off
    @domain.destroy if is_running?
    @display.stop
  end

  def destroy
    clean_up_domain
    clean_up_net
    power_off
  end

  def take_screenshot(description)
    @display.take_screenshot(description)
  end

  def get_remote_shell_port
    domain_xml = REXML::Document.new(@domain.xml_desc)
    domain_xml.elements.each('domain/devices/serial') do |e|
      if e.attribute('type').to_s == "tcp"
        return e.elements['source'].attribute('service').to_s.to_i
      end
    end
  end

end