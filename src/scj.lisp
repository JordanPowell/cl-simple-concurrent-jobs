(in-package #:cl-simple-concurrent-jobs)

(defmacro with-job-executor-lock ((worker) &body body)
  `(bt:with-recursive-lock-held ((je-lock ,worker))
     ,@body))

(defclass JobExecutor ()
  ((num-threads :initarg :num-threads :reader num-threads)
   (chanl-tasks :accessor chanl-tasks)
   (results :accessor results :initform nil)
   (num-expected-results :accessor num-expected-results :initform 0)
   (num-results-got :accessor num-results-got :initform 0)
   (completion-condition :initform (bt:make-condition-variable)
			 :reader completion-condition)
   (should-run :initform t :accessor should-run)
   (je-lock :initform (bt:make-recursive-lock) :reader je-lock)
   (channel :initform (make-instance 'chanl:unbounded-channel)
	    :reader channel)))

(defun has-all-results (je)
  (with-job-executor-lock (je)
    (eql (num-expected-results je) (num-results-got je))))

(defun append-result (je result)
  (with-job-executor-lock (je)
    (incf (num-results-got je))
    (push result (results je))
    (when (has-all-results je)
      (bt:condition-notify (completion-condition je)))))

(defun create-job-for-executor (je)
  (chanl:pexec ()
    (loop while (should-run je)
       do (let ((result nil))
	    ;; this is awful, but the way we block on jobs completing
	    ;; requires something like this. Any better ideas?
	    (unwind-protect (let ((function-or-quit (chanl:recv (channel je))))
			      (when (functionp function-or-quit)
				(setf result (funcall function-or-quit))))
	      (append-result je result))))))

(defun add-job (je callable)
  (with-job-executor-lock (je)
    (incf (num-expected-results je))
    (chanl:send (channel je) callable)
    (num-expected-results je)))

(defun cleanup-threads (je)
  (dotimes (x (num-threads je))
    (add-job je nil)))

(defun stop (je)
  (setf (should-run je) nil)
  (cleanup-threads je)
  (bt:condition-notify (completion-condition je)))

(defun finish-and-return-results (je)
  (stop je)
  (results je))

(defun join-results (je)
  (with-job-executor-lock (je)
    (if (or (not (should-run je))
	    (has-all-results je))
	(finish-and-return-results je)
	(progn
	  (bt:condition-wait (completion-condition je) (je-lock je))
	  (finish-and-return-results je)))))

(defmethod initialize-instance :after ((je JobExecutor) &key)
  (setf (chanl-tasks je)
	(loop for i from 0 to (- (num-threads je) 1) collect
	     (create-job-for-executor je))))

(defun create-job-executor (&key (num-threads 8))
  (make-instance 'JobExecutor :num-threads num-threads))
