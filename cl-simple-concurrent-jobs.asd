(asdf:defsystem :cl-simple-concurrent-jobs
  :version "1.0.0"
  :license "BSD 2-Clause"
  :author "Jordan Rhys Powell"
  :description "A simple API for running concurrent jobs and collecting the results"
  :serial t
  :depends-on (#:bordeaux-threads #:chanl)
  :components ((:module src
                        :components ((:file "packages")
                                     (:file "scj" 
					    :depends-on ("packages"))))))
