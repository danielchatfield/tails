@product
Feature: Installing Tails to a USB drive, upgrading it, and using persistence
  As a Tails user
  I may want to install Tails to a USB drive
  and upgrade it to new Tails versions
  and use persistence

  # An issue with this feature is that scenarios depend on each other.
  # For instance, "Tails boot from USB drive without persistent
  # partition" depends on "Install Tails to a USB drive". This feels
  # strange, but the alternative would be gigantic scenarios that
  # test what to me deels like logically different features, e.g.
  # the two named above would be concatenated.

  Scenario: Installing Tails to a pristine USB drive
    Given a computer
    And the computer is set to boot from the Tails DVD
    And the network is unplugged
    And I start the computer
    When the computer boots Tails
    And I log in to a new session
    And GNOME has started
    And I have closed all annoying notifications
    And I create a new 4 GiB USB drive named "A"
    And I plug USB drive "A"
    And I "Clone & Install" Tails to USB drive "A"
    Then Tails is installed on USB drive "A"
    But there is no persistence partition on USB drive "A"
    And I unplug USB drive "A"

  Scenario: Booting Tails from a USB drive without a persistent partition
    Given a computer
    And the computer is setup up to boot from USB drive "A"
    And the network is unplugged
    When I start the computer
    And the computer boots Tails
    And I log in to a new session
    Then Tails seems to have booted normally
    And Tails is running from USB drive "A"
    And the boot device has safe access rights
    And there is no persistence partition on USB drive "A"

  Scenario: Creating a persistent partition
    Given a computer
    And the computer is setup up to boot from USB drive "A"
    And the network is unplugged
    When I start the computer
    And the computer boots Tails
    And Tails is running from USB drive "A"
    And the boot device has safe access rights
    And I log in to a new session
    And GNOME has started
    And I have closed all annoying notifications
    And I create a persistent partition with password "asdf"
    Then a Tails persistence partition with password "asdf" exists on USB drive "A"
    And I shutdown Tails

  Scenario: Booting Tails from a USB drive with a disabled persistent partition
    Given a computer
    And the computer is setup up to boot from USB drive "A"
    And the network is unplugged
    When I start the computer
    And the computer boots Tails
    And I log in to a new session
    Then Tails seems to have booted normally
    And Tails is running from USB drive "A"
    And the boot device has safe access rights
    And persistence is not enabled
    But a Tails persistence partition with password "asdf" exists on USB drive "A"

  Scenario: Writing files to a read/write-enabled persistent partition
    Given a computer
    And the computer is setup up to boot from USB drive "A"
    And the network is unplugged
    When I start the computer
    And the computer boots Tails
    And Tails is running from USB drive "A"
    And the boot device has safe access rights
    And I enable persistence with password "asdf"
    And I log in to a new session
    And GNOME has started
    And I have closed all annoying notifications
    And persistence has been enabled
    And I write some files expected to persist
    And I shutdown Tails
    Then only the expected files should persist on USB drive "A"

  Scenario: Writing files to a read-only-enabled persistent partition
    Given a computer
    And the computer is setup up to boot from USB drive "A"
    And the network is unplugged
    When I start the computer
    And the computer boots Tails
    And Tails is running from USB drive "A"
    And the boot device has safe access rights
    And I enable read-only persistence with password "asdf"
    And I log in to a new session
    And GNOME has started
    And I have closed all annoying notifications
    And persistence has been enabled
    And I write some files not expected to persist
    And I remove some files expected to persist
    And I shutdown Tails
    Then only the expected files should persist on USB drive "A"

  Scenario: Upgrading a Tails USB drive from a Tails DVD
    Given a computer
    And the computer is set to boot from the Tails DVD
    And the network is unplugged
    When I start the computer
    And the computer boots Tails
    And I log in to a new session
    And GNOME has started
    And I have closed all annoying notifications
    And I plug USB drive "A"
    And I "Clone & Upgrade" Tails to USB drive "A"
    Then Tails is installed on USB drive "A"
    And I unplug USB drive "A"

  # If above scenario failed before it upgraded the Tails on USB drive A
  # this scenario will test the pre-upgrade Tails. While not completely
  # bad, we probably want USB drive A to contain an old version of Tails
  # (give OLD_ISO as env variable?) and then verify that an up-to-date
  # version is booted in this step.
  Scenario: Booting Tails from a USB drive upgraded from DVD with persistence enabled
    Given a computer
    And the computer is setup up to boot from USB drive "A"
    And the network is unplugged
    When I start the computer
    And the computer boots Tails
    And I enable read-only persistence with password "asdf"
    And I log in to a new session
    Then Tails seems to have booted normally
    And Tails is running from USB drive "A"
    And the boot device has safe access rights
    And the expected persistent files are present in the filesystem

  Scenario: Upgrading a Tails USB drive from another Tails USB drive
    Given a computer
    And I clone USB drive "A" to a new USB drive "B"
    And the computer is setup up to boot from USB drive "A"
    And the network is unplugged
    When I start the computer
    And the computer boots Tails
    And Tails is running from USB drive "A"
    And the boot device has safe access rights
    And I log in to a new session
    And GNOME has started
    And I have closed all annoying notifications
    And I plug USB drive "B"
    And I "Clone & Upgrade" Tails to USB drive "B"
    Then Tails is installed on USB drive "B"
    And I unplug USB drive "B"
    And I unplug USB drive "A"

  # Same issue as with scenario "Boot from USB drive upgraded from DVD"
  Scenario: Booting Tails from a USB drive upgraded from USB with persistence enabled
    Given a computer
    And the computer is setup up to boot from USB drive "B"
    And the network is unplugged
    When I start the computer
    And the computer boots Tails
    And I enable read-only persistence with password "asdf"
    And I log in to a new session
    Then Tails seems to have booted normally
    And persistence has been enabled
    And Tails is running from USB drive "B"
    And the boot device has safe access rights
    And the expected persistent files are present in the filesystem

  Scenario: Upgrading a Tails USB drive from an ISO image
    Given a computer
    And the computer is set to boot from the Tails DVD
    And the network is unplugged
    And I setup a filesystem share containing the Tails ISO
    When I start the computer
    And the computer boots Tails
    And I log in to a new session
    And GNOME has started
    And I have closed all annoying notifications
    And I plug USB drive "A"
    And I do a "Upgrade from ISO" on USB drive "A"
    Then Tails is installed on USB drive "A"
    And I unplug USB drive "A"

  # Same issue as with scenario "Boot from USB drive upgraded from DVD"
  Scenario: Booting Tails from a USB drive upgraded from ISO with persistence enabled
    Given a computer
    And the computer is setup up to boot from USB drive "A"
    And the network is unplugged
    When I start the computer
    And the computer boots Tails
    And I enable read-only persistence with password "asdf"
    And I log in to a new session
    Then Tails seems to have booted normally
    And persistence has been enabled
    And Tails is running from USB drive "A"
    And the boot device has safe access rights
    And the expected persistent files are present in the filesystem

  Scenario: Deleting a Tails persistent partition
    Given a computer
    And the computer is setup up to boot from USB drive "A"
    And the network is unplugged
    And I start the computer
    And the computer boots Tails
    And I log in to a new session
    And Tails is running from USB drive "A"
    And the boot device has safe access rights
    And Tails seems to have booted normally
    And persistence is not enabled
    But a Tails persistence partition with password "asdf" exists on USB drive "A"
    And I have closed all annoying notifications
    When I delete the persistent partition
    Then there is no persistence partition on USB drive "A"
