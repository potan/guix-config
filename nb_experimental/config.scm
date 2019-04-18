;; This is an operating system configuration template
;; for a "desktop" setup with GNOME and Xfce where the
;; root partition is encrypted with LUKS.

(use-modules (gnu) (gnu system) (gnu system nss) (gnu packages vim) (gnu packages firmware) (gnu packages algebra) (gnu packages version-control))
(use-service-modules desktop)
(use-package-modules certs gnome)


;; copupaste
(define-module (ambrevar linux-custom)
  #:use-module (guix gexp)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix git-download)

  #:use-module (guix build-system trivial)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages certs)
  #:use-module (gnu packages gnome)
  #:use-module (gnu packages vim)
  #:use-module (gnu packages firmware)
  #:use-module (gnu packages algebra)
  #:use-module (gnu packages version-control)
  #:use-module (gnu system)
  #:use-module (gnu system nss)
  #:use-module (gnu system file-systems)
  #:use-module (gnu system shadow)
  #:use-module (gnu bootloader)
  #:use-module (gnu bootloader grub)
  #:use-module (gnu services desktop)
  #:use-module (srfi srfi-1))

(define-public linux-nonfree
  (package
    (inherit linux-libre)
    (name "linux-nonfree")
    (version (package-version linux-libre))
    (source
     (origin
      (method url-fetch)
      (uri
       (string-append
	"https://www.kernel.org/pub/linux/kernel/v4.x/"
	"linux-" version ".tar.xz"))
      (sha256
       (base32
	"1lm2s9yhzyqra1f16jrjwd66m3jl43n5k7av2r9hns8hdr1smmw4"))))
    (native-inputs
     `(("kconfig" ,(local-file "./linux-custom.conf"))
       ,@(alist-delete "kconfig" (package-native-inputs linux-libre))))))

(define (linux-firmware-version) "9d40a17beaf271e6ad47a5e714a296100eef4692")
(define (linux-firmware-source version)
  (origin
    (method git-fetch)
    (uri (git-reference
	  (url (string-append "https://git.kernel.org/pub/scm/linux/kernel"
			      "/git/firmware/linux-firmware.git"))
	  (commit version)))
    (file-name (string-append "linux-firmware-" version "-checkout"))
    (sha256
     (base32
      "099kll2n1zvps5qawnbm6c75khgn81j8ns0widiw0lnwm8s9q6ch"))))

(define-public linux-firmware-iwlwifi
  (package
    (name "linux-firmware-iwlwifi")
    (version (linux-firmware-version))
    (source (linux-firmware-source version))
    (build-system trivial-build-system)
    (arguments
     `(#:modules ((guix build utils))
       #:builder (begin
		   (use-modules (guix build utils))
		   (let ((source (assoc-ref %build-inputs "source"))
			 (fw-dir (string-append %output "/lib/firmware/")))
		     (mkdir-p fw-dir)
		     (for-each (lambda (file)
				 (copy-file file
					    (string-append fw-dir (basename file))))
			       (find-files source
					   "iwlwifi-.*\\.ucode$|LICENSE\\.iwlwifi_firmware$"))
		     #t))))
    (home-page "https://wireless.wiki.kernel.org/en/users/drivers/iwlwifi")
    (synopsis "Non-free firmware for Intel wifi chips")
    (description "Non-free iwlwifi firmware")
    (license (license:non-copyleft
	      "https://git.kernel.org/cgit/linux/kernel/git/firmware/linux-firmware.git/tree/LICENCE.iwlwifi_firmware?id=HEAD"))))
;; /copypaste

(operating-system
  (host-name "pmguix")
  (timezone "Europe/Moscow")
  (locale "en_US.utf8")

  ;; Use the UEFI variant of GRUB with the EFI System
  ;; Partition mounted on /boot/efi.
  (bootloader (bootloader-configuration
                (bootloader grub-efi-bootloader)
                (target "/boot/efi")))

  ;; Specify a mapped device for the encrypted root partition.
  ;; The UUID is that returned by 'cryptsetup luksUUID'.
 ; (mapped-devices
 ;  (list (mapped-device
 ;         (source (uuid "12345678-1234-1234-1234-123456789abc"))
 ;         (target "my-root")
 ;         (type luks-device-mapping))))

  (file-systems (cons (file-system
                        (device (file-system-label "root"))
                        (mount-point "/")
                        (type "btrfs")
                        (options "defaults,compress=lzo,space_cache,autodefrag,subvol=guix")
                        )
                      %base-file-systems))

  (users (cons (user-account
                (name "bob")
                (comment "Alice's brother")
                (group "users")
                (supplementary-groups '("wheel" "netdev"
                                        "audio" "video"))
                (home-directory "/home/bob"))
               %base-user-accounts))

  ;; This is where we specify system-wide packages.
  (packages (cons* nss-certs         ;for HTTPS access
                   gvfs              ;for user mounts
                   vim-full
;                   vips
                   network-manager
                   network-manager-applet
;                   network-manager-qt
                   b43-tools
                   bc
                   git
                   %base-packages))

  ;; Add GNOME and/or Xfce---we can choose at the log-in
  ;; screen with F1.  Use the "desktop" services, which
  ;; include the X11 log-in service, networking with
  ;; NetworkManager, and more.
  (services (cons* (gnome-desktop-service)
                   (xfce-desktop-service)
                   %desktop-services))

;  ;; copypaste
;  (kernel linux-nonfree)
;  (firmware (append (list linux-firmware-iwlwifi)
;		    %base-firmware))
;  ;; /copypaste
  ;; Allow resolution of '.local' host names with mDNS.
  (name-service-switch %mdns-host-lookup-nss))
