#!/usr/bin/python

# Root test dir
TESTDIR = "./testroot/"
UPTO = TESTDIR

import imp
import os
import os.path
import unittest

tailsadditionalsoftware = imp.load_source("tailsadditionalsoftware",
    "config/chroot_local-includes/usr/local/sbin/tails-additional-software")

def touch(path, mode):
    print mode
    f = open(path, 'w')
    f.closed
    os.chmod(path, mode)

class PackageslistPermissionsTest(unittest.TestCase):

    def setUp(self):
        if not os.getuid() == 0:
            raise Exception("This test must be run as root")

        if os.path.exists(TESTDIR):
            raise Exception("%s already exists" % TESTDIR)

        self.test_path = None
        self.test_dir = None
        os.mkdir(TESTDIR)
        os.chmod(TESTDIR, 0755)

    def test_good_file(self):
        self.test_path = os.path.join(TESTDIR, "good")
        touch(self.test_path, 0644)
        self.assertTrue(tailsadditionalsoftware._is_path_safe(self.test_path, upto=UPTO))

    def test_good_path(self):
        self.test_dir = os.path.join(TESTDIR, "goodowndir")
        self.test_path = os.path.join(self.test_dir, "good")
        os.mkdir(self.test_dir)
        os.chmod(self.test_dir, 0755)
        touch(self.test_path, 0644)
        self.assertTrue(tailsadditionalsoftware._is_path_safe(self.test_path, upto=UPTO))

    def test_bad_mod_file(self):
        self.test_path = os.path.join(TESTDIR, "badmod")
        touch(self.test_path, 0664)
        self.assertFalse(tailsadditionalsoftware._is_path_safe(self.test_path, upto=UPTO))

    def test_bad_own_file(self):
        self.test_path = os.path.join(TESTDIR, "badown")
        touch(self.test_path, 0644)
        os.chown(self.test_path, 1000, 0)
        self.assertFalse(tailsadditionalsoftware._is_path_safe(self.test_path, upto=UPTO))

    def test_bad_mod_dir(self):
        self.test_dir = os.path.join(TESTDIR, "badowndir")
        self.test_path = os.path.join(self.test_dir, "good")
        os.mkdir(self.test_dir)
        os.chmod(self.test_dir, 0770)
        touch(self.test_path, 0644)
        self.assertFalse(tailsadditionalsoftware._is_path_safe(self.test_path, upto=UPTO))

    def test_bad_own_dir(self):
        self.test_dir = os.path.join(TESTDIR, "badmoddir")
        self.test_path = os.path.join(self.test_dir, "good")
        os.mkdir(self.test_dir)
        os.chmod(self.test_dir, 0755)
        os.chown(self.test_dir, 1000, 0)
        touch(self.test_path, 0644)
        self.assertFalse(tailsadditionalsoftware._is_path_safe(self.test_path, upto=UPTO))

    def tearDown(self):
        if self.test_path:
            os.remove(self.test_path)
        if self.test_dir:
            os.rmdir(self.test_dir)
        os.rmdir(TESTDIR)

if __name__ == '__main__':
    suite = unittest.TestSuite()
    suite.addTest(unittest.makeSuite(PackageslistPermissionsTest))
    unittest.TextTestRunner(verbosity=15).run(suite)
