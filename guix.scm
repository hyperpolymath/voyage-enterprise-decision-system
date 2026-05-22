; SPDX-License-Identifier: MPL-2.0
;; guix.scm — GNU Guix package definition for voyage-enterprise-decision-system
;; Usage: guix shell -f guix.scm

(use-modules (guix packages)
             (guix build-system gnu)
             (guix licenses))

(package
  (name "voyage-enterprise-decision-system")
  (version "0.1.0")
  (source #f)
  (build-system gnu-build-system)
  (synopsis "voyage-enterprise-decision-system")
  (description "voyage-enterprise-decision-system — part of the hyperpolymath ecosystem.")
  (home-page "https://github.com/hyperpolymath/voyage-enterprise-decision-system")
  (license ((@@ (guix licenses) license) "MPL-2.0"
             "https://github.com/hyperpolymath/palimpsest-license")))
