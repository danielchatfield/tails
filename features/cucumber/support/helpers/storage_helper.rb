# Helper class for manipulating VM storage *volumes*, i.e. it deals
# only with creation of images and keeps a name => volume path lookup
# table (plugging drives or getting info of plugged devices is done in
# the VM class). We'd like better coupling, but given the ridiculous
# disconnect between Libvirt::StoragePool and Libvirt::Domain (hint:
# they have nothing with each other to do whatsoever) it's what makes
# sense.

require 'libvirt'
require 'rexml/document'
require 'etc'

class VMStorage

  @@virt = nil

  def initialize(virt, xml_path)
    @@virt ||= virt
    @xml_path = xml_path
    pool_xml = REXML::Document.new(File.read("#{@xml_path}/storage_pool.xml"))
    pool_name = pool_xml.elements['pool/name'].text
    begin
      @pool = @@virt.lookup_storage_pool_by_name(pool_name)
    rescue Libvirt::RetrieveError
      # There's no pool with that name, so we don't have to clear it
    else
      VMStorage.clear_storage_pool(@pool)
    end
    @path = "#{$tmp_dir}/#{pool_name}"
    pool_xml.elements['pool/target/path'].text = @path
    @pool = @@virt.define_storage_pool_xml(pool_xml.to_s)
    @pool.build
    @pool.create
    @pool.refresh
  end

  def VMStorage.clear_storage_pool(pool)
    pool.create if !pool.active?
    pool.list_volumes.each do |vol_name|
      vol = pool.lookup_volume_by_name(vol_name)
      vol.delete
    end
    pool.destroy if pool.active?
    pool.undefine
  end

  def clear
    VMStorage.clear_storage_pool(self)
  end

  def create_new_usb_drive(name, size = 2)
    begin
      old_vol = @pool.lookup_volume_by_name(name)
    rescue Libvirt::RetrieveError
      # noop
    else
      old_vol.delete
    end
    uid = Etc::getpwnam("libvirt-qemu").uid
    gid = Etc::getgrnam("kvm").gid
    vol_xml = REXML::Document.new(File.read("#{@xml_path}/usb_volume.xml"))
    vol_xml.elements['volume/name'].text = name
    vol_xml.elements['volume/capacity'].text = size.to_s
    vol_xml.elements['volume/target/path'].text = "#{@pool}/#{name}"
    vol_xml.elements['volume/target/permissions/owner'].text = uid.to_s
    vol_xml.elements['volume/target/permissions/group'].text = gid.to_s
    vol = @pool.create_volume_xml(vol_xml.to_s)
    @pool.refresh
  end

  def clone_to_new_usb_drive(from, to)
    begin
      old_to_vol = @pool.lookup_volume_by_name(to)
    rescue Libvirt::RetrieveError
      # noop
    else
      old_to_vol.delete
    end
    from_vol = @pool.lookup_volume_by_name(from)
    xml = REXML::Document.new(from_vol.xml_desc)
    pool_path = REXML::Document.new(@pool.xml_desc).elements['pool/target/path'].text
    xml.elements['volume/name'].text = to
    xml.elements['volume/target/path'].text = "#{pool_path}/#{to}"
    @pool.create_volume_xml_from(xml.to_s, from_vol)
  end

  def usb_drive_path(name)
    @pool.lookup_volume_by_name(name).path
  end

end