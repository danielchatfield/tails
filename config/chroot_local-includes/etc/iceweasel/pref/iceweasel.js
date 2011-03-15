// This is the Debian specific preferences file for Iceweasel
// You can make any change in here, it is the purpose of this file.
// You can, with this file and all files present in the
// /etc/iceweasel/pref directory, override any preference that is
// present in /usr/lib/iceweasel/defaults/preferences directory.
// While your changes will be kept on upgrade if you modify files in
// /etc/iceweasel/pref, please note that they won't be kept if you
// do make your changes in /usr/lib/iceweasel/defaults/preferences.
//
// Note that lockPref is allowed in these preferences files if you
// don't want users to be able to override some preferences.

// Use LANG environment variable to choose locale
pref("intl.locale.matchOS", true);

// Disable default browser checking.
pref("browser.shell.checkDefaultBrowser", false);

pref("app.update.auto", false);
pref("app.update.disable_button.showUpdateHistory", false);
pref("app.update.enabled", false);
pref("browser.bookmarks.livemark_refresh_seconds", 31536000);
pref("browser.cache.disk.capacity", 0);
pref("browser.cache.disk.enable", false);
pref("browser.cache.offline.enable", false);
pref("browser.chrome.favicons", false);
pref("browser.chrome.site_icons", false);
pref("browser.chrome.image_icons.max_size", 0);
pref("browser.download.manager.closeWhenDone", true);
pref("browser.download.manager.retention", 0);
pref("browser.formfill.enable", false);
pref("browser.history_expire_days", 0);
pref("browser.history_expire_days.mirror", 0);
pref("browser.microsummary.updateGenerators", false);
pref("browser.privatebrowsing.autostart", true);
pref("browser.safebrowsing.enabled", false);
pref("browser.safebrowsing.malware.enabled", false);
pref("browser.safebrowsing.remoteLookups", false);
pref("browser.search.suggest.enabled", false);
pref("browser.search.update", false);
pref("browser.send_pings", false);
pref("browser.sessionstore.enabled", false);
pref("browser.sessionstore.privacy_level", 2);
pref("browser.startup.homepage_override.mstone", "ignore");
pref("capability.policy.maonoscript.javascript.enabled", "allAccess");
pref("capability.policy.maonoscript.sites", "https://auk.riseup.net https://mail.riseup.net https://swift.riseup.net https://tern.riseup.net https://webmail.no-log.org about: about:blank about:certerror about:config about:credits about:neterror about:plugins about:privatebrowsing about:sessionrestore chrome: file:// https://webmail.boum.org resource:");
pref("dom.event.contextmenu.enabled", false);
pref("dom.storage.enabled", false);
pref("extensions.foxyproxy.last-version", "2.19.1");
pref("extensions.update.enabled", false);
pref("extensions.update.notifyUser", false);
pref("geo.enabled", false);
pref("geo.wifi.uri", "");
pref("layout.css.report_errors", false);
pref("network.cookie.lifetimePolicy", 2);
pref("network.cookie.prefsMigrated", true);
pref("network.protocol-handler.external-default", false);
pref("network.protocol-handler.external.mailto", false);
pref("network.protocol-handler.external.news", false);
pref("network.protocol-handler.external.nntp", false);
pref("network.protocol-handler.external.snews", false)
pref("network.protocol-handler.warn-external.file", true);
pref("network.protocol-handler.warn-external.mailto", true);
pref("network.protocol-handler.warn-external.news", true);
pref("network.protocol-handler.warn-external.nntp", true);
pref("network.protocol-handler.warn-external.snews", true);
pref("network.proxy.failover_timeout", 0);
pref("network.proxy.http", "127.0.0.1");
pref("network.proxy.http_port", 8118);
pref("network.proxy.socks", "127.0.0.1");
pref("network.proxy.socks_port", 9050);
pref("network.proxy.socks_remote_dns", true);
pref("network.proxy.ssl", "127.0.0.1");
pref("network.proxy.ssl_port", 8118);
pref("network.proxy.type", 1);
pref("network.security.ports.banned", "8118,8123,9050,9051");
pref("layout.spellcheckDefault", 0);
pref("network.dns.disableIPv6", true);
pref("noscript.ABE.enabled", false);
pref("noscript.ABE.notify", false);
pref("noscript.httpsForced", "*twitter.com *facebook.com blog.torproject.org www.torproject.org docs.google.com addons.mozilla.org www.stumbleupon.com boum.org tails.boum.org mail.google.com mail.riseup.net webmail.no-log.org webmail.boum.org");
pref("noscript.httpsForcedExceptions", "");
pref("noscript.notify.hide", true);
pref("noscript.policynames", "");
pref("noscript.secureCookies", true);
pref("noscript.secureCookiesForced", "*torproject.org *github.com *facebook.com *twitter.com boum.org tails.boum.org mail.google.com mail.riseup.net webmail.no-log.org webmail.boum.org");
pref("noscript.showAddress", true);
pref("noscript.showAllowPage", false);
pref("noscript.showDistrust", false);
pref("noscript.showDomain", true);
pref("noscript.showGlobal", false);
pref("noscript.showPermanent", false);
pref("noscript.showRecentlyBlocked", false);
pref("noscript.showRevokeTemp", false);
pref("noscript.showTemp", false);
pref("noscript.showTempAllowPage", false);
pref("noscript.showTempToPerm", false);
pref("noscript.showUntrusted", false);
pref("noscript.untrusted", "google-analytics.com google.com file:// http://google-analytics.com http://google.com https://google-analytics.com https://google.com");
pref("pref.privacy.disable_button.cookie_exceptions", false);
pref("pref.privacy.disable_button.view_cookies", false);
pref("pref.privacy.disable_button.view_passwords", false);
pref("privacy.item.cookies", true);
pref("privacy.item.offlineApps", true);
pref("privacy.item.passwords", true);
pref("privacy.sanitize.didShutdownSanitize", true);
pref("privacy.sanitize.promptOnSanitize", false);
pref("privacy.sanitize.sanitizeOnShutdown", true);
pref("security.disable_button.openCertManager", false);
pref("security.enable_java", false);
pref("security.enable_ssl2", false);
pref("security.enable_ssl3", true);
pref("security.enable_tls", true);
pref("security.xpconnect.plugin.unrestricted", false);
pref("security.warn_leaving_secure", true);
pref("security.warn_submit_insecure", true);
pref("signon.prefillForms", false);
pref("signon.rememberSignons", false);
pref("xpinstall.whitelist.add", "");
pref("xpinstall.whitelist.add.103", "");
