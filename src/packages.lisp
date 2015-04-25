(defpackage #:cl-simple-concurrent-jobs
  (:documentation
   "A simple API for running concurrent jobs")
  (:use #:cl)
  (:nicknames #:cl-scj)
  (:export #:join-results
	   #:has-all-results
	   #:add-job
	   #:stop
	   #:create-job-executor))
