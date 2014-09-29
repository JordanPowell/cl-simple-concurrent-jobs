(asdf:defsystem :cl-simple-concurrent-jobs
  :version "0.2"
  :license "BSD 2-Clause"
  :author "Jordan Rhys Powell"
  :description "A simple API for running concurrent jobs"
  :serial t
  :depends-on (#:bordeaux-threads #:chanl)
  :components ((:module src
                        :components ((:file "packages")
                                     (:file "scj" 
					    :depends-on ("packages"))))))
