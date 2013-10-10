# -*- coding: utf-8 -*-
# Tails: The Amnesic Incognito Live System
# Copyright © 2012 Tails developers <tails@boum.org>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

require 'digest'

# The following will monkeypatch Vagrant (successfuly tested against Vagrant
# 1.2.2) in order to verify the checksum of a downloaded box.
module VagrantPlugins
  module Kernel_V1
    class VMConfig < Vagrant.plugin("1", :config)
      attr_accessor :box_checksum
    end
  end
end

module VagrantPlugins
  module Kernel_V2
    class VMConfig < Vagrant.plugin("2", :config)
      attr_accessor :box_checksum
    end
  end
end

# This is a horrible hack compared to our previous monkeypatch since
# the downloader was made into an independent utility (that doesn't
# have access to the Vagrant environment, e.g. the checksum). The
# 'recover' method is absolutely not a nice place to put this code,
# but its our only option without having to reimplement huge parts of
# the BoxAdd class here.
module Vagrant
  module Action
    module Builtin
      class BoxAdd
        alias :unverified_download_recover :recover
        def recover(env)
          expected_checksum = env[:global_config].vm.box_checksum
          checksum = nil
          if @temp_path and File.exist?(@temp_path)
            checksum = Digest::SHA256.new.file(@temp_path).hexdigest
          end
          unverified_download_recover(env)
          if checksum and checksum != expected_checksum
            box = env[:global_config].vm.box
            provider = env[:box_provider]
            env[:box_collection].find(box, provider).destroy!
            FileUtils.remove_entry_secure("#{Dir.pwd}/vagrant/.vagrant")
            raise "The downloaded box has the incorrect checksum: " +
              "expected #{expected_checksum} but got #{checksum}."
          end
        end
      end
    end
  end
end
